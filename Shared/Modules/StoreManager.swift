//
//  StoreManager.swift
//  Rereminder
//
//  부분 유료화(프로 일회성 잠금해제) — 파사드
//
//  StoreKit 2 엔진(상품 로드·구매·복원·권한 추적·트랜잭션 리스너·오프라인 캐시)은
//  이제 LeeoKit 의 LeeoStore 가 공용으로 담당한다. 이 파일은 그 위에 앱 고유의
//  로직만 얹은 얇은 파사드로, 기존 호출부·ProGate·PaywallView 는 그대로 동작한다.
//  - 일회성 구매 (Non-consumable) 세 개 — **트림**(`ProTier`):
//      com.xa.toki.pro          Pro 전체(세션 모드·대본·오버타임·기록 + 기억)
//      com.xa.toki.remember     기억(템플릿 저장·불러오기 + 마지막 설정 복원)만
//      com.xa.toki.pro.upgrade  기억 → Pro 차액. 기억을 산 사람에게만 보인다. 권한은 pro 와 같다.
//    ⚠️ `isProUser` 는 예전 그대로 **Pro 전체**를 뜻한다. 기억 트림은 `canRememberSetup` 만 연다.
//       기존 구매자·그랜드파더링·창단 후원자는 전부 Pro 전체다 — 기억으로 떨어지면 신뢰 사고다.
//  - 구매 상태 영구 저장 (UserDefaults + Keychain, key "rereminder.pro.purchased")
//    → 논isolated 정적 isProUser 가 항상 올바른 값을 읽도록 store.hasPro 를 미러링한다.
//  - 개발/샌드박스/맥앱 자동 Pro → unlockOverride 로 LeeoStore 에 주입
//  - 기존 사용자 그랜드파더링 → grandfather 클로저로 LeeoStore 에 주입
//
//  ⚠️ **구매 기록은 래치다 — 조회가 비었다고 내리지 않는다.**
//     예전에는 `store.hasPro` 가 false 로 바뀌면 그대로 Keychain 에 false 를 적었다. 그런데
//     `Transaction.currentEntitlements` 는 App Store 계정 로그아웃·기기 초기화 직후·StoreKit
//     캐시 미형성에서도 **조용히 빈 값**을 내므로, 그 한 번이 재설치에도 살아남으라고 넣어 둔
//     평생 해제 기록을 지웠다. 결과는 **돈을 낸 사람에게 페이월이 다시 뜨는 것**이고, 이건
//     기능 결함이 아니라 신뢰의 문제다.
//     그래서 기록을 내리는 근거는 **회수(환불)를 직접 확인했을 때** 하나뿐이다
//     (`hasRevokedProTransaction`). 자세한 이유는 그 함수 주석 참고.
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
        case remember = "com.xa.toki.remember"
        case proUpgrade = "com.xa.toki.pro.upgrade"

        /// 이 상품이 여는 트림.
        var tier: ProTier { self == .remember ? .plus : .session }
    }

    /// Pro 전체 권한을 주는 상품. ⚠️ `RereminderSpec.paywallConfig.entitlementIDs` 와 같아야 한다.
    nonisolated static let fullProductIDs: Set<String> = [ProductID.pro.rawValue, ProductID.proUpgrade.rawValue]

    /// 팁(응원) 상품 — **소모성**, 작은 것부터 큰 것 순(화면도 이 순서다). 아무 권한도 열지 않는다.
    /// ⚠️ `ProductID`·`productIDs`·`entitlementIDs` 어디에도 넣지 않는다 — 넣으면 팁을 낸 사람이 Pro 가 된다.
    nonisolated static let tipProductIDs = ["com.xa.toki.tip.small", "com.xa.toki.tip.medium", "com.xa.toki.tip.large"]

    /// Pro 선물 상품 — **소모성**(몇 번이고 보낼 수 있어야 한다). 받은 사람이 `ProductID.pro` 를 산 것과 같아진다.
    /// ⚠️ 이것도 `productIDs`·`entitlementIDs` 에 넣지 않는다 — 넣으면 선물을 산 사람 자신이 Pro 가 된다.
    nonisolated static let giftProductID = "com.xa.toki.gift.pro"

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    /// 설정을 기억해도 되는가 — 기억 트림 또는 Pro 전체. 화면은 이 값을 관찰해 자물쇠를 푼다.
    @Published private(set) var canRemember: Bool = false
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
    nonisolated private static let rememberKey = "rereminder.remember.purchased"
    /// 회수 확인이 이미 돌고 있는지. `syncFromStore` 는 상품 로드·복원 등으로도 자주 불리는데,
    /// 그때마다 `Transaction.all` 을 훑으면 낭비다.
    private var isCheckingRevocation = false
    private var isCheckingRememberRevocation = false

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
    /// 창단 후원자 자격이 남는 자리(`FoundingSupporter.keychainKey`). 앱 전용 파일이라
    /// 여기서는 **문자열로** 읽는다 — `Shared/` 는 워치·위젯에서도 컴파일된다.
    nonisolated private static let founderKeychainKey = "rereminder.founder"

    /// 기존 사용자 무료 Pro 여부 — verifyCurrentEntitlements 가 구매 부재로
    /// Pro 를 회수하지 않도록 보호하는 근거.
    ///
    /// ⚠️ **Keychain 도 함께 본다.** 예전에는 이 자격이 `UserDefaults` 에만 있어서
    ///    **앱을 지웠다 다시 깔면 평생 무료가 통째로 사라졌다** — 재판정에 쓰는 흔적
    ///    (테마·완주 횟수)도 같은 곳에 있어 함께 지워지므로 영영 돌아오지 않았다.
    ///    실제 제보로 확인된 경로다(2026-09-18). 구매 기록과 같은 급으로 다뤄야 한다.
    nonisolated static var isGrandfathered: Bool {
        if UserDefaults.standard.bool(forKey: grandfatherGrantedKey) { return true }
        guard KeychainHelper.load(key: grandfatherGrantedKey) == true else { return false }
        // 재설치 뒤 처음 읽은 순간 — 빠른 판정을 위해 UserDefaults 도 되살려 둔다.
        UserDefaults.standard.set(true, forKey: grandfatherGrantedKey)
        return true
    }

    /// 창단 후원자 기록이 Keychain 에 남아 있는가 — 결제했거나 그랜드파더링된 사람만 받는 표식이라
    /// 그 자체가 "이 사람은 값을 치렀거나 평생 무료를 약속받았다"는 증거다. 앱을 지워도 남는다.
    nonisolated static var hasFounderRecord: Bool {
        KeychainHelper.load(key: founderKeychainKey) == true
    }

    /// LeeoStore 의 grandfather 클로저로 주입되는 판정.
    /// 실제 구매/그랜드파더링이 없을 때 LeeoStore 가 1회만 호출한다(결과 캐시).
    /// 부여하면 rereminder.grandfather.granted 를 기록해 정적 isGrandfathered 가 읽는다.
    nonisolated private static func grandfatherExistingUserIfNeeded() -> Bool {
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
            grantGrandfather()
            return true
        }
        return false
    }

    /// 그랜드파더링 자격을 **두 벌로** 남긴다 — 앱을 지워도 Keychain 에 남아야 한다.
    nonisolated private static func grantGrandfather() {
        UserDefaults.standard.set(true, forKey: grandfatherGrantedKey)
        KeychainHelper.save(key: grandfatherGrantedKey, value: true)
    }

    /// **"예전에 Pro 였는데 사라졌어요" 를 되돌리는 자리.**
    ///
    /// 앱을 지웠다 깐 사람의 `UserDefaults` 는 비어 있지만 Keychain 은 남아 있다. 남은 표식
    /// (그랜드파더링 기록·창단 후원자 기록·구매 기록)이 하나라도 있으면 자격을 되살린다.
    ///
    /// ⚠️ **흔적 검사(`grandfatherExistingUserIfNeeded`)를 다시 돌리지 말 것.** 그 검사가 보는
    ///    흔적(테마를 골랐나·완주한 적 있나)은 **신규 사용자도 며칠이면 만든다.** 처음 한 번,
    ///    즉 Pro 도입 버전으로 막 올라온 순간에만 뜻이 있는 신호다. 나중에 다시 돌리면
    ///    새로 깐 사람에게 평생 무료가 나간다.
    /// - Returns: 복구했거나 이미 자격이 있으면 `true`.
    @discardableResult
    nonisolated static func recoverLostEntitlementIfPossible() -> Bool {
        if isGrandfathered || storedPurchaseFlag { return true }
        guard hasFounderRecord else { return false }
        grantGrandfather()
        return true
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

        // ⚠️ **먼저 잃어버린 자격부터 되살린다.** 앱을 지웠다 깐 그랜드파더링 사용자는
        //    UserDefaults 가 비어 있어 "평생 무료"가 사라진 채로 시작한다(Keychain 에는 남아 있다).
        Self.recoverLostEntitlementIfPossible()

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
    ///
    /// ⚠️ **올릴 때와 내릴 때가 대칭이 아니다.** 올리는 근거(권한이 보인다)는 확실하지만,
    ///    내리는 근거(권한이 안 보인다)는 확실하지 않다 — 조회가 실패해도 똑같이 안 보인다.
    ///    그래서 내리는 쪽만 회수 확인(`clearStoredPurchaseIfRevoked`)을 한 겹 더 거친다.
    private func syncFromStore() {
        products = store.products

        let live = store.hasPro
        // ⚠️ `hasPro` 는 그랜드파더링까지 참으로 본다. 구매 기록은 **실제 결제 트랜잭션**이 보일 때만
        //    적는다 — 예전에는 `live` 로 적어서 평생 무료 사용자도 결제한 사람(`flag.isPaid`)으로 셌다.
        let purchased = !store.purchasedProductIDs.isDisjoint(with: store.config.entitlementIDs)

        if !Self.isAutoProEnvironment {
            if purchased {
                // 결제가 보인다 — 근거가 확실하므로 바로 기록한다.
                if !Self.storedPurchaseFlag {
                    savePurchaseState(true)
                    // 결제는 페이월 밖에서도 일어난다 — 권한이 처음 보이는 순간 새 결제인지 확인한다.
                    Task { [weak self] in await self?.reportNewPurchaseIfNeeded() }
                }
            } else if !live, Self.storedPurchaseFlag {
                // 갖고 있던 기록이 조회에서 사라졌다. 환불인지 조회 실패인지 따로 확인한다.
                Task { [weak self] in await self?.clearStoredPurchaseIfRevoked() }
            }
        }

        // 기억 트림 — Pro 와 같은 래치 규칙. 올리는 건 바로, 내리는 건 환불을 확인했을 때만.
        let rememberLive = store.purchasedProductIDs.contains(ProductID.remember.rawValue)
        if !Self.isAutoProEnvironment {
            if rememberLive {
                if !Self.storedRememberFlag {
                    Self.saveRememberState(true)
                    Task { [weak self] in await self?.reportNewPurchaseIfNeeded() }
                }
            } else if Self.storedRememberFlag {
                Task { [weak self] in await self?.clearStoredRememberIfRevoked() }
            }
        }

        // 화면에 보이는 값(@Published)은 최종 판정과 언제나 같아야 한다 — 여기가 갈라지면
        // 페이월은 "구매하세요"라고 하는데 기능은 열려 있는(또는 그 반대의) 상태가 된다.
        isPro = Self.isProUser || live
        canRemember = isPro || Self.canRememberSetup || rememberLive
    }

    /// 기억 트림의 회수 확인 — `clearStoredPurchaseIfRevoked` 와 같은 근거(`Transaction.all`)로만 내린다.
    private func clearStoredRememberIfRevoked() async {
        guard !isCheckingRememberRevocation else { return }
        isCheckingRememberRevocation = true
        defer { isCheckingRememberRevocation = false }

        let revocations = await Self.revocationDates(for: [ProductID.remember.rawValue])
        guard Self.isRevoked(proTransactionRevocationDates: revocations) else { return }
        Self.saveRememberState(false)
        canRemember = isPro || Self.canRememberSetup
    }

    /// 회수(환불)가 확인된 경우에만 저장된 구매 기록을 내린다.
    ///
    /// 확인은 `Transaction.all` 로 한다. `Transaction.currentEntitlements` 는 회수된
    /// 트랜잭션을 **아예 내보내지 않으므로** 거기서는 "환불됐다"와 "조회가 비었다"를 구분할
    /// 수 없다 — 구분하지 못한 채 내렸던 것이 바로 결제한 사용자에게 페이월이 다시 뜨던 원인이다.
    private func clearStoredPurchaseIfRevoked() async {
        guard !isCheckingRevocation else { return }
        isCheckingRevocation = true
        defer { isCheckingRevocation = false }

        // Pro 전체는 pro·업그레이드 어느 쪽으로든 얻는다 — 둘을 함께 봐야 "살아 있는 것이 하나라도"가 맞다.
        let revocations = await Self.revocationDates(for: Self.fullProductIDs)
        guard Self.isRevoked(proTransactionRevocationDates: revocations) else { return }
        savePurchaseState(false)
        isPro = Self.isProUser || store.hasPro
        canRemember = isPro || Self.canRememberSetup
    }

    /// 주어진 상품들의 트랜잭션 회수 시각 목록 (살아 있으면 nil). StoreKit 접촉은 여기까지다.
    nonisolated private static func revocationDates(for productIDs: Set<String>) async -> [Date?] {
        var dates: [Date?] = []
        for await result in Transaction.all {
            guard case .verified(let transaction) = result,
                  productIDs.contains(transaction.productID) else { continue }
            dates.append(transaction.revocationDate)
        }
        return dates
    }

    /// 회수 판정 (순수 함수 — 테스트 대상).
    ///
    /// - 살아 있는 트랜잭션이 하나라도 있으면 회수가 아니다(환불 후 재구매 등).
    /// - ⚠️ **목록이 비어 있으면 false 다.** "조회에 아무것도 안 잡혔다"는 환불의 근거가
    ///   아니라 근거가 없다는 뜻이다. 여기서 true 를 돌려주면 App Store 로그아웃 한 번으로
    ///   결제한 사용자의 평생 해제가 지워진다 — 고치려던 바로 그 버그다.
    nonisolated static func isRevoked(proTransactionRevocationDates dates: [Date?]) -> Bool {
        guard !dates.isEmpty else { return false }
        return dates.allSatisfy { $0 != nil }
    }

    // MARK: - 결제 완료 이벤트

    /// 새 결제를 **트랜잭션 하나당 한 번** `purchase_completed` 로 남긴다.
    ///
    /// ⚠️ 예전에는 페이월의 `purchase()` 가 true 를 돌려줄 때만 남겼다. 그런데 결제는 그 밖에서도
    ///    일어난다 — 자녀 구매 승인(Ask to Buy, `.pending` 뒤 `Transaction.updates` 로 도착)·
    ///    인앱결제 프로모션 코드·App Store 페이지의 인앱 구매. 그 결제는 이벤트 없이 권한만 생겨
    ///    허브의 결제 퍼널 마지막 칸이 비어 있었다. 그래서 **권한이 보이는 순간** 트랜잭션을 보고 판정한다.
    /// - 페이월 안의 결제도 이 길로 온다 — 두 경로가 같은 트랜잭션을 두 번 세지 않게 하려는 것이다.
    ///   페이월에서 샀는지는 `paywall_converted:*` 가 따로 말한다.
    private func reportNewPurchaseIfNeeded() async {
        guard !Self.isAutoProEnvironment, !isReportingPurchase else { return }
        isReportingPurchase = true
        defer { isReportingPurchase = false }

        for transaction in await Self.ownedPurchases() {
            let key = Self.reportedPurchaseKeyPrefix + String(transaction.originalID)
            guard Self.shouldReportPurchase(
                purchaseDate: transaction.purchaseDate,
                isOwnPurchase: transaction.isOwnPurchase,
                alreadyReported: KeychainHelper.load(key: key) == true
            ) else { continue }
            // Keychain 이라 재설치해도 같은 결제를 다시 세지 않는다.
            KeychainHelper.save(key: key, value: true)
            // 어느 트림을 샀는지가 이벤트에 그대로 실린다(`purchase_completed:<상품 ID>`).
            AnalyticsManager.log(.purchaseCompleted(productId: transaction.productID))
        }
    }

    private var isReportingPurchase = false
    nonisolated private static let reportedPurchaseKeyPrefix = "rereminder.purchase.reported."

    /// 결제 시각이 이만큼 지난 트랜잭션은 새 결제로 보지 않는다 — 옛 구매자가 재설치·새 기기로
    /// 복원한 것을 결제로 세면 퍼널이 부풀려진다. 승인 대기가 며칠 걸릴 수 있어 넉넉히 둔다.
    nonisolated static let newPurchaseWindow: TimeInterval = 7 * 24 * 3600

    /// 결제 완료로 셀지 판정 (순수 함수 — 테스트 대상).
    /// 가족 공유로 받은 권한은 이 사람이 결제한 것이 아니므로 세지 않는다.
    nonisolated static func shouldReportPurchase(
        purchaseDate: Date,
        isOwnPurchase: Bool,
        alreadyReported: Bool,
        now: Date = Date()
    ) -> Bool {
        guard isOwnPurchase, !alreadyReported else { return false }
        return now.timeIntervalSince(purchaseDate) < newPurchaseWindow
    }

    /// 살아 있는 이 앱 상품(트림 셋)의 트랜잭션들. StoreKit 접촉은 여기까지다.
    nonisolated private static func ownedPurchases() async
        -> [(productID: String, originalID: UInt64, purchaseDate: Date, isOwnPurchase: Bool)] {
        let ids = Set(ProductID.allCases.map(\.rawValue))
        var found: [(productID: String, originalID: UInt64, purchaseDate: Date, isOwnPurchase: Bool)] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ids.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            found.append((transaction.productID, transaction.originalID, transaction.purchaseDate,
                          transaction.ownershipType == .purchased))
        }
        return found
    }

    // MARK: - 팁 · 선물 (LeeoStore 가 엔진을 가진다)

    /// 팁(응원) 엔진. 상품이 App Store 에서 와야 `isAvailable` 이 참이 되고, 그때만 설정에 줄이 선다.
    var tipJar: LeeoTipJar? { store.tipJar }

    /// Pro 선물 엔진. 받은 선물은 LeeoStore 가 `purchasedProductIDs` 에 합쳐 Pro 로 연다.
    var gift: LeeoGiftStore? { store.gift }

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

        if store.products.first(where: { $0.id == productID.rawValue }) == nil {
            await store.loadProducts()
        }
        let success: Bool
        if let product = store.products.first(where: { $0.id == productID.rawValue }) {
            success = await store.purchase(product)
        } else {
            // ⚠️ 상품을 못 찾으면 **다른 상품을 대신 사게 하지 않는다.** `purchasePrimary()` 는 로드된
            //    첫 상품을 사는데, 상품이 셋이 된 뒤로는 Pro 만 빠진 경우 그게 기억($2.99)일 수 있고,
            //    반대로 기억을 누른 사람에게 $9.99 결제창이 뜰 수도 있다.
            purchaseState = .failed
            errorMessage = String(localized: "Couldn't load this purchase. Please try again.")
            return
        }

        if success {
            purchaseState = .purchased
            errorMessage = nil
            await reportNewPurchaseIfNeeded()
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
        // 구매 기록이 없어도 평생 무료 자격이 Keychain 에 남아 있을 수 있다 — 복원은 그것도 되살린다.
        Self.recoverLostEntitlementIfPossible()
        syncFromStore()

        if isPro || canRemember {
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

    nonisolated private static func saveRememberState(_ purchased: Bool) {
        UserDefaults.standard.set(purchased, forKey: rememberKey)
        KeychainHelper.save(key: rememberKey, value: purchased)
    }
}

// MARK: - 트림

/// 이 설치가 어디까지 열려 있나. **값이 커질수록 위다** — 위 트림은 아래 트림을 전부 포함한다.
/// 무료 · 플러스 · 프로 세 칸이다. 사람에게 보이는 플러스의 이름은 **"기억(Remember)"** 이다.
/// ⚠️ 플러스는 Pro 가 아니다 — `com.xa.toki.remember` 는 `entitlementIDs` 에 넣지 않는다(`RereminderSpec`).
///    `rawValue` 는 순서 비교에만 쓰고 어디에도 저장하지 않는다.
enum ProTier: Int, Comparable, CaseIterable {
    case free = 0
    /// 플러스(기억) — 템플릿 저장·불러오기 + 마지막 설정 복원. 상품은 `com.xa.toki.remember`.
    case plus = 1
    /// Pro 전체 — 기억 + 세션 모드·대본·오버타임·기록. 기존 구매자·평생 무료·창단 후원자가 여기다.
    case session = 2

    static func < (lhs: ProTier, rhs: ProTier) -> Bool { lhs.rawValue < rhs.rawValue }

    /// 판정 (순수 함수 — 테스트 대상). Pro 전체 근거가 하나라도 있으면 기억 구매 여부와 무관하게 위다.
    static func resolve(isFullPro: Bool, ownsRemember: Bool) -> ProTier {
        if isFullPro { return .session }
        return ownsRemember ? .plus : .free
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

    /// 상품 가격 문자열. 상품이 아직 안 왔으면(또는 App Store Connect 에 없으면) nil.
    func price(of id: ProductID) -> String? {
        products.first { $0.id == id.rawValue }?.displayPrice
    }

    /// 기억 트림을 팔 수 있는가 — 상품이 실제로 로드됐을 때만. ⚠️ App Store Connect 에 상품을
    /// 만들기 전에 이 빌드가 나가도 페이월은 예전처럼 Pro 한 장만 보여 준다.
    var offersRememberTier: Bool { price(of: .remember) != nil }

    /// Pro 를 살 때 실제로 결제할 상품 — 기억을 이미 가졌고 업그레이드 상품이 있으면 차액 상품.
    var proOffer: ProductID {
        (canRemember && !isPro && price(of: .proUpgrade) != nil) ? .proUpgrade : .pro
    }

    /// Pro 제품 이름
    var proDisplayName: String {
        products
            .first { $0.id == ProductID.pro.rawValue }?
            .displayName ?? AppName.pro
    }

    /// 저장된 구매 기록(래치). Keychain 우선, 없으면 UserDefaults.
    /// ⚠️ 이 값은 회수를 확인했을 때만 내려간다 — `clearStoredPurchaseIfRevoked` 참고.
    /// 이 설치가 **돈을 내고** Pro 를 얻었는가 — 허브의 `flag.isPaid`.
    ///
    /// ⚠️ 2.2.9 까지는 그랜드파더링(`hasPro` 에 포함)으로 열린 사람에게도 구매 기록이 적혔다.
    ///    그 기록은 래치라 지우지 않고(환불 확인 없이 내리지 않는다는 원칙), 셀 때 그랜드파더링을 뺀다.
    ///    평생 무료 사용자에게는 페이월이 뜨지 않아 따로 결제할 길이 없으므로 빼도 결제를 놓치지 않는다.
    nonisolated static var isPaidPurchase: Bool {
        isPaid(storedPurchase: storedPurchaseFlag, grandfathered: isGrandfathered)
    }

    /// `isPaidPurchase` 의 판정 (순수 함수 — 테스트 대상).
    nonisolated static func isPaid(storedPurchase: Bool, grandfathered: Bool) -> Bool {
        storedPurchase && !grandfathered
    }

    nonisolated static var storedPurchaseFlag: Bool {
        KeychainHelper.load(key: "rereminder.pro.purchased")
            ?? UserDefaults.standard.bool(forKey: "rereminder.pro.purchased")
    }

    /// 빠른 Pro 체크 (저장된 값, 네트워크 불필요)
    /// nonisolated — Keychain/UserDefaults만 읽으므로 어디서든 호출 가능
    /// TestFlight/Sandbox 환경과 기존 사용자(그랜드파더링)는 항상 true 를 반환
    /// 기억 트림 구매 기록(래치). Pro 전체와 따로 센다.
    nonisolated static var storedRememberFlag: Bool {
        KeychainHelper.load(key: rememberKey) ?? UserDefaults.standard.bool(forKey: rememberKey)
    }

    /// 이 설치의 트림.
    nonisolated static var tier: ProTier {
        ProTier.resolve(isFullPro: isProUser, ownsRemember: storedRememberFlag)
    }

    /// **설정을 기억해도 되는가** — 기억 트림 이상. `ProGate.canRememberSetup` 의 근거.
    nonisolated static var canRememberSetup: Bool { tier >= .plus }

    nonisolated static var isProUser: Bool {
        if isAutoProEnvironment || isGrandfathered { return true }
        // 창단 후원자 표식은 결제·그랜드파더링에만 주어진다 — 앱을 지워도 남으므로 마지막 근거가 된다.
        if hasFounderRecord { return true }
        return storedPurchaseFlag
    }
}
