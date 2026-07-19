//
//  TrialCounterTests.swift
//  RereminderTests
//
//  TrialCounter 단위 테스트
//

import XCTest
@testable import Rereminder

final class TrialCounterTests: XCTestCase {

    private static let suiteName = "TrialCounterTests.suite"
    private var testDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDefaults = UserDefaults(suiteName: Self.suiteName)
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        TrialCounter.defaults = testDefaults
    }

    override func tearDownWithError() throws {
        testDefaults.removePersistentDomain(forName: Self.suiteName)
        TrialCounter.defaults = .standard
        try super.tearDownWithError()
    }

    // MARK: - Count

    func test_count_default_returnsZero() {
        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 0)
    }

    func test_increment_addsOneToCount() {
        TrialCounter.increment(.presentationMode)
        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 1)
    }

    func test_increment_multipleTimes_accumulates() {
        TrialCounter.increment(.presentationMode)
        TrialCounter.increment(.presentationMode)
        TrialCounter.increment(.presentationMode)
        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 3)
    }

    func test_increment_isIsolatedPerFeature() {
        TrialCounter.increment(.presentationMode)
        TrialCounter.increment(.presentationMode)
        TrialCounter.increment(.timerHistory)

        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 2)
        XCTAssertEqual(TrialCounter.count(for: .timerHistory), 1)
        XCTAssertEqual(TrialCounter.count(for: .overtimeTracking), 0)
    }

    // MARK: - Extension

    func test_extensionAccepted_default_returnsFalse() {
        XCTAssertFalse(TrialCounter.extensionAccepted(for: .presentationMode))
    }

    func test_acceptExtension_setsToTrue() {
        TrialCounter.acceptExtension(for: .presentationMode)
        XCTAssertTrue(TrialCounter.extensionAccepted(for: .presentationMode))
    }

    func test_acceptExtension_isIsolatedPerFeature() {
        TrialCounter.acceptExtension(for: .presentationMode)
        XCTAssertTrue(TrialCounter.extensionAccepted(for: .presentationMode))
        XCTAssertFalse(TrialCounter.extensionAccepted(for: .timerHistory))
    }

    // MARK: - Reset

    func test_reset_clearsBothCountAndExtension() {
        TrialCounter.increment(.presentationMode)
        TrialCounter.increment(.presentationMode)
        TrialCounter.acceptExtension(.presentationMode)

        TrialCounter.reset(.presentationMode)

        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 0)
        XCTAssertFalse(TrialCounter.extensionAccepted(for: .presentationMode))
    }

    func test_reset_doesNotAffectOtherFeatures() {
        TrialCounter.increment(.presentationMode)
        TrialCounter.increment(.timerHistory)

        TrialCounter.reset(.presentationMode)

        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 0)
        XCTAssertEqual(TrialCounter.count(for: .timerHistory), 1)
    }

    func test_resetAll_clearsEveryFeature() {
        TrialCounter.increment(.presentationMode)
        TrialCounter.increment(.timerHistory)
        TrialCounter.increment(.overtimeTracking)
        TrialCounter.acceptExtension(.presentationMode)

        TrialCounter.resetAll()

        for feature in ProGate.Feature.allCases {
            XCTAssertEqual(TrialCounter.count(for: feature), 0,
                           "\(feature.rawValue) count should be reset")
            XCTAssertFalse(TrialCounter.extensionAccepted(for: feature),
                           "\(feature.rawValue) extension should be reset")
        }
    }

    // MARK: - Limits

    func test_limits_areFiveAndTen() {
        XCTAssertEqual(TrialCounter.firstStageLimit, 5)
        XCTAssertEqual(TrialCounter.secondStageLimit, 10)
    }

    // Helper: TrialCounter has only acceptExtension without label, but tests use labeled call
}

// 라벨 없는 호출을 위한 편의 확장 (테스트 가독성용)
private extension TrialCounter {
    static func acceptExtension(_ feature: ProGate.Feature) {
        acceptExtension(for: feature)
    }
}
