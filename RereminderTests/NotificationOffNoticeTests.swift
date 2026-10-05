//
//  NotificationOffNoticeTests.swift
//  RereminderTests
//
//  알림 꺼짐 한 줄의 주기 규칙.
//  - 권한이 꺼져 있을 때만 선다
//  - 닫으면 3일 쉬고 **다시 나온다** (영영 닫히면 고장 난 채로 계속 쓴다)
//  - 권한을 켜면 쉬는 기록을 지운다 (다시 끄면 그날 바로 알려야 한다)
//

import XCTest
import UserNotifications
@testable import Rereminder

final class NotificationOffNoticeTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "NotificationOffNoticeTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func day(_ offset: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: base)!
    }

    func test_showsOnlyWhenDenied() {
        XCTAssertTrue(NotificationOffNotice.shouldShow(authStatus: .denied, defaults: defaults))
        XCTAssertFalse(NotificationOffNotice.shouldShow(authStatus: .authorized, defaults: defaults))
        XCTAssertFalse(NotificationOffNotice.shouldShow(authStatus: .notDetermined, defaults: defaults))
        XCTAssertFalse(NotificationOffNotice.shouldShow(authStatus: .provisional, defaults: defaults))
    }

    func test_dismiss_restsThenComesBack() {
        let now = Date()
        NotificationOffNotice.dismiss(now: now, defaults: defaults)

        XCTAssertFalse(NotificationOffNotice.shouldShow(authStatus: .denied, now: now, defaults: defaults))
        XCTAssertFalse(NotificationOffNotice.shouldShow(authStatus: .denied,
                                                        now: day(NotificationOffNotice.snoozeDays - 1, from: now),
                                                        defaults: defaults))
        XCTAssertTrue(NotificationOffNotice.shouldShow(authStatus: .denied,
                                                       now: day(NotificationOffNotice.snoozeDays, from: now),
                                                       defaults: defaults),
                      "쉬는 기간이 끝나면 다시 나와야 한다")
    }

    func test_grantingClearsSnooze_soTurningOffAgainShowsImmediately() {
        let now = Date()
        NotificationOffNotice.dismiss(now: now, defaults: defaults)
        NotificationOffNotice.resetIfAllowed(authStatus: .authorized, defaults: defaults)

        XCTAssertTrue(NotificationOffNotice.shouldShow(authStatus: .denied, now: now, defaults: defaults))
    }

    func test_stillDenied_keepsSnooze() {
        let now = Date()
        NotificationOffNotice.dismiss(now: now, defaults: defaults)
        NotificationOffNotice.resetIfAllowed(authStatus: .denied, defaults: defaults)

        XCTAssertFalse(NotificationOffNotice.shouldShow(authStatus: .denied, now: now, defaults: defaults))
    }
}
