//
//  FeedbackNudgeTests.swift
//  RereminderTests
//
//  의견 요청 노출 정책 검증 — 너무 자주 물으면 짜증나고, 안 물으면 아무 말도 못 듣는다.
//  타이밍이 조용히 틀어지는 걸 막는 게 이 테스트의 목적이다.
//

import XCTest
@testable import Rereminder

final class FeedbackNudgeTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - 첫 노출

    func test_firstShow_waitsUntilTenthLaunch() {
        XCTAssertFalse(FeedbackNudge.shouldShow(launchCount: 9, lastShownLaunch: 0, snoozedAt: nil, now: now))
        XCTAssertTrue(FeedbackNudge.shouldShow(launchCount: 10, lastShownLaunch: 0, snoozedAt: nil, now: now))
    }

    // MARK: - 반복 간격

    func test_repeatShow_needsFortyMoreLaunches() {
        XCTAssertFalse(FeedbackNudge.shouldShow(launchCount: 49, lastShownLaunch: 10, snoozedAt: nil, now: now))
        XCTAssertTrue(FeedbackNudge.shouldShow(launchCount: 50, lastShownLaunch: 10, snoozedAt: nil, now: now))
    }

    // MARK: - 다시 보지 않기 = 6개월 유예

    func test_snooze_silencesForSixMonthsThenComesBack() {
        let justSnoozed = now.addingTimeInterval(-60 * 60 * 24 * 30)     // 한 달 전
        XCTAssertFalse(FeedbackNudge.shouldShow(launchCount: 999, lastShownLaunch: 0,
                                                snoozedAt: justSnoozed, now: now))

        let longAgo = now.addingTimeInterval(-FeedbackNudge.snoozeDuration - 1)
        XCTAssertTrue(FeedbackNudge.shouldShow(launchCount: 999, lastShownLaunch: 0,
                                               snoozedAt: longAgo, now: now),
                      "'다시 보지 않기'는 영구 중단이 아니라 유예다 — 6개월 뒤에는 다시 물어봐야 한다")
    }

    func test_snooze_doesNotOverrideIntervalRule() {
        // 유예가 풀렸어도 간격 조건은 여전히 지켜야 한다
        let longAgo = now.addingTimeInterval(-FeedbackNudge.snoozeDuration - 1)
        XCTAssertFalse(FeedbackNudge.shouldShow(launchCount: 20, lastShownLaunch: 10,
                                                snoozedAt: longAgo, now: now))
    }
}
