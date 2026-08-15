//
//  StoreManager.swift
//  Rereminder
//
//  부분 유료화(프로 일회성 잠금해제) — 파사드
//
//  StoreKit 2 엔진(상품 로드·구매·복원·권한 추적·트랜잭션 리스너·오프라인 캐시)은
//  이제 LeeoKit 의 LeeoStore 가 공용으로 담당한다. 이 파일은 그 위에 앱 고유의
//  로직만 얹은 얇은 파사드로, 기존 호출부·ProGate·PaywallView 는 그대로 동작한다.
//  - 일회성 구매 (Non-consumable, com.xa.toki.pro)
//  - 구매 상태 영구 저장 (UserDefaults + Keychain, key "rereminder.pro.purchased")
//    → 논isolated 정적 isProUser 가 항상 올바른 값을 읽도록 store.hasPro 를 미러링한다.
//  - 개발/샌드박스/맥앱 자동 Pro → unlockOverride 로 LeeoStore 에 주입
//  - 기존 사용자 그랜드파더링 → grandfather 클로저로 LeeoStore 에 주입
//

import Foundation
import Combine
import StoreKit
import LeeoKit

@MainActor
final class StoreManager: ObservableObject {

    // MARK: - Product IDs

    enum ProductID: String, CaseIterable {
        case pro = "com.xa.toki.pro"
    }

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var purchaseState: PurchaseState = .idle
    @Published private(set) var errorMessage: String?

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case purchased
        case failed
        case restored
    }

    // MARK: - Singleton

    static let shared = StoreManager()

    // MARK: - Private (LeeoStore 엔진 + 상태 미러링)

    private let store: LeeoStore
    private var cancellable: AnyCancellable?
    private let keychainKey = "rereminder.pro.purchased"
    private let defaultsKey = "rereminder.pro.purchased"

    // MARK: - TestFlight / Sandbox

    /// TestFlight 또는 sandbox StoreKit 환경에서 실행 중인지 판별.
    /// Release 빌드에서만 동작하며, Debug 빌드는 항상 false 를 반환하여
    /// 시뮬레이터/Xcode 디버그에서 paywall 흐름 테스트가 가능하도록 함.
    nonisolated static var isTestFlightOrSandbox: Bool {
        #if DEBUG
        return false
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    /// 개발자 / macOS 환경에서 Pro 자동 부여.
    /// - macOS 빌드: 별도 인앱 결제 없이 모든 Pro 기능 사용 (개발자/맥앱)
    /// - iOS DEBUG(개발) 빌드: 기본적으로 Pro 부여 → 개발자는 항상 Pro 접근.
    ///   paywall 흐름을 테스트하려면 UserDefaults "dev.testPaywall" = true 로 끌 수 있음.
    /// - Release/App Store 빌드: 영향 없음(실제 구매/그랜드파더링만 적용).
    nonisolated static var isDeveloperUnlock: Bool {
        #if os(macOS)
        return true
        #elseif DEBUG
        return !UserDefaults.standard.bool(forKey: "dev.testPaywall")
        #else
        return false
        #endif
    }

    /// Pro 자동 부여 환경 여부 (TestFlight/Sandbox 또는 개발자/macOS)
    nonisolated static var isAutoProEnvironment: Bool {
        isTestFlightOrSandbox || isDeveloperUnlock
    }

    // MARK: - Grandfathering

    /// Pro 잠금 도입 전 기존 사용자에게 무료 Pro 부여
    /// v2: v1은 부여 직후 verifyCurrentEntitlements 가 구매 부재로 Pro 를 되돌리는
    /// 버그가 있었다. 부여 사실을 별도 플래그로 기록해 검증에서 보호하고,
    /// v1 에서 부여받았다 잃은 사용자를 위해 흔적 검사를 한 번 더 수행한다.
    private static let grandfatherCheckKey = "rereminder.grandfather.checked.v2"
    nonisolated private static let grandfatherGrantedKey = "rereminder.grandfather.granted"

    /// 기존 사용자 무료 Pro 여부 — verifyCurrentEntitlements 가 구매 부재로
    /// Pro 를 회수하지 않도록 보호하는 근거
    nonisolated static var isGrandfathered: Bool {
        UserDefaults.standard.bool(forKey: grandfatherGrantedKey)
    }

    /// LeeoStore 의 grandfather 클로저로 주입되는 판정.
    /// 실제 구매/그랜드파더링이 없을 때 LeeoStore 가 1회만 호출한다(결과 캐시).
    /// 부여하면 rereminder.grandfather.granted 를 기록해 정적 isGrandfathered 가 읽는다.
    private static func grandfatherExistingUserIfNeeded() -> Bool {
        let defaults = UserDefaults.standard

        // 이미 체크 완료된 경우 스킵
        guard !defaults.bool(forKey: grandfatherCheckKey) else { return false }
        defaults.set(true, forKey: grandfatherCheckKey)

        // 자동 Pro 환경(개발/샌드박스/맥앱)에서는 그랜드파더링을 부여하지 않는다.
        // (원본의 `guard !isPro` 재현 — 자동 Pro 는 keychain/grant 에 영속화하지 않는다.)
        guard !isAutoProEnvironment else { return false }

        // Pro 도입 전에 앱을 사용한 흔적이 있는지 확인
        let isExistingUser = defaults.string(forKey: "selectedThemeID") != nil
            || defaults.bool(forKey: "pushEnabled")
            || defaults.integer(forKey: "timerCompletionCount") > 0

        if isExistingUser {
            defaults.set(true, forKey: grandfatherGrantedKey)
            return true
        }
        return false
    }

    // MARK: - Init

    private init() {
        store = LeeoStore(
            config: RereminderSpec.paywallConfig,
            // 개발/샌드박스/맥앱 자동 Pro (true=강제 해제). 그 외에는 정상 판정(nil).
            unlockOverride: { Self.isAutoProEnvironment ? true : nil },
            // 기존 사용자 그랜드파더링 (구매 없을 때 LeeoStore 가 1회 호출).
            grandfather: { Self.grandfatherExistingUserIfNeeded() }
        )

        // 공용 스토어의 초기 상태를 파사드에 반영 + 키체인 미러링
        syncFromStore()

        // 공용 스토어의 상태 변화를 파사드 @Published + 키체인/UserDefaults 로 전파.
        // objectWillChange 는 값 변경 '직전'에 발화하므로, 변경 반영 후 읽도록
        // 다음 메인액터 틱으로 미룬다.
        cancellable = store.objectWillChange.sink { [weak self] in
            Task { @MainActor in
                self?.syncFromStore()
                self?.objectWillChange.send()
            }
        }
    }

    // MARK: - 상태 미러링

    /// LeeoStore 의 현재 상태를 파사드의 @Published 로 옮기고,
    /// 논isolated 정적 isProUser 가 어디서든 올바른 값을 읽도록
    /// Pro 상태를 Keychain + UserDefaults(rereminder.pro.purchased) 로 미러링한다.
    private func syncFromStore() {
        products = store.products

        let pro = store.hasPro
        let changed = (pro != isPro)
        isPro = pro

        // 자동 Pro 환경은 영속화하지 않는다(원본과 동일). 실제 구매/그랜드파더링만 저장.
        if changed, !Self.isAutoProEnvironment {
            savePurchaseState(pro)
        }
    }

    // MARK: - Load Products / Entitlements (LeeoStore 로 위임)

    /// 상품 로드 — 네트워크 불안정 대비 지수 백오프 재시도 (1s → 2s → 4s)
    func loadProducts() async {
        let maxRetries = 3
        for attempt in 0..<maxRetries {
            await store.loadProducts()
            if !store.products.isEmpty { return }
            // 마지막 시도가 아니면 백오프 후 재시도
            guard attempt < maxRetries - 1 else { break }
            let backoff = UInt64(1 << attempt) * 1_000_000_000
            try? await Task.sleep(nanoseconds: backoff)
        }
    }

    /// 현재 유효한 구매 내역 확인 (앱 시작 시, 복원 시 호출)
    func verifyCurrentEntitlements() async {
        await store.refreshEntitlements()
    }

    // MARK: - Purchase

    func purchase(_ productID: ProductID = .pro) async {
        purchaseState = .purchasing
        errorMessage = nil

        AnalyticsManager.log(.purchaseStarted(productId: productID.rawValue))

        let success: Bool
        if let product = store.products.first(where: { $0.id == productID.rawValue }) {
            success = await store.purchase(product)
        } else {
            success = await store.purchasePrimary()
        }

        if success {
            purchaseState = .purchased
            errorMessage = nil
            AnalyticsManager.log(.purchaseCompleted(productId: productID.rawValue))
        } else if let message = store.lastError {
            // 오류/보류 — LeeoStore 가 사용자 노출 메시지를 남긴 경우
            errorMessage = message
            purchaseState = .failed
            AnalyticsManager.log(.purchaseFailed(
                productId: productID.rawValue,
                reason: "error"
            ))
        } else {
            // 사용자 취소 등 — 조용히 idle 로 되돌림
            purchaseState = .idle
            AnalyticsManager.log(.purchaseFailed(
                productId: productID.rawValue,
                reason: "user_cancelled"
            ))
        }

        syncFromStore()
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        purchaseState = .purchasing
        errorMessage = nil

        await store.restore()
        syncFromStore()

        if isPro {
            purchaseState = .restored
            AnalyticsManager.log(.purchaseRestored)
        } else {
            purchaseState = .idle
            errorMessage = store.lastError
                ?? String(localized: "No purchases to restore")
        }
    }

    // MARK: - Persistence (UserDefaults + Keychain)

    private func savePurchaseState(_ purchased: Bool) {
        // UserDefaults (빠른 접근)
        UserDefaults.standard.set(purchased, forKey: defaultsKey)

        // Keychain (앱 삭제 후 재설치에도 유지)
        KeychainHelper.save(key: keychainKey, value: purchased)
    }
}

// MARK: - Convenience

extension StoreManager {
    /// Pro 제품 가격 문자열 (예: "₩3,900")
    var proPrice: String {
        products
            .first { $0.id == ProductID.pro.rawValue }?
            .displayPrice ?? ""
    }

    /// Pro 제품 이름
    var proDisplayName: String {
        products
            .first { $0.id == ProductID.pro.rawValue }?
            .displayName ?? AppName.pro
    }

    /// 빠른 Pro 체크 (저장된 값, 네트워크 불필요)
    /// nonisolated — Keychain/UserDefaults만 읽으므로 어디서든 호출 가능
    /// TestFlight/Sandbox 환경과 기존 사용자(그랜드파더링)는 항상 true 를 반환
    nonisolated static var isProUser: Bool {
        if isAutoProEnvironment || isGrandfathered { return true }
        return KeychainHelper.load(key: "rereminder.pro.purchased") ?? UserDefaults.standard.bool(forKey: "rereminder.pro.purchased")
    }
}
