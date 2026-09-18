//
//  StorePurchaseLatchTests.swift
//  RereminderTests
//
//  **결제한 사용자에게 페이월이 다시 뜨지 않는다** — 이 파일이 지키는 한 문장이다.
//
//  예전에는 `store.hasPro` 가 false 로 바뀌면 그대로 Keychain 에 false 를 적었다.
//  그런데 `Transaction.currentEntitlements` 는 App Store 계정 로그아웃·기기 초기화 직후·
//  StoreKit 캐시 미형성에서도 조용히 빈 값을 내므로, 그 한 번이 재설치에도 살아남으라고
//  넣어 둔 평생 해제 기록을 지웠다. 그래서 기록을 내리는 근거는 **회수(환불)를 직접
//  확인했을 때** 하나뿐이다.
//

import XCTest
import Security
@testable import Rereminder

final class StorePurchaseLatchTests: XCTestCase {

    private static let proKey = "rereminder.pro.purchased"
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
        clearStoredPurchase()
    }

    override func tearDownWithError() throws {
        clearStoredPurchase()
        let defaults = UserDefaults.standard
        defaults.set(savedDevPaywall, forKey: Self.devPaywallKey)
        if savedGrandfather { defaults.set(true, forKey: Self.grandfatherKey) }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func deleteKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func clearStoredPurchase() {
        UserDefaults.standard.removeObject(forKey: Self.proKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.proKey,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - 회수 판정 (기록을 내려도 되는가)

    /// ⚠️ **이 테스트가 이 라운드의 핵심이다.** 조회가 비었다는 것은 환불의 근거가 아니다.
    func test_emptyTransactionList_isNotRevocation() {
        XCTAssertFalse(
            StoreManager.isRevoked(proTransactionRevocationDates: []),
            "조회에 아무것도 안 잡힌 것을 환불로 읽으면, App Store 로그아웃 한 번으로 평생 해제가 지워진다"
        )
    }

    func test_liveTransaction_isNotRevocation() {
        XCTAssertFalse(StoreManager.isRevoked(proTransactionRevocationDates: [nil]))
    }

    func test_revokedTransaction_isRevocation() {
        XCTAssertTrue(StoreManager.isRevoked(proTransactionRevocationDates: [Date()]))
    }

    /// 환불 후 재구매 — 회수된 것과 살아 있는 것이 함께 있으면 회수가 아니다.
    func test_revokedThenRepurchased_isNotRevocation() {
        XCTAssertFalse(StoreManager.isRevoked(proTransactionRevocationDates: [Date(), nil]))
    }

    func test_allRevoked_isRevocation() {
        XCTAssertTrue(StoreManager.isRevoked(proTransactionRevocationDates: [Date(), Date()]))
    }

    // MARK: - 저장된 기록 → Pro 판정

    func test_storedPurchase_makesUserPro() {
        UserDefaults.standard.set(true, forKey: Self.proKey)
        XCTAssertTrue(StoreManager.storedPurchaseFlag)
        XCTAssertTrue(StoreManager.isProUser)
    }

    func test_noStoredPurchase_isNotPro() {
        XCTAssertFalse(StoreManager.storedPurchaseFlag)
        XCTAssertFalse(StoreManager.isProUser)
    }

    /// Keychain 에 기록이 있으면 UserDefaults 가 비어도 Pro 다 (재설치 시나리오).
    func test_keychainOnlyRecord_survivesEmptyDefaults() {
        XCTAssertTrue(KeychainHelper.save(key: Self.proKey, value: true))
        UserDefaults.standard.removeObject(forKey: Self.proKey)
        XCTAssertTrue(StoreManager.storedPurchaseFlag)
        XCTAssertTrue(StoreManager.isProUser)
    }

    /// 게이트도 같은 판정을 따라야 한다 — 여기가 갈라지면 결제한 사용자가 기능에서 막힌다.
    func test_proGateFollowsStoredPurchase() {
        UserDefaults.standard.set(true, forKey: Self.proKey)
        XCTAssertTrue(ProGate.canRememberSetup)
        XCTAssertTrue(ProGate.canSaveTemplate())
    }

    // MARK: - 평생 무료를 잃어버리는 길 (2026-09-18 제보)

    /// ⚠️ **앱을 지웠다 깔아도 평생 무료는 남아야 한다.** 예전에는 이 자격이 UserDefaults 에만
    ///    있어서 재설치 한 번에 통째로 사라졌고, 재판정에 쓰는 흔적도 같이 지워져 영영 돌아오지 않았다.
    func test_grandfatheredSurvivesReinstall_viaKeychain() {
        let key = Self.grandfatherKey
        defer { deleteKeychain(key); UserDefaults.standard.removeObject(forKey: key) }

        // 재설치 직후: UserDefaults 는 비었고 Keychain 에만 기록이 남아 있다.
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertTrue(KeychainHelper.save(key: key, value: true))

        XCTAssertTrue(StoreManager.isGrandfathered)
        XCTAssertTrue(StoreManager.isProUser)
        // 한 번 읽으면 UserDefaults 도 되살아나 다음부터는 빠르게 판정한다.
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
    }

    /// 창단 후원자 표식은 결제·그랜드파더링에만 주어진다 — 앱을 지워도 남는 마지막 근거다.
    func test_founderRecordAloneRestoresPro() {
        let founderKey = "rereminder.founder"
        defer { deleteKeychain(founderKey); deleteKeychain(Self.grandfatherKey)
                UserDefaults.standard.removeObject(forKey: Self.grandfatherKey) }

        deleteKeychain(Self.grandfatherKey)
        UserDefaults.standard.removeObject(forKey: Self.grandfatherKey)
        XCTAssertFalse(StoreManager.isProUser)

        XCTAssertTrue(KeychainHelper.save(key: founderKey, value: true))
        XCTAssertTrue(StoreManager.recoverLostEntitlementIfPossible())
        XCTAssertTrue(StoreManager.isProUser)
    }

    /// ⚠️ **아무 근거도 없는 사람에게 평생 무료를 주지 않는다.** 복구는 Keychain 에 남은 기록만 본다 —
    ///    옛 흔적 검사(테마·완주 횟수)를 다시 돌리면 새로 깐 사람에게도 자격이 나간다.
    func test_recoveryGivesNothingWithoutARecord() {
        deleteKeychain(Self.grandfatherKey)
        deleteKeychain("rereminder.founder")
        UserDefaults.standard.removeObject(forKey: Self.grandfatherKey)

        XCTAssertFalse(StoreManager.recoverLostEntitlementIfPossible())
        XCTAssertFalse(StoreManager.isProUser)
    }
}
