//
//  WatchStartedTimerTests.swift
//  RereminderTests
//
//  워치에서 건 타이머를 받은 아이폰은 뒤에서 합류하는 기기이고, 워치와 같은 순간에 끝난다.
//

import XCTest
@testable import Rereminder

final class WatchStartedTimerTests: XCTestCase {

    func test_endDate_countsFromWhenWatchSent() {
        let now = Date(timeIntervalSince1970: 1_000)
        let data = TimerSyncData(duration: 600, prealertOffsets: [], timestamp: 997)
        XCTAssertEqual(data.endDate(now: now).timeIntervalSince1970, 1_597)
    }

    func test_endDate_neverStartsLaterThanNow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let data = TimerSyncData(duration: 600, prealertOffsets: [], timestamp: 1_005)
        XCTAssertEqual(data.endDate(now: now).timeIntervalSince1970, 1_600)
    }

    func test_receivedTimerIsSecondary_ownTimerIsPrimary() {
        let engine = TimerEngine()
        defer { engine.stop() }

        engine.applyRemoteRunning(mainSeconds: 600, prealertOffsetsSec: [60], name: "",
                                  endDate: Date().addingTimeInterval(600))
        XCTAssertEqual(engine.escalationRole, .secondary)
        XCTAssertEqual(engine.state, .running)

        engine.configure(mainSeconds: 600, prealertOffsetsSec: [60], name: "")
        engine.start()
        XCTAssertEqual(engine.escalationRole, .primary)
    }
}
