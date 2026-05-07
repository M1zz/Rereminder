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

    override func setUpWithError() throws {
        try super.setUpWithError()

        // TrialCounter 격리
        trialDefaults = UserDefaults(suiteName: Self.trialSuiteName)
        trialDefaults.removePersistentDomain(forName: Self.trialSuiteName)
        TrialCounter.defaults = trialDefaults

        // Pro 상태 클리어
        clearProState()
    }

    override func tearDownWithError() throws {
        trialDefaults.removePersistentDomain(forName: Self.trialSuiteName)
        TrialCounter.defaults = .standard
        clearProState()
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
        // count == freePrealertLimit (1), trial 가능 (count: 0)
        XCTAssertTrue(ProGate.canAddPrealert(currentCount: 1))
    }

    func test_canAddPrealert_freeUserExhaustedTrial_returnsFalse() {
        for _ in 0..<5 { TrialCounter.increment(.unlimitedPrealerts) }
        // 1차 페이월 이후, 확장 미수락
        XCTAssertFalse(ProGate.canAddPrealert(currentCount: 1))
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
}
