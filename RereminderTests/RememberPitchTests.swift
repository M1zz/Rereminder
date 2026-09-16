//
//  RememberPitchTests.swift
//  RereminderTests
//
//  무료 사용자에게 "앱이 기억한다"를 보여 주는 세 자리의 규칙.
//  이 기능도 실패 방식은 하나다 — **잔소리가 되는 것.** 그래서 "언제 입을 다무는가"를 촘촘히 본다.
//

import XCTest
@testable import Rereminder

final class RememberPitchTests: XCTestCase {

    private var suiteName = ""
    private var suite: UserDefaults!
    private var calendar = Calendar(identifier: .gregorian)

    /// 2026-09-16 10:00 KST 근처
    private let now = Date(timeIntervalSince1970: 1_789_520_400)
    private func day(_ n: Int, hours: Double = 0) -> Date {
        now.addingTimeInterval(Double(n) * 86_400 + hours * 3600)
    }

    private let defaultConfig = RepeatDetector.Config(mainSec: 600, offsets: [60])
    private let lastUsed = RepeatDetector.Config(mainSec: 1500, offsets: [300, 180, 60])

    override func setUp() {
        super.setUp()
        suiteName = "RememberPitchTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        RememberPitch.defaults = suite
        RememberPitch.calendar = calendar
        RepeatDetector.defaults = suite
        RepeatDetector.calendar = calendar
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        RememberPitch.defaults = .standard
        RememberPitch.calendar = .current
        RepeatDetector.defaults = .standard
        RepeatDetector.calendar = .current
        super.tearDown()
    }

    private func recall(lastUsed: RepeatDetector.Config? = nil,
                        canRemember: Bool = false,
                        atDefault: Bool = true,
                        at date: Date? = nil) -> RepeatDetector.Config? {
        RememberPitch.recallLine(lastUsed: lastUsed ?? self.lastUsed,
                                 canRemember: canRemember,
                                 isAtDefaultSetup: atDefault,
                                 defaultConfig: defaultConfig,
                                 now: date ?? now)
    }

    // MARK: - ① 다시 연 순간의 한 줄

    func test_recall_showsLastUsedSetupToFreeUser() {
        XCTAssertEqual(recall(), lastUsed)
    }

    func test_recall_notForPro() {
        XCTAssertNil(recall(canRemember: true), "Pro 는 이미 복원됐다 — 말할 것이 없다")
    }

    func test_recall_notWhenDialAlreadyChanged() {
        XCTAssertNil(recall(atDefault: false))
    }

    func test_recall_notWhenLastUsedIsTheDefault() {
        XCTAssertNil(recall(lastUsed: defaultConfig), "잃은 것이 없는데 기억하라고 권하면 거짓말이다")
    }

    func test_recall_onceADay() {
        XCTAssertNotNil(recall())
        RememberPitch.markRecallShown(now: now)
        XCTAssertNil(recall(at: day(0, hours: 5)), "같은 날 두 번 뜨면 잔소리다")
        XCTAssertNotNil(recall(at: day(1)))
    }

    func test_recall_stopsAfterAWeekOfDays() {
        for n in 0..<RememberPitch.maxRecallDays {
            XCTAssertNotNil(recall(at: day(n)))
            RememberPitch.markRecallShown(now: day(n))
            // 같은 날 다시 표시해도 날수는 늘지 않는다
            RememberPitch.markRecallShown(now: day(n, hours: 1))
        }
        XCTAssertEqual(RememberPitch.recallDays, RememberPitch.maxRecallDays)
        XCTAssertNil(recall(at: day(RememberPitch.maxRecallDays)))
    }

    // MARK: - ② 반복 감지 (무료는 한 번)

    func test_repeat_freeUserGetsExactlyOneProposal() {
        let other = RepeatDetector.Config(mainSec: 2700, offsets: [600])
        for config in [lastUsed, other] {
            RepeatDetector.record(config, now: day(-2))
            RepeatDetector.record(config, now: day(-1))
        }

        XCTAssertTrue(RepeatDetector.shouldPropose(lastUsed, isAlreadySaved: false, canSave: false, now: now))
        RepeatDetector.markProposed(lastUsed, asFree: true)

        XCTAssertFalse(RepeatDetector.shouldPropose(other, isAlreadySaved: false, canSave: false, now: now),
                       "무료에게 두 번째 제안부터는 권유가 된다")
        XCTAssertTrue(RepeatDetector.shouldPropose(other, isAlreadySaved: false, canSave: true, now: now),
                      "결제하면 Pro 몫의 상한이 다시 적용된다")
    }

    // MARK: - ③ 다음 자리 전날

    private func booking(on occasion: Date) -> NextOccasionReminder.Booking {
        NextOccasionReminder.Booking(occasionDate: occasion, mainSec: 1200, offsets: [300, 60])
    }

    /// n일 뒤 자정 기준 + 시각
    private func at(dayOffset: Int, hour: Int) -> Date {
        let start = calendar.startOfDay(for: day(dayOffset))
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: start)!
    }

    func test_eve_notBeforeTheEveningBefore() {
        let b = booking(on: at(dayOffset: 3, hour: 14))
        XCTAssertNil(RememberPitch.eveBookingToPrepare(b, now: at(dayOffset: 2, hour: 18)))
        XCTAssertNotNil(RememberPitch.eveBookingToPrepare(b, now: at(dayOffset: 2, hour: 19)))
    }

    func test_eve_stillPreparesOnTheDayItself() {
        let b = booking(on: at(dayOffset: 3, hour: 9))
        XCTAssertNotNil(RememberPitch.eveBookingToPrepare(b, now: at(dayOffset: 3, hour: 13)),
                        "전날 알림을 놓치고 당일에 연 사람이 더 도움이 필요하다")
        XCTAssertNil(RememberPitch.eveBookingToPrepare(b, now: at(dayOffset: 4, hour: 0)))
    }

    func test_eve_preparesOnlyOncePerBooking() {
        let b = booking(on: at(dayOffset: 3, hour: 9))
        let evening = at(dayOffset: 2, hour: 20)
        XCTAssertNotNil(RememberPitch.eveBookingToPrepare(b, now: evening))
        RememberPitch.markEvePrepared(b)
        XCTAssertNil(RememberPitch.eveBookingToPrepare(b, now: evening.addingTimeInterval(1800)),
                     "그 뒤에 바꾼 설정을 다시 덮으면 안 된다")

        let next = booking(on: at(dayOffset: 30, hour: 9))
        XCTAssertNotNil(RememberPitch.eveBookingToPrepare(next, now: at(dayOffset: 29, hour: 20)),
                        "다음 예약은 따로 센다")
    }

    func test_eve_noBooking() {
        XCTAssertNil(RememberPitch.eveBookingToPrepare(nil, now: now))
    }
}
