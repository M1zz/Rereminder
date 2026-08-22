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

    func test_canAddPrealert_freeUserUnderLimit_returnsTrue() {
        XCTAssertTrue(ProGate.canAddPrealert(currentCount: 0))
    }

    func test_canAddPrealert_freeUserAtLimitWithTrial_returnsTrue() {
        // count == freePrealertLimit, trial 가능 (count: 0)
        XCTAssertTrue(ProGate.canAddPrealert(currentCount: ProGate.freePrealertLimit))
    }

    func test_canAddPrealert_freeUserExhaustedTrial_returnsFalse() {
        for _ in 0..<5 { TrialCounter.increment(.unlimitedPrealerts) }
        // 1차 페이월 이후, 확장 미수락 — 한도 **위**에서만 막힌다
        XCTAssertFalse(ProGate.canAddPrealert(currentCount: ProGate.freePrealertLimit))
    }

    func test_canSaveTemplate_underFreeLimit_returnsTrue() {
        XCTAssertTrue(ProGate.canSaveTemplate(currentCount: 2))
    }

    func test_canSaveTemplate_atFreeLimit_returnsFalse() {
        XCTAssertFalse(ProGate.canSaveTemplate(currentCount: 3))
    }

    func test_canSaveTemplate_proUser_returnsTrue() {
        setProUser(true)
        XCTAssertTrue(ProGate.canSaveTemplate(currentCount: 100))
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

    // MARK: - 알림 추가 게이트 (prealertAdmission / requestPrealert)
    //
    // 이 정책은 알림을 켤 수 있는 화면마다 복사돼 있었고, 지금은 ProGate 한 곳이 답한다.
    // 화면들이 같은 답을 쓰는 한 여기서 규칙을 지키면 된다.

    func test_prealertAdmission_firstAlertIsFree_evenWhenTrialExhausted() {
        setProUser(false)
        for _ in 0..<10 { TrialCounter.increment(.unlimitedPrealerts) }   // 1·2차 체험 모두 소진

        XCTAssertEqual(ProGate.prealertAdmission(currentCount: 0), .allowed,
                       "1번째 알림은 무료 기능이다 — 체험이 다 떨어져도 막으면 안 된다")
    }

    func test_prealertAdmission_secondAlert_allowedWhileTrialRemains() {
        setProUser(false)
        XCTAssertEqual(ProGate.prealertAdmission(currentCount: ProGate.freePrealertLimit), .allowed)
    }

    func test_prealertAdmission_freeLimitIsTwo_soSecondAlertIsAlwaysFree() {
        setProUser(false)
        for _ in 0..<10 { TrialCounter.increment(.unlimitedPrealerts) }   // 체험 전부 소진

        // 이 앱이 파는 문장은 "여러 번 알려 준다"다 — 2개까지는 체험과 무관하게 무료여야
        // 그 문장이 성립한다(1개면 그냥 평범한 타이머다).
        XCTAssertEqual(ProGate.freePrealertLimit, 2)
        XCTAssertEqual(ProGate.prealertAdmission(currentCount: 1), .allowed)
    }

    func test_prealertAdmission_offersGraceAtLimit_whenTrialExhausted() {
        setProUser(false)
        PrealertGrace.reset()
        for _ in 0..<TrialCounter.firstStageLimit { TrialCounter.increment(.unlimitedPrealerts) }

        // 막힌 자리에서 문을 닫지 않는다 — 오늘치 유예가 남아 있으면 그 자리에서 내준다
        XCTAssertEqual(ProGate.prealertAdmission(currentCount: ProGate.freePrealertLimit),
                       .grace(stage: .first))
    }

    func test_prealertAdmission_blocksAfterGraceIsUsedToday() {
        setProUser(false)
        PrealertGrace.reset()
        for _ in 0..<TrialCounter.firstStageLimit { TrialCounter.increment(.unlimitedPrealerts) }

        PrealertGrace.consume()

        // 하루 한 번이라 두 번째부터는 원래대로 막힌다 — 아니면 게이트가 없는 것과 같다
        XCTAssertEqual(ProGate.prealertAdmission(currentCount: ProGate.freePrealertLimit),
                       .blocked(stage: .first))
    }

    func test_prealertGrace_isAvailableAgainTheNextDay() {
        PrealertGrace.reset()
        let today = Date()
        PrealertGrace.consume(now: today)

        XCTAssertFalse(PrealertGrace.isAvailable(now: today))
        XCTAssertTrue(PrealertGrace.isAvailable(now: today.addingTimeInterval(86_400 + 60)))
    }

    func test_prealertAdmission_proUser_isNeverBlocked() {
        setProUser(true)
        for _ in 0..<10 { TrialCounter.increment(.unlimitedPrealerts) }

        XCTAssertEqual(ProGate.prealertAdmission(currentCount: 99), .allowed)
    }

    func test_prealertAdmission_hasNoSideEffect() {
        setProUser(false)
        let before = TrialCounter.count(for: .unlimitedPrealerts)

        // 자물쇠 아이콘처럼 그릴 때마다 물어보는 경로다 — 물어본 것만으로 상태가 변하면 안 된다
        for _ in 0..<5 { _ = ProGate.prealertAdmission(currentCount: 3) }

        XCTAssertEqual(TrialCounter.count(for: .unlimitedPrealerts), before)
    }

    func test_requestPrealert_matchesPureAdmission_whenNothingIsConsumed() {
        setProUser(false)

        // 허용되는 경우에는 부작용이 없으므로 두 함수의 답이 같아야 한다
        XCTAssertEqual(ProGate.requestPrealert(currentCount: 0),
                       ProGate.prealertAdmission(currentCount: 0))
    }

    func test_requestPrealert_consumesTheGrace_soTheNextTryIsBlocked() {
        setProUser(false)
        PrealertGrace.reset()
        for _ in 0..<TrialCounter.firstStageLimit { TrialCounter.increment(.unlimitedPrealerts) }

        let count = ProGate.freePrealertLimit
        XCTAssertEqual(ProGate.requestPrealert(currentCount: count), .grace(stage: .first))
        // 유예는 하루 한 번 — 실제로 소진돼야 한다(안 그러면 무제한이 된다)
        XCTAssertEqual(ProGate.prealertAdmission(currentCount: count), .blocked(stage: .first))
    }

}
