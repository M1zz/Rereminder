//
//  ProGateTests.swift
//  RereminderTests
//
//  ProGate 5+5 trial 게이트 로직 테스트
//

import XCTest
import Security
@testable import Rereminder

final class ProGateTests: XCTestCase {

    private static let trialSuiteName = "ProGateTests.trialSuite"
    private var trialDefaults: UserDefaults!

    private static let proKey = "rereminder.pro.purchased"
    private static let devPaywallKey = "dev.testPaywall"
    private static let grandfatherKey = "rereminder.grandfather.granted"

    // 테스트 종료 후 원복할 호스트 앱의 원래 상태
    private var savedDevPaywall: Bool = false
    private var savedGrandfather: Bool = false

    override func setUpWithError() throws {
        try super.setUpWithError()

        // TrialCounter 격리
        trialDefaults = UserDefaults(suiteName: Self.trialSuiteName)
        trialDefaults.removePersistentDomain(forName: Self.trialSuiteName)
        TrialCounter.defaults = trialDefaults

        // DEBUG 빌드의 개발자 자동 Pro(isDeveloperUnlock)와 그랜드파더링을 꺼서
        // "무료 사용자" 전제를 만든다. 끝나면 원래 값으로 되돌린다.
        let defaults = UserDefaults.standard
        savedDevPaywall = defaults.bool(forKey: Self.devPaywallKey)
        savedGrandfather = defaults.bool(forKey: Self.grandfatherKey)
        defaults.set(true, forKey: Self.devPaywallKey)
        defaults.removeObject(forKey: Self.grandfatherKey)

        // Pro 상태 클리어
        clearProState()
    }

    override func tearDownWithError() throws {
        trialDefaults.removePersistentDomain(forName: Self.trialSuiteName)
        TrialCounter.defaults = .standard
        clearProState()

        let defaults = UserDefaults.standard
        defaults.set(savedDevPaywall, forKey: Self.devPaywallKey)
        if savedGrandfather {
            defaults.set(true, forKey: Self.grandfatherKey)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func clearProState() {
        UserDefaults.standard.removeObject(forKey: Self.proKey)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.proKey,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.Ysoup.Rereminder",
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func setProUser(_ pro: Bool) {
        clearProState()
        if pro {
            UserDefaults.standard.set(true, forKey: Self.proKey)
        }
    }

    // MARK: - Pro user

    func test_evaluate_proUser_returnsAllowed() {
        setProUser(true)
        for feature in ProGate.Feature.allCases {
            let result = ProGate.evaluate(feature)
            if case .allowed = result {
                // OK
            } else {
                XCTFail("Pro user should be allowed for \(feature.rawValue), got \(result)")
            }
        }
    }

    // MARK: - First stage trial

    func test_evaluate_freshFreeUser_returnsAllowedWithFiveRemaining() {
        let result = ProGate.evaluate(.presentationMode)
        guard case .allowedWithTrial(let remaining, let stage) = result else {
            return XCTFail("Expected allowedWithTrial, got \(result)")
        }
        XCTAssertEqual(remaining, 5)
        XCTAssertEqual(stage, .first)
    }

    func test_evaluate_afterFourUses_returnsOneRemaining() {
        for _ in 0..<4 { TrialCounter.increment(.presentationMode) }
        let result = ProGate.evaluate(.presentationMode)
        guard case .allowedWithTrial(let remaining, let stage) = result else {
            return XCTFail("Expected allowedWithTrial, got \(result)")
        }
        XCTAssertEqual(remaining, 1)
        XCTAssertEqual(stage, .first)
    }

    func test_evaluate_atFiveUsesWithoutExtension_returnsBlockedFirstStage() {
        for _ in 0..<5 { TrialCounter.increment(.presentationMode) }
        let result = ProGate.evaluate(.presentationMode)
        guard case .blocked(let stage) = result else {
            return XCTFail("Expected blocked, got \(result)")
        }
        XCTAssertEqual(stage, .first)
    }

    // MARK: - Extension and second stage

    func test_evaluate_afterAcceptingExtension_returnsAllowedSecondStage() {
        for _ in 0..<5 { TrialCounter.increment(.presentationMode) }
        ProGate.acceptExtendedTrial(.presentationMode)

        let result = ProGate.evaluate(.presentationMode)
        guard case .allowedWithTrial(let remaining, let stage) = result else {
            return XCTFail("Expected allowedWithTrial, got \(result)")
        }
        XCTAssertEqual(remaining, 5)
        XCTAssertEqual(stage, .second)
    }

    func test_evaluate_atNineUsesWithExtension_returnsOneRemaining() {
        for _ in 0..<9 { TrialCounter.increment(.presentationMode) }
        ProGate.acceptExtendedTrial(.presentationMode)

        let result = ProGate.evaluate(.presentationMode)
        guard case .allowedWithTrial(let remaining, let stage) = result else {
            return XCTFail("Expected allowedWithTrial, got \(result)")
        }
        XCTAssertEqual(remaining, 1)
        XCTAssertEqual(stage, .second)
    }

    func test_evaluate_atTenUsesWithExtension_returnsBlockedSecondStage() {
        for _ in 0..<10 { TrialCounter.increment(.presentationMode) }
        ProGate.acceptExtendedTrial(.presentationMode)

        let result = ProGate.evaluate(.presentationMode)
        guard case .blocked(let stage) = result else {
            return XCTFail("Expected blocked, got \(result)")
        }
        XCTAssertEqual(stage, .second)
    }

    // MARK: - Non-trial features

    func test_evaluate_unlimitedTemplates_freeUser_returnsBlocked() {
        let result = ProGate.evaluate(.unlimitedTemplates)
        guard case .blocked = result else {
            return XCTFail("Templates without trial support should be blocked, got \(result)")
        }
    }

    func test_evaluate_unlimitedTemplates_proUser_returnsAllowed() {
        setProUser(true)
        let result = ProGate.evaluate(.unlimitedTemplates)
        guard case .allowed = result else {
            return XCTFail("Pro user should be allowed for templates, got \(result)")
        }
    }

    // MARK: - recordUsage

    func test_recordUsage_freeUser_incrementsCounter() {
        ProGate.recordUsage(.presentationMode)
        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 1)

        ProGate.recordUsage(.presentationMode)
        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 2)
    }

    func test_recordUsage_proUser_doesNotIncrement() {
        setProUser(true)
        ProGate.recordUsage(.presentationMode)
        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 0)
    }

    func test_recordUsage_unlimitedTemplates_doesNotIncrement() {
        ProGate.recordUsage(.unlimitedTemplates)
        XCTAssertEqual(TrialCounter.count(for: .unlimitedTemplates), 0)
    }

    // MARK: - acceptExtendedTrial

    func test_acceptExtendedTrial_setsExtensionFlag() {
        XCTAssertFalse(TrialCounter.extensionAccepted(for: .presentationMode))
        ProGate.acceptExtendedTrial(.presentationMode)
        XCTAssertTrue(TrialCounter.extensionAccepted(for: .presentationMode))
    }

    func test_acceptExtendedTrial_unlimitedTemplates_isNoOp() {
        ProGate.acceptExtendedTrial(.unlimitedTemplates)
        XCTAssertFalse(TrialCounter.extensionAccepted(for: .unlimitedTemplates))
    }

    // MARK: - Legacy bool API

    /// ⚠️ 무료 몫이 없다 — **저장 자체가 Pro** 다. 개수로 다시 나누지 말 것(`ProGate` 머리말).
    func test_canSaveTemplate_freeUser_isAlwaysFalse() {
        setProUser(false)
        XCTAssertFalse(ProGate.canSaveTemplate(currentCount: 0))
        XCTAssertFalse(ProGate.canRememberSetup)
    }

    func test_canSaveTemplate_proUser_returnsTrue() {
        setProUser(true)
        XCTAssertTrue(ProGate.canSaveTemplate(currentCount: 100))
        XCTAssertTrue(ProGate.canRememberSetup)
    }

    // MARK: - Full lifecycle integration

    func test_fullLifecycle_freeUserUsesAllElevenAttempts() {
        // 1~5: allowedWithTrial(stage: .first)
        for i in 1...5 {
            let result = ProGate.evaluate(.presentationMode)
            guard case .allowedWithTrial(let r, let s) = result else {
                return XCTFail("attempt \(i): expected allowedWithTrial, got \(result)")
            }
            XCTAssertEqual(r, 6 - i, "attempt \(i) remaining")
            XCTAssertEqual(s, .first)
            ProGate.recordUsage(.presentationMode)
        }

        // 6번째 시도: blocked(.first)
        if case .blocked(let stage) = ProGate.evaluate(.presentationMode) {
            XCTAssertEqual(stage, .first)
        } else {
            XCTFail("attempt 6: expected blocked first")
        }

        // 사용자 확장 수락
        ProGate.acceptExtendedTrial(.presentationMode)

        // 6~10: allowedWithTrial(stage: .second)
        for i in 6...10 {
            let result = ProGate.evaluate(.presentationMode)
            guard case .allowedWithTrial(let r, let s) = result else {
                return XCTFail("attempt \(i): expected allowedWithTrial, got \(result)")
            }
            XCTAssertEqual(r, 11 - i, "attempt \(i) remaining")
            XCTAssertEqual(s, .second)
            ProGate.recordUsage(.presentationMode)
        }

        // 11번째 시도: blocked(.second)
        if case .blocked(let stage) = ProGate.evaluate(.presentationMode) {
            XCTAssertEqual(stage, .second)
        } else {
            XCTFail("attempt 11: expected blocked second")
        }
    }

    // MARK: - 알림에는 한도가 없다
    //
    // 예전에는 여기서 "몇 개까지 무료인가"를 지켰다. 그 한도를 없앴으므로,
    // 이제 지킬 것은 **한도가 다시 생기지 않는 것**이다.
    // 알림 개수는 이 앱을 설치할 유일한 이유이고, 거기에 벽을 세우면 걸리는 사람이 하필
    // 결제 가능성이 가장 큰 사람(발표자·강사·퍼실리테이터)이다.

    func test_alertCountIsNotAProFeature() {
        XCTAssertFalse(ProGate.Feature.allCases.contains { $0.rawValue.lowercased().contains("prealert") },
                       "예비 알림이 다시 Pro 기능 목록에 들어왔다 — ProGate 머리말 참고")
    }

    func test_paidFeaturesAreTheSessionTools() {
        XCTAssertEqual(Set(ProGate.Feature.allCases),
                       [.presentationMode, .overtimeTracking, .unlimitedTemplates, .timerHistory])
    }

    // MARK: - 허브로 나가는 판정 (flag.isTrial · flag.trialExhausted)
    //
    // 이 두 값은 익명 통계 허브에서 "결제에 가장 가까운 사람"을 세는 근거다
    // (`ActivityReporter.currentMetrics`). 한 번 틀리면 화면 전체가 조용히 거짓이 되므로
    // 경계를 여기서 못박는다.

    /// **갓 깐 설치는 체험자가 아니다.** 세 기능이 모두 `allowedWithTrial(remaining: 5)` 라서
    /// "아직 안 막혔다"로 세면 신규 설치가 전부 체험자가 된다 — 다른 앱에서 신규 설치의
    /// 99%가 유료로 기록된 것과 같은 실수다.
    func test_freshInstall_isNotBurningTrial() {
        XCTAssertFalse(ProGate.isBurningTrial)
        XCTAssertFalse(ProGate.isTrialExhausted)
    }

    func test_afterUsingOnce_isBurningTrial() {
        TrialCounter.increment(.presentationMode)
        XCTAssertTrue(ProGate.isBurningTrial)
        XCTAssertFalse(ProGate.isTrialExhausted)
    }

    func test_whenTrialRunsOut_isExhaustedNotBurning() {
        for _ in 0..<5 { TrialCounter.increment(.presentationMode) }
        XCTAssertTrue(ProGate.isTrialExhausted)
        XCTAssertFalse(ProGate.isBurningTrial, "막힌 사람을 체험 중으로도 세면 두 칸에 겹쳐 든다")
    }

    /// 체험은 기능마다 따로 돈다. 하나가 막혀도 다른 하나가 남아 있으면 둘 다 참이다 —
    /// 그 사람 앞에는 벽이 서 있고(막힘), 동시에 아직 태울 것도 남았다(체험).
    func test_blockedOnOneFeature_stillBurningOnAnother() {
        for _ in 0..<5 { TrialCounter.increment(.timerHistory) }
        TrialCounter.increment(.presentationMode)
        XCTAssertTrue(ProGate.isTrialExhausted)
        XCTAssertTrue(ProGate.isBurningTrial)
    }

    /// 연장을 받으면 벽이 10으로 물러난다. 허브가 한도를 베껴 적지 않고 이 판정을 그대로
    /// 받는 이유가 이것이다 — 같은 횟수라도 연장 여부에 따라 답이 다르다.
    func test_extendedTrial_isBurningAgainAtSameCount() {
        for _ in 0..<5 { TrialCounter.increment(.presentationMode) }
        XCTAssertTrue(ProGate.isTrialExhausted)
        ProGate.acceptExtendedTrial(.presentationMode)
        XCTAssertFalse(ProGate.isTrialExhausted)
        XCTAssertTrue(ProGate.isBurningTrial)
    }

    /// 결제한 사람은 어느 쪽도 아니다. 허브의 결제 축에서 체험이 유료를 갉아먹으면 안 된다.
    func test_proUser_isNeitherTrialNorExhausted() {
        for _ in 0..<20 { TrialCounter.increment(.presentationMode) }
        setProUser(true)
        XCTAssertFalse(ProGate.isBurningTrial)
        XCTAssertFalse(ProGate.isTrialExhausted)
    }

    /// 체험이 없는 hard gate(기억하기)는 이 두 판정에 끼어들지 않는다. 끼면 무료 사용자가
    /// 전부 "막힘"이 되어, 값을 낼 이유가 지금 있는 사람을 못 골라낸다.
    func test_hardGateFeature_doesNotCountAsExhausted() {
        XCTAssertFalse(ProGate.Feature.unlimitedTemplates.supportsTrial)
        XCTAssertFalse(ProGate.isTrialExhausted)
    }
}
