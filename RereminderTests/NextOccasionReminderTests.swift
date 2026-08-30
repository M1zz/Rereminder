//
//  NextOccasionReminderTests.swift
//  RereminderTests
//
//  "다음 자리 언제세요?"를 **언제 묻고 언제 입을 다무는지**의 규칙 검증.
//
//  이 기능의 실패 방식은 하나뿐이다 — **잔소리가 되는 것.** 세션을 안 쓴 사람에게 묻거나,
//  매주 오는 사람에게 묻거나, 거절한 사람에게 또 묻거나, 예약해 둔 사람에게 다시 묻는 순간
//  이 기능은 얻는 것 없이 신뢰만 깎는다.
//

import XCTest
@testable import Rereminder

final class NextOccasionReminderTests: XCTestCase {

    private var suiteName = ""
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "NextOccasionReminderTests.\(UUID().uuidString)"
        NextOccasionReminder.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        NextOccasionReminder.calendar = calendar
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        NextOccasionReminder.defaults = .standard
        NextOccasionReminder.calendar = .current
        super.tearDown()
    }

    private func ask(session: Bool = true,
                     completions: Int = 1,
                     weekly: Bool = false) -> Bool {
        NextOccasionReminder.shouldAsk(didUseSessionMode: session,
                                       completions: completions,
                                       repeatsWeekly: weekly,
                                       now: now)
    }

    // MARK: - 누구에게 묻나

    func testAsksAfterASessionRun() {
        XCTAssertTrue(ask())
    }

    /// 평범한 타이머를 쓴 사람에게는 "다음 자리"가 없다.
    func testDoesNotAskAfterAPlainTimerRun() {
        XCTAssertFalse(ask(session: false))
    }

    /// 매주 오는 사람은 알아서 돌아온다 — 물으면 잔소리다.
    func testDoesNotAskSomeoneWhoAlreadyRepeatsWeekly() {
        XCTAssertFalse(ask(weekly: true))
    }

    // MARK: - 상한과 유예

    func testStopsAfterTheAskLimit() {
        for _ in 0..<NextOccasionReminder.maxAsks { NextOccasionReminder.markAsked() }
        XCTAssertFalse(ask())
    }

    func testDeclineSilencesItUntilEnoughMoreCompletions() {
        NextOccasionReminder.decline(completions: 3)

        XCTAssertFalse(ask(completions: 3))
        XCTAssertFalse(ask(completions: 3 + NextOccasionReminder.declineCooldown - 1))
        XCTAssertTrue(ask(completions: 3 + NextOccasionReminder.declineCooldown))
    }

    // MARK: - 예약이 있으면 묻지 않는다

    func testDoesNotAskWhileABookingIsStillAhead() {
        NextOccasionReminder.booking = .init(occasionDate: now.addingTimeInterval(86_400 * 30),
                                             mainSec: 600, offsets: [300, 60])
        XCTAssertFalse(ask())
    }

    /// 지나간 예약은 막지 않는다 — 막으면 발표 한 번 하고 영영 다시 안 묻는다.
    func testAsksAgainOnceTheBookingHasPassed() {
        NextOccasionReminder.booking = .init(occasionDate: now.addingTimeInterval(-86_400),
                                             mainSec: 600, offsets: [300, 60])
        XCTAssertTrue(ask())
    }

    func testClearIfPassedRemovesOnlyPastBookings() {
        NextOccasionReminder.booking = .init(occasionDate: now.addingTimeInterval(86_400),
                                             mainSec: 600, offsets: [300])
        NextOccasionReminder.clearIfPassed(now: now)
        XCTAssertNotNil(NextOccasionReminder.booking)

        NextOccasionReminder.booking = .init(occasionDate: now.addingTimeInterval(-60),
                                             mainSec: 600, offsets: [300])
        NextOccasionReminder.clearIfPassed(now: now)
        XCTAssertNil(NextOccasionReminder.booking)
    }

    // MARK: - 언제 울리나

    /// 발표 전날 저녁이 리허설 시간대다 — 당일 아침에 알려 봐야 고칠 수 있는 게 없다.
    func testFiresTheEveningBefore() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let occasion = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 14))!

        let fire = NextOccasionReminder.Booking.fireDate(for: occasion, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: fire!)

        XCTAssertEqual(parts.day, 19)
        XCTAssertEqual(parts.month, 11)
        XCTAssertEqual(parts.hour, NextOccasionReminder.reminderHour)
    }

    /// 내일 자리는 이미 늦었다 — 전날 저녁이 지났기 때문이다.
    func testEarliestSelectableDateIsTheDayAfterTomorrow() {
        let earliest = NextOccasionReminder.earliestSelectableDate(now: now)
        let days = NextOccasionReminder.calendar.dateComponents(
            [.day],
            from: NextOccasionReminder.calendar.startOfDay(for: now),
            to: earliest
        ).day
        XCTAssertEqual(days, 2)
    }

    /// 전날 저녁이 이미 지난 날짜는 예약하지 않는다(조용히 안 울리는 알림을 남기지 않는다).
    func testDoesNotBookWhenTheEveningBeforeHasPassed() {
        let tooSoon = now.addingTimeInterval(60 * 60)
        XCTAssertFalse(NextOccasionReminder.book(occasion: tooSoon, mainSec: 600,
                                                 offsets: [300], now: now))
        XCTAssertNil(NextOccasionReminder.booking)
    }
}
