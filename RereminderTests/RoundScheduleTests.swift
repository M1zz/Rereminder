//
//  RoundScheduleTests.swift
//  RereminderTests
//
//  반복(링 한 바퀴 × N회)의 시간 계산과 알림 예약 몫을 지킨다.
//

import XCTest
@testable import Rereminder

final class RoundScheduleTests: XCTestCase {
    /// 제보 그대로: 운동 1:00 + 휴식 0:30 = 1:30 한 회, 알림은 휴식 시작(끝 30초 전).
    private let round: TimeInterval = 90
    private let offsets: [TimeInterval] = [30]

    func test_roundIndexAndRemaining_followElapsed() {
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: 0, roundSeconds: round, rounds: 27), 0)
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: 89, roundSeconds: round, rounds: 27), 0)
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: 90, roundSeconds: round, rounds: 27), 1)
        XCTAssertEqual(RoundSchedule.roundRemaining(elapsed: 100, roundSeconds: round, rounds: 27), 80)
    }

    func test_afterLastRound_staysOnLastAndGoesNegative() {
        let total = RoundSchedule.total(roundSeconds: round, rounds: 3)
        XCTAssertEqual(total, 270)
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: 300, roundSeconds: round, rounds: 3), 2)
        XCTAssertEqual(RoundSchedule.roundRemaining(elapsed: 300, roundSeconds: round, rounds: 3), -30)
    }

    func test_upcoming_ordersAlertsAndRoundEnds_withoutFinalEnd() {
        let events = RoundSchedule.upcoming(roundSeconds: round, rounds: 2, offsets: offsets,
                                            after: 0, limit: 100)
        XCTAssertEqual(events.map(\.at), [60, 90, 150])
        XCTAssertEqual(events[1].kind, .roundEnd)
        // 마지막 회의 끝(180)은 종료 알림 몫이라 없다
        XCTAssertFalse(events.contains { $0.at == 180 })
    }

    func test_upcoming_skipsPassedAndRespectsLimit() {
        let events = RoundSchedule.upcoming(roundSeconds: round, rounds: 27, offsets: offsets,
                                            after: 95, limit: 3)
        XCTAssertEqual(events.map(\.at), [150, 180, 240])
        XCTAssertEqual(events.first?.round, 1)
    }

    func test_identifiers_areUniquePerRound() {
        let events = RoundSchedule.upcoming(roundSeconds: round, rounds: 27, offsets: offsets,
                                            after: 0, limit: 1000)
        XCTAssertEqual(Set(events.map(\.identifierSuffix)).count, events.count)
        XCTAssertEqual(events.count, RoundSchedule.eventCount(roundSeconds: round, rounds: 27, offsets: offsets))
    }

    func test_singleRound_isPlainTimer() {
        let events = RoundSchedule.upcoming(roundSeconds: 600, rounds: 1, offsets: [180, 60],
                                            after: 0, limit: 100)
        XCTAssertEqual(events.map(\.at), [420, 540])
        XCTAssertNil(RoundSchedule.lastCoveredRound(roundSeconds: 600, rounds: 1, offsets: [180, 60], budget: 59))
    }

    func test_coverage_whenTooManyForBudget() {
        // 27회 × (알림 1 + 회 끝 1) - 1 = 53개 → 몫 59 면 다 들어간다
        XCTAssertNil(RoundSchedule.lastCoveredRound(roundSeconds: round, rounds: 27, offsets: offsets, budget: 59))
        // 되풀이 알림이 24개를 쓰면 몫이 35 — 17회 끝까지(34개)와 18회의 알림 하나 — 온전히 울리는 건 17회째까지
        let budget = RoundSchedule.budget(escalationCount: 24)
        XCTAssertEqual(budget, 35)
        XCTAssertEqual(RoundSchedule.lastCoveredRound(roundSeconds: round, rounds: 27, offsets: offsets, budget: budget), 17)
    }
}
