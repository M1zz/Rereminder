//
//  IntervalListTests.swift
//  RereminderTests
//

import XCTest
@testable import Rereminder

final class IntervalListTests: XCTestCase {
    func test_lengthsBecomeTotalAndBoundaryAlerts() {
        let setup = IntervalList.setup(from: [300, 1200, 300])
        XCTAssertEqual(setup?.total, 1800)
        // 5분 뒤 = 25분 전, 25분 뒤 = 5분 전
        XCTAssertEqual(setup?.offsets, [1500, 300])
    }

    func test_singleIntervalHasNoAlerts() {
        XCTAssertEqual(IntervalList.setup(from: [600])?.offsets, [])
    }

    func test_zeroLengthsAreDropped() {
        XCTAssertEqual(IntervalList.setup(from: [0, 600, 0, 60])?.offsets, [60])
    }

    func test_overTheDialLimitIsRejected() {
        XCTAssertNil(IntervalList.setup(from: [TimeMapper.maxSeconds, 60]))
        XCTAssertNil(IntervalList.setup(from: [0, 0]))
    }

    func test_roundTripFromDial() {
        let lengths = IntervalList.lengths(total: 600, offsets: [180, 60])
        XCTAssertEqual(lengths, [420, 120, 60])
        let back = IntervalList.setup(from: lengths)
        XCTAssertEqual(back?.total, 600)
        XCTAssertEqual(back?.offsets, [180, 60])
    }

    func test_alertsOutsideTheTimerAreIgnored() {
        XCTAssertEqual(IntervalList.lengths(total: 600, offsets: [0, 600, 900, 300]), [300, 300])
    }
}
