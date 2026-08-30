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
}
