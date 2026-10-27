//
//  PricingLadderTests.swift
//  RereminderTests
//
//  **세 칸 요금제(2026-10 개편)의 권한 판정.** 무료 · 기억(Plus) · Pro, 유료 칸마다 연 구독과 평생.
//
//  지키는 것:
//  - 상품마다 여는 칸: 연 구독은 같은 칸의 평생과 같고, 올리기 · 졸업은 Pro 평생과 같다.
//  - 연 구독은 래치(Keychain)에 적지 않는다. 만료일이 지나면 닫힌다.
//  - 언제나 평생 패스는 가장 높은 칸(Pro)을 연다. 패스 상품은 앱의 상품 목록 밖에 있다.
//  - 이미 산 사람(평생 Pro · 기억 평생 · 그랜드파더링)은 구독이 끝나도 그대로다.
//

import XCTest
import Security
import LeeoKit
@testable import Rereminder

final class PricingLadderTests: XCTestCase {

    private typealias PID = StoreManager.ProductID

    private static let proKey = "rereminder.pro.purchased"
    private static let rememberKey = "rereminder.remember.purchased"
    private static let devPaywallKey = "dev.testPaywall"
    private static let grandfatherKey = "rereminder.grandfather.granted"
    private static let passKey = "rereminder.foreverPass.active"

    private var savedDevPaywall = false
    private var savedGrandfather = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        let defaults = UserDefaults.standard
        savedDevPaywall = defaults.bool(forKey: Self.devPaywallKey)
        savedGrandfather = defaults.bool(forKey: Self.grandfatherKey)
        // DEBUG 빌드의 개발자 자동 Pro와 그랜드파더링을 꺼야 "저장된 기록"만 남는다.
        defaults.set(true, forKey: Self.devPaywallKey)
        clear()
    }

    override func tearDownWithError() throws {
        clear()
        let defaults = UserDefaults.standard
        defaults.set(savedDevPaywall, forKey: Self.devPaywallKey)
        if savedGrandfather { defaults.set(true, forKey: Self.grandfatherKey) }
        try super.tearDownWithError()
    }

    private func clear() {
        for key in [Self.proKey, Self.rememberKey, Self.grandfatherKey, "rereminder.founder"] {
            UserDefaults.standard.removeObject(forKey: key)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
            ]
            SecItemDelete(query as CFDictionary)
        }
        UserDefaults.standard.removeObject(forKey: Self.passKey)
        SubscriptionMark.clear()
    }

    private func mark(_ id: PID, expiresIn seconds: TimeInterval) {
        SubscriptionMark.save(.init(productID: id.rawValue, expiresAt: Date().addingTimeInterval(seconds)))
    }

    // MARK: - 상품이 여는 칸 (순수 함수)

    func test_eachProductOpensItsTier() {
        XCTAssertEqual(ProTier.granted(by: [PID.remember.rawValue]), .plus)
        XCTAssertEqual(ProTier.granted(by: [PID.plusYearly.rawValue]), .plus)
        XCTAssertEqual(ProTier.granted(by: [PID.pro.rawValue]), .session)
        XCTAssertEqual(ProTier.granted(by: [PID.proYearly.rawValue]), .session)
        XCTAssertEqual(ProTier.granted(by: [PID.proUpgrade.rawValue]), .session, "올리기는 Pro 평생과 같다")
        XCTAssertEqual(ProTier.granted(by: [PID.proGraduate.rawValue]), .session, "졸업은 Pro 평생과 같다")
    }

    func test_higherTierWins() {
        XCTAssertEqual(ProTier.granted(by: [PID.plusYearly.rawValue, PID.proGraduate.rawValue]), .session)
        XCTAssertEqual(ProTier.granted(by: [PID.remember.rawValue, PID.plusYearly.rawValue]), .plus)
    }

    /// 팁 · 선물 · 패스 상품은 이 판정에서 아무것도 열지 않는다(선물은 받은 쪽에 pro 로, 패스는 `LeeoForeverPass` 가 연다).
    func test_tipGiftPassOpenNothingHere() {
        var others = Set(StoreManager.tipProductIDs)
        others.insert(StoreManager.giftProductID)
        others.formUnion(LeeoForeverPassRule.productIDs(bundleID: "com.xa.toki"))
        XCTAssertEqual(ProTier.granted(by: others), .free)
        XCTAssertEqual(ProTier.granted(by: []), .free)
    }

    func test_resolve_withSubscription() {
        XCTAssertEqual(ProTier.resolve(isFullPro: false, ownsRemember: false, subscription: .plus), .plus)
        XCTAssertEqual(ProTier.resolve(isFullPro: false, ownsRemember: true, subscription: .session), .session)
        XCTAssertEqual(ProTier.resolve(isFullPro: false, ownsRemember: true, subscription: .free), .plus)
        XCTAssertEqual(ProTier.resolve(isFullPro: true, ownsRemember: false, subscription: .free), .session)
    }

    // MARK: - 상품 구성

    func test_entitlementsAreFullProOnly() {
        let ids = RereminderSpec.paywallConfig.entitlementIDs
        XCTAssertEqual(ids, [PID.pro.rawValue, PID.proUpgrade.rawValue, PID.proGraduate.rawValue, PID.proYearly.rawValue])
        XCTAssertFalse(ids.contains(PID.plusYearly.rawValue), "기억 연 구독이 Pro 전체가 되면 안 된다")
        XCTAssertFalse(ids.contains(PID.remember.rawValue))
    }

    /// 연 구독을 래치에 적으면 구독이 끝나도 Pro 가 남는다.
    func test_latchHoldsLifetimeOnly() {
        XCTAssertTrue(StoreManager.lifetimeProProductIDs.isDisjoint(with: StoreManager.subscriptionProductIDs))
        XCTAssertEqual(StoreManager.subscriptionProductIDs, [PID.plusYearly.rawValue, PID.proYearly.rawValue])
        XCTAssertTrue(StoreManager.lifetimeProProductIDs.contains(PID.proGraduate.rawValue))
        XCTAssertTrue(StoreManager.lifetimeProProductIDs.contains(PID.proUpgrade.rawValue))
    }

    func test_passProductsStayOutOfTheAppCatalog() {
        let pass = Set(LeeoForeverPassRule.productIDs(bundleID: "com.xa.toki"))
        XCTAssertTrue(pass.isDisjoint(with: RereminderSpec.paywallConfig.productIDs))
        XCTAssertTrue(LeeoForeverPassRule.family.contains("com.xa.toki"))
    }

    func test_newProductIDsKeepThePrefix() {
        for id in PID.allCases { XCTAssertTrue(id.rawValue.hasPrefix("com.xa.toki."), id.rawValue) }
        XCTAssertEqual(Set(RereminderSpec.paywallConfig.productIDs), Set(PID.allCases.map(\.rawValue)))
    }

    // MARK: - 구독 표식

    func test_subscriptionMark_tier() {
        let now = Date()
        let future = now.addingTimeInterval(3600)
        XCTAssertEqual(SubscriptionMark.tier(of: .init(productID: PID.proYearly.rawValue, expiresAt: future), now: now), .session)
        XCTAssertEqual(SubscriptionMark.tier(of: .init(productID: PID.plusYearly.rawValue, expiresAt: future), now: now), .plus)
        XCTAssertEqual(SubscriptionMark.tier(of: .init(productID: PID.proYearly.rawValue, expiresAt: now.addingTimeInterval(-1)), now: now),
                       .free, "만료된 구독은 아무것도 열지 않는다")
        XCTAssertEqual(SubscriptionMark.tier(of: .init(productID: PID.pro.rawValue, expiresAt: future), now: now),
                       .free, "평생 상품은 구독 표식으로 읽지 않는다")
        XCTAssertEqual(SubscriptionMark.tier(of: nil, now: now), .free)
    }

    func test_subscriptionMark_bestPrefersHigherTierThenLaterExpiry() {
        let soon = Date().addingTimeInterval(100)
        let later = Date().addingTimeInterval(1000)
        let plusLater = SubscriptionMark.Entry(productID: PID.plusYearly.rawValue, expiresAt: later)
        let proSoon = SubscriptionMark.Entry(productID: PID.proYearly.rawValue, expiresAt: soon)
        let proLater = SubscriptionMark.Entry(productID: PID.proYearly.rawValue, expiresAt: later)
        XCTAssertEqual(SubscriptionMark.best([plusLater, proSoon]), proSoon)
        XCTAssertEqual(SubscriptionMark.best([proSoon, proLater]), proLater)
        XCTAssertNil(SubscriptionMark.best([]))
    }

    // MARK: - 저장된 상태로 판정

    func test_proYearly_opensProUntilItExpires() {
        mark(.proYearly, expiresIn: 3600)
        XCTAssertTrue(StoreManager.isProUser)
        XCTAssertEqual(StoreManager.tier, .session)

        mark(.proYearly, expiresIn: -60)
        XCTAssertFalse(StoreManager.isProUser, "구독이 끝나면 Pro 도 끝난다")
        XCTAssertEqual(StoreManager.tier, .free)
    }

    func test_plusYearly_opensRememberOnly() {
        mark(.plusYearly, expiresIn: 3600)
        XCTAssertFalse(StoreManager.isProUser)
        XCTAssertEqual(StoreManager.tier, .plus)
        XCTAssertTrue(ProGate.canRememberSetup)
        if case .allowed = ProGate.evaluate(.presentationMode) {
            XCTFail("기억 연 구독이 세션 모드를 열면 안 된다")
        }
    }

    func test_foreverPass_opensPro() {
        UserDefaults.standard.set(true, forKey: Self.passKey)
        XCTAssertTrue(StoreManager.hasForeverPass)
        XCTAssertTrue(StoreManager.isProUser)
        XCTAssertEqual(StoreManager.tier, .session)
    }

    // MARK: - 이미 가진 사람은 그대로

    func test_lifetimeProSurvivesExpiredSubscription() {
        UserDefaults.standard.set(true, forKey: Self.proKey)
        mark(.proYearly, expiresIn: -60)
        XCTAssertTrue(StoreManager.isProUser)
    }

    func test_lifetimeRememberSurvivesExpiredSubscription() {
        UserDefaults.standard.set(true, forKey: Self.rememberKey)
        mark(.plusYearly, expiresIn: -60)
        XCTAssertEqual(StoreManager.tier, .plus)
    }

    func test_rememberOwnerWithProYearlyIsPro() {
        UserDefaults.standard.set(true, forKey: Self.rememberKey)
        mark(.proYearly, expiresIn: 3600)
        XCTAssertEqual(StoreManager.tier, .session)
    }

    func test_grandfatheredStaysPro() {
        UserDefaults.standard.set(true, forKey: Self.grandfatherKey)
        XCTAssertTrue(StoreManager.isProUser)
        XCTAssertEqual(StoreManager.tier, .session)
    }

    func test_subscriberCountsAsPaid() {
        XCTAssertFalse(StoreManager.isPaidPurchase)
        mark(.plusYearly, expiresIn: 3600)
        XCTAssertTrue(StoreManager.isPaidPurchase)
    }
}
