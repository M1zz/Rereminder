//
//  FoundingSupporterTests.swift
//  RereminderTests
//
//  창단 후원자 자격의 규칙 검증.
//
//  이 규칙이 조용히 틀어지면 **약속을 어기게 된다** — 값을 치른 사람의 자격이 사라지거나,
//  새 가격에 산 사람에게 평생 무료가 나가거나, 고맙다는 말이 두 번 뜬다.
//  특히 "한 번 준 자격은 회수하지 않는다"는 되돌릴 수 없는 성질이라 테스트로 못박아 둔다.
//

import XCTest
@testable import Rereminder

final class FoundingSupporterTests: XCTestCase {

    private var suiteName = ""
    /// Keychain 대신 쓰는 가짜 저장소 — 진짜 Keychain 은 시뮬레이터에 남아 다음 테스트로 샌다.
    private var keychainBool: [String: Bool] = [:]
    private var keychainText: [String: String] = [:]

    /// 이 버전을 처음 실행하는 순간.
    private let firstLaunch = Date(timeIntervalSince1970: 1_800_000_000)
    private var beforeWindow: Date { firstLaunch.addingTimeInterval(-86_400) }
    private var afterWindow: Date { firstLaunch.addingTimeInterval(86_400) }

    override func setUp() {
        super.setUp()
        suiteName = "FoundingSupporterTests.\(UUID().uuidString)"
        FoundingSupporter.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        keychainBool = [:]
        keychainText = [:]
        FoundingSupporter.keychainRead = { [unowned self] in self.keychainBool[$0] }
        FoundingSupporter.keychainWrite = { [unowned self] in self.keychainBool[$0] = $1 }
        FoundingSupporter.keychainReadString = { [unowned self] in self.keychainText[$0] }
        FoundingSupporter.keychainWriteString = { [unowned self] in self.keychainText[$0] = $1 }
        FoundingSupporter.keychainClear = { [unowned self] in
            self.keychainBool[$0] = nil
            self.keychainText[$0] = nil
        }
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        FoundingSupporter.defaults = .standard
        FoundingSupporter.keychainRead = { KeychainHelper.load(key: $0) }
        FoundingSupporter.keychainWrite = { _ = KeychainHelper.save(key: $0, value: $1) }
        FoundingSupporter.keychainReadString = { KeychainHelper.loadString(key: $0) }
        FoundingSupporter.keychainWriteString = { _ = KeychainHelper.save(key: $0, value: $1) }
        FoundingSupporter.keychainClear = { KeychainHelper.delete(key: $0) }
        super.tearDown()
    }

    /// 앱을 지웠다 다시 깐 상황 — UserDefaults 는 비고 Keychain 만 남는다.
    private func simulateReinstall() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        FoundingSupporter.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - 기본

    func testFreshInstallIsNotFounder() {
        XCTAssertFalse(FoundingSupporter.isFounder)
        XCTAssertNil(FoundingSupporter.origin)
        XCTAssertNil(FoundingSupporter.windowClosedAt)
    }

    // MARK: - 창은 이 버전 첫 실행에 닫힌다

    func testWindowClosesOnceAndKeepsTheFirstTimestamp() {
        XCTAssertTrue(FoundingSupporter.closeWindowIfNeeded(now: firstLaunch))
        XCTAssertEqual(FoundingSupporter.windowClosedAt, firstLaunch)

        // 두 번째 실행은 경계를 밀지 않는다.
        XCTAssertFalse(FoundingSupporter.closeWindowIfNeeded(now: afterWindow))
        XCTAssertEqual(FoundingSupporter.windowClosedAt, firstLaunch)
    }

    /// 재설치해도 경계는 그대로여야 한다 — 밀리면 새 가격에 산 사람이 자격을 주워 간다.
    func testWindowSurvivesReinstallViaKeychain() {
        FoundingSupporter.closeWindowIfNeeded(now: firstLaunch)
        simulateReinstall()

        XCTAssertEqual(
            FoundingSupporter.windowClosedAt.map { Int($0.timeIntervalSince1970) },
            Int(firstLaunch.timeIntervalSince1970)
        )
        XCTAssertFalse(FoundingSupporter.closeWindowIfNeeded(now: afterWindow))
    }

    // MARK: - 첫 실행 상태로 판정 (StoreKit 없이)

    func testProAtFirstLaunchGrants() {
        let granted = FoundingSupporter.refreshFromCurrentState(
            now: firstLaunch, isGrandfathered: false, isPro: true, isAutoPro: false)
        XCTAssertTrue(granted)
        XCTAssertEqual(FoundingSupporter.origin, .purchased)
    }

    func testNotProAtFirstLaunchDoesNotGrant() {
        let granted = FoundingSupporter.refreshFromCurrentState(
            now: firstLaunch, isGrandfathered: false, isPro: false, isAutoPro: false)
        XCTAssertFalse(granted)
        XCTAssertFalse(FoundingSupporter.isFounder)
    }

    /// 창이 닫힌 뒤에 Pro 가 된 사람은 새 가격에 산 사람이다 — 이 경로로 자격이 나가면 안 된다.
    func testBecomingProAfterWindowClosedDoesNotGrant() {
        FoundingSupporter.refreshFromCurrentState(
            now: firstLaunch, isGrandfathered: false, isPro: false, isAutoPro: false)

        let granted = FoundingSupporter.refreshFromCurrentState(
            now: afterWindow, isGrandfathered: false, isPro: true, isAutoPro: false)
        XCTAssertFalse(granted)
        XCTAssertFalse(FoundingSupporter.isFounder)
    }

    /// 개발/샌드박스/맥의 자동 Pro 는 결제가 아니다 — 자격을 주면 안 된다.
    func testAutoProEnvironmentDoesNotGrant() {
        let granted = FoundingSupporter.refreshFromCurrentState(
            now: firstLaunch, isGrandfathered: false, isPro: true, isAutoPro: true)
        XCTAssertFalse(granted)
    }

    /// 그랜드파더링된 사람에게는 이미 "평생 무료"라고 말해 뒀다 — 창과 무관하게 같은 대접.
    func testGrandfatheredGrantsEvenAfterWindowClosed() {
        FoundingSupporter.closeWindowIfNeeded(now: firstLaunch)

        let granted = FoundingSupporter.refreshFromCurrentState(
            now: afterWindow, isGrandfathered: true, isPro: true, isAutoPro: false)
        XCTAssertTrue(granted)
        XCTAssertEqual(FoundingSupporter.origin, .grandfathered)
    }

    // MARK: - StoreKit 결제 시각으로 판정 (복원 경로)

    func testPurchaseBeforeWindowGrants() {
        FoundingSupporter.closeWindowIfNeeded(now: firstLaunch)
        XCTAssertTrue(FoundingSupporter.considerPurchase(date: beforeWindow))
        XCTAssertEqual(FoundingSupporter.origin, .purchased)
    }

    func testPurchaseAfterWindowDoesNotGrant() {
        FoundingSupporter.closeWindowIfNeeded(now: firstLaunch)
        XCTAssertFalse(FoundingSupporter.considerPurchase(date: afterWindow))
        XCTAssertFalse(FoundingSupporter.isFounder)
    }

    func testUnknownPurchaseDateDoesNotGrant() {
        FoundingSupporter.closeWindowIfNeeded(now: firstLaunch)
        XCTAssertFalse(FoundingSupporter.considerPurchase(date: nil))
        XCTAssertFalse(FoundingSupporter.isFounder)
    }

    /// 경계가 없으면 비교할 것이 없다 — 창이 닫히기 전에는 판정하지 않는다.
    func testNoJudgementBeforeWindowCloses() {
        XCTAssertFalse(FoundingSupporter.considerPurchase(date: beforeWindow))
        XCTAssertFalse(FoundingSupporter.isFounder)
    }

    /// 한참 뒤에 새 기기에서 복원한 옛 구매자 — 자격이 살아 돌아와야 한다.
    func testRestoreLongAfterWindowStillGrantsForEarlyPurchase() {
        FoundingSupporter.closeWindowIfNeeded(now: firstLaunch)
        simulateReinstall()

        XCTAssertTrue(FoundingSupporter.considerPurchase(date: beforeWindow))
        XCTAssertTrue(FoundingSupporter.isFounder)
    }

    /// 새 가격에 산 사람이 재설치·복원으로 자격을 주워 가면 안 된다.
    /// (창이 닫힌 시각이 Keychain 에 남아 있어야만 막힌다.)
    func testReinstallDoesNotLetLatePurchaserSneakIn() {
        FoundingSupporter.refreshFromCurrentState(
            now: firstLaunch, isGrandfathered: false, isPro: false, isAutoPro: false)
        simulateReinstall()

        XCTAssertFalse(FoundingSupporter.considerPurchase(date: afterWindow))
        XCTAssertFalse(FoundingSupporter.isFounder)
    }

    // MARK: - 회수는 없다

    func testGrantIsIdempotentAndNeverOverwritesOrigin() {
        XCTAssertTrue(FoundingSupporter.grant(.grandfathered))
        XCTAssertFalse(FoundingSupporter.grant(.purchased))
        XCTAssertEqual(FoundingSupporter.origin, .grandfathered)
    }

    /// 나중에 Pro 가 아닌 상태로 판정이 돌아도 자격은 남아야 한다.
    /// (약속은 되돌릴 수 없다 — 여기서 false 가 나오면 그 약속을 깬 것이다.)
    func testStatusSurvivesLaterNonProState() {
        FoundingSupporter.grant(.purchased)
        FoundingSupporter.refreshFromCurrentState(
            now: afterWindow, isGrandfathered: false, isPro: false, isAutoPro: false)
        XCTAssertTrue(FoundingSupporter.isFounder)
    }

    /// 앱을 지웠다 다시 깔면 UserDefaults 는 비지만 Keychain 은 남는다 —
    /// 출처를 잃었을 뿐 자격은 살아 있으므로 결제한 것으로 본다.
    func testKeychainAloneRestoresStatusAfterReinstall() {
        FoundingSupporter.grant(.purchased)
        simulateReinstall()

        XCTAssertTrue(FoundingSupporter.isFounder)
        XCTAssertEqual(FoundingSupporter.origin, .purchased)
    }

    // MARK: - 안내는 한 번만

    func testAnnouncementShowsOnceForFounder() {
        FoundingSupporter.grant(.purchased)
        XCTAssertTrue(FoundingSupporter.shouldAnnounce)

        FoundingSupporter.markAnnounced()
        XCTAssertFalse(FoundingSupporter.shouldAnnounce)
    }

    func testNonFounderNeverSeesAnnouncement() {
        XCTAssertFalse(FoundingSupporter.shouldAnnounce)
    }

    // MARK: - 안내 화면의 내용

    /// 변경 목록이 비면 화면이 "무엇이 바뀌는지" 없이 뜬다 — 그 화면은 불안만 남긴다.
    func testChangeListIsNotEmptyAndHasUniqueIDs() {
        let changes = FounderChange.current
        XCTAssertFalse(changes.isEmpty)
        XCTAssertEqual(Set(changes.map(\.id)).count, changes.count)
    }
}
