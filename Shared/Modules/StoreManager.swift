//
//  StoreManager.swift
//  Rereminder
//
//  StoreKit 2 기반 인앱 구매 관리
//  - 일회성 구매 (Non-consumable)
//  - 구매 상태 영구 저장 (UserDefaults + Keychain)
//  - Transaction 자동 감시
//

import Foundation
import StoreKit

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

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?
    private let keychainKey = "rereminder.pro.purchased"
    private let defaultsKey = "rereminder.pro.purchased"

    // MARK: - Grandfathering

    /// Pro 잠금 도입 전 기존 사용자에게 무료 Pro 부여
    private static let grandfatherCheckKey = "rereminder.grandfather.checked"

    private func grandfatherExistingUserIfNeeded() {
        let defaults = UserDefaults.standard

        // 이미 체크 완료된 경우 스킵
        guard !defaults.bool(forKey: Self.grandfatherCheckKey) else { return }
        defaults.set(true, forKey: Self.grandfatherCheckKey)

        // 이미 Pro인 경우 스킵
        guard !isPro else { return }

        // Pro 도입 전에 앱을 사용한 흔적이 있는지 확인
        let isExistingUser = defaults.string(forKey: "selectedThemeID") != nil
            || defaults.bool(forKey: "pushEnabled")
            || defaults.integer(forKey: "timerCompletionCount") > 0

        if isExistingUser {
            isPro = true
            savePurchaseState(true)
        }
    }

    // MARK: - Init

    private init() {
        // 저장된 구매 상태 로드
        isPro = loadPurchaseState()

        // 기존 사용자 무료 Pro 부여
        grandfatherExistingUserIfNeeded()

        // Transaction 감시 시작
        transactionListener = listenForTransactions()

        // 제품 정보 로드
        Task { await loadProducts() }

        // 앱 시작 시 영수증 검증
        Task { await verifyCurrentEntitlements() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let ids = ProductID.allCases.map(\.rawValue)
            products = try await Product.products(for: ids)
        } catch {
            print("❌ 제품 로드 실패: \(error)")
            errorMessage = "Failed to load products"
        }
    }

    // MARK: - Purchase

    func purchase(_ productID: ProductID = .pro) async {
        guard let product = products.first(where: { $0.id == productID.rawValue }) else {
            errorMessage = "Product not found"
            purchaseState = .failed
            return
        }

        purchaseState = .purchasing
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handlePurchased(transaction)
                purchaseState = .purchased

            case .userCancelled:
                purchaseState = .idle

            case .pending:
                // 결제 보류 (가족 승인 등)
                purchaseState = .idle
                errorMessage = "Purchase pending approval"

            @unknown default:
                purchaseState = .failed
            }
        } catch {
            print("❌ 구매 실패: \(error)")
            errorMessage = error.localizedDescription
            purchaseState = .failed
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        purchaseState = .purchasing

        // AppStore에 동기화 요청
        try? await AppStore.sync()

        await verifyCurrentEntitlements()

        if isPro {
            purchaseState = .restored
        } else {
            purchaseState = .idle
            errorMessage = "No purchases to restore"
        }
    }

    // MARK: - Entitlement Verification

    /// 현재 유효한 구매 내역 확인 (앱 시작 시, 복원 시 호출)
    func verifyCurrentEntitlements() async {
        var foundPro = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == ProductID.pro.rawValue {
                    foundPro = true
                    await transaction.finish()
                }
            }
        }

        if foundPro != isPro {
            isPro = foundPro
            savePurchaseState(foundPro)
        }
    }

    // MARK: - Transaction Listener

    /// 외부 구매 (프로모션 코드, 가족 공유 등) 실시간 감지
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? self.checkVerified(result) {
                    await self.handlePurchased(transaction)
                }
            }
        }
    }

    // MARK: - Helpers

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private func handlePurchased(_ transaction: Transaction) async {
        if transaction.productID == ProductID.pro.rawValue {
            isPro = true
            savePurchaseState(true)
        }
        await transaction.finish()
    }

    // MARK: - Persistence (UserDefaults + Keychain)

    private func savePurchaseState(_ purchased: Bool) {
        // UserDefaults (빠른 접근)
        UserDefaults.standard.set(purchased, forKey: defaultsKey)

        // Keychain (앱 삭제 후 재설치에도 유지)
        KeychainHelper.save(key: keychainKey, value: purchased)
    }

    private func loadPurchaseState() -> Bool {
        // Keychain 우선, 없으면 UserDefaults
        if let keychainValue = KeychainHelper.load(key: keychainKey) {
            // UserDefaults도 동기화
            UserDefaults.standard.set(keychainValue, forKey: defaultsKey)
            return keychainValue
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
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
    nonisolated static var isProUser: Bool {
        KeychainHelper.load(key: "rereminder.pro.purchased") ?? UserDefaults.standard.bool(forKey: "rereminder.pro.purchased")
    }
}
