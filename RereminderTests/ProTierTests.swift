//
//  ProTierTests.swift
//  RereminderTests
//
//  **트림(무료 · 기억 · Pro)은 기능으로 나뉘고, 위 트림은 아래를 전부 포함한다.**
//
//  지키는 것:
//  - 기억($2.99)을 산 사람은 설정을 기억하지만 세션 모드는 여전히 Pro 다.
//  - Pro 근거(결제·그랜드파더링·창단 후원자)가 하나라도 있으면 기억 구매 여부와 무관하게 Pro 전체다.
//  - 기억 상품은 LeeoStore 의 `hasPro`(= Pro 전체)에 섞이지 않는다.
//  - 페이월 맨 위 한 줄은 숫자가 작으면 뜨지 않는다.
//

import XCTest
import Security
@testable import Rereminder

final class ProTierTests: XCTestCase {

    private static let proKey = "rereminder.pro.purchased"
    private static let rememberKey = "rereminder.remember.purchased"
    private static let devPaywallKey = "dev.testPaywall"
    private static let grandfatherKey = "rereminder.grandfather.granted"

    private var savedDevPaywall = false
    private var savedGrandfather = false

    override func setUpWithError() throws {
        try super.setUpWithError()
        let defaults = UserDefaults.standard
        savedDevPaywall = defaults.bool(forKey: Self.devPaywallKey)
        savedGrandfather = defaults.bool(forKey: Self.grandfatherKey)
        // DEBUG 빌드의 개발자 자동 Pro와 그랜드파더링을 꺼야 "저장된 기록"만 남는다.
        defaults.set(true, forKey: Self.devPaywallKey)
        defaults.removeObject(forKey: Self.grandfatherKey)
        clear()
    }

    override func tearDownWithError() throws {
        clear()
        let defaults = UserDefaults.standard
        defaults.set(savedDevPaywall, forKey: Self.devPaywallKey)
        if savedGrandfather { defaults.set(true, forKey: Self.grandfatherKey) }
        try super.tearDownWithError()
    }

    private func deleteKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func clear() {
        for key in [Self.proKey, Self.rememberKey, Self.grandfatherKey, "rereminder.founder"] {
            UserDefaults.standard.removeObject(forKey: key)
            deleteKeychain(key)
        }
    }

    // MARK: - 판정 (순수 함수)

    func test_resolve_fullProWinsOverRemember() {
        XCTAssertEqual(ProTier.resolve(isFullPro: true, ownsRemember: false), .session)
        XCTAssertEqual(ProTier.resolve(isFullPro: true, ownsRemember: true), .session)
        XCTAssertEqual(ProTier.resolve(isFullPro: false, ownsRemember: true), .remember)
        XCTAssertEqual(ProTier.resolve(isFullPro: false, ownsRemember: false), .free)
    }

    func test_tierOrder() {
        XCTAssertLessThan(ProTier.free, .remember)
        XCTAssertLessThan(ProTier.remember, .session)
    }

    func test_featureTiers() {
        XCTAssertEqual(ProGate.Feature.unlimitedTemplates.tier, .remember)
        XCTAssertEqual(ProGate.Feature.presentationMode.tier, .session)
        XCTAssertEqual(ProGate.Feature.overtimeTracking.tier, .session)
        XCTAssertEqual(ProGate.Feature.timerHistory.tier, .session)
    }

    func test_productTiers() {
        XCTAssertEqual(StoreManager.ProductID.remember.tier, .remember)
        XCTAssertEqual(StoreManager.ProductID.pro.tier, .session)
        XCTAssertEqual(StoreManager.ProductID.proUpgrade.tier, .session)
    }

    // MARK: - 상품 구성

    /// ⚠️ 기억 상품이 entitlementIDs 에 들어가면 LeeoStore 가 기억 구매자를 Pro 전체로 본다.
    func test_rememberIsNotAFullEntitlement() {
        let config = RereminderSpec.paywallConfig
        XCTAssertFalse(config.entitlementIDs.contains(StoreManager.ProductID.remember.rawValue))
        XCTAssertEqual(config.entitlementIDs, StoreManager.fullProductIDs)
        XCTAssertEqual(Set(config.productIDs), Set(StoreManager.ProductID.allCases.map(\.rawValue)))
    }

    /// `purchasePrimary` 는 첫 상품을 산다 — 그게 Pro 전체여야 한다.
    func test_primaryProductIsPro() {
        XCTAssertEqual(RereminderSpec.paywallConfig.productIDs.first, StoreManager.ProductID.pro.rawValue)
    }

    // MARK: - 저장된 기록으로 판정

    func test_noRecord_isFree() {
        XCTAssertEqual(StoreManager.tier, .free)
        XCTAssertFalse(ProGate.canRememberSetup)
    }

    /// 기억을 산 사람은 기억하고, 세션 모드는 열리지 않는다(체험은 그대로 돈다).
    func test_rememberRecord_opensRememberOnly() {
        UserDefaults.standard.set(true, forKey: Self.rememberKey)

        XCTAssertEqual(StoreManager.tier, .remember)
        XCTAssertFalse(StoreManager.isProUser)
        XCTAssertTrue(ProGate.canRememberSetup)
        XCTAssertTrue(ProGate.canSaveTemplate())
        if case .allowed = ProGate.evaluate(.unlimitedTemplates) {} else {
            XCTFail("기억 트림은 템플릿을 열어야 한다")
        }
        if case .allowed = ProGate.evaluate(.presentationMode) {
            XCTFail("기억 트림이 세션 모드를 열면 Pro 를 팔 이유가 사라진다")
        }
    }

    /// 재설치해도 기억 구매가 남는다 — Pro 와 같은 래치.
    func test_rememberRecord_survivesReinstall_viaKeychain() {
        XCTAssertTrue(KeychainHelper.save(key: Self.rememberKey, value: true))
        UserDefaults.standard.removeObject(forKey: Self.rememberKey)
        XCTAssertTrue(StoreManager.storedRememberFlag)
        XCTAssertTrue(ProGate.canRememberSetup)
    }

    /// 기존 Pro 구매자는 기억 기록이 없어도 Pro 전체다 — 기억으로 떨어지면 신뢰 사고다.
    func test_proRecord_isFullTier() {
        UserDefaults.standard.set(true, forKey: Self.proKey)
        XCTAssertEqual(StoreManager.tier, .session)
        XCTAssertTrue(ProGate.canRememberSetup)
    }

    func test_grandfathered_isFullTier() {
        UserDefaults.standard.set(true, forKey: Self.grandfatherKey)
        XCTAssertEqual(StoreManager.tier, .session)
    }

    // MARK: - 페이월 맨 위 한 줄

    func test_receipt_hiddenWhenNumbersAreSmall() {
        XCTAssertNil(PaywallReceipt.pick(completions: 2, sessions: 1, focus: .session))
        XCTAssertNil(PaywallReceipt.pick(completions: 0, sessions: 0, focus: .remember))
    }

    func test_receipt_sessionFocusPrefersSessions() {
        XCTAssertEqual(PaywallReceipt.pick(completions: 10, sessions: 4, focus: .session), .sessions(4))
        // 세션이 적으면 완주 횟수로 물러선다.
        XCTAssertEqual(PaywallReceipt.pick(completions: 10, sessions: 1, focus: .session), .timers(10))
    }

    /// 기억 자리에서는 세션 이야기를 꺼내지 않는다.
    func test_receipt_rememberFocusUsesTimers() {
        XCTAssertEqual(PaywallReceipt.pick(completions: 5, sessions: 9, focus: .remember), .timers(5))
    }
}
