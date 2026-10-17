//
//  NotificationPermissionWarningTests.swift
//  RereminderTests
//
//  알림 권한 없이 시작하면 경고가 뜨는가.
//  권한이 없으면 앱이 앞에 있을 때만 울리고 **화면을 끄면 아무것도 울리지 않는다** —
//  "잠금 화면이 울리지 않는다"는 제보의 정체. 예전엔 `useAlarmKit` 이 켜져 있을 때만 경고해서
//  (기본값 꺼짐) 사실상 아무에게도 뜨지 않았다.
//

import XCTest
import UserNotifications
@testable import Rereminder

@MainActor
final class NotificationPermissionWarningTests: XCTestCase {

    private let alarmKitKey = "useAlarmKit"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: alarmKitKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: alarmKitKey)
        super.tearDown()
    }

    // MARK: - 판정

    func test_denied_warns() {
        XCTAssertTrue(TimerScreenViewModel.shouldWarnBeforeStart(authStatus: .denied, alreadyWarned: false))
    }

    func test_authorized_or_unknown_doesNotWarn() {
        XCTAssertFalse(TimerScreenViewModel.shouldWarnBeforeStart(authStatus: .authorized, alreadyWarned: false))
        XCTAssertFalse(TimerScreenViewModel.shouldWarnBeforeStart(authStatus: .notDetermined, alreadyWarned: false))
        XCTAssertFalse(TimerScreenViewModel.shouldWarnBeforeStart(authStatus: nil, alreadyWarned: false))
    }

    func test_onlyOncePerLaunch() {
        XCTAssertFalse(TimerScreenViewModel.shouldWarnBeforeStart(authStatus: .denied, alreadyWarned: true))
    }

    // MARK: - 시작 흐름

    private func makeDeniedScreen() -> TimerScreenViewModel {
        let screen = TimerScreenViewModel()
        let appState = AppStateManager()
        appState.notificationAuthStatus = .denied
        screen.timerVM.appStateManager = appState
        screen.initialConfiguration()
        return screen
    }

    /// 회귀: AlarmKit 이 꺼져 있어도(기본값) 경고가 떠야 한다.
    func test_start_withAlarmKitOff_holdsAndWarns() {
        let screen = makeDeniedScreen()
        screen.start()

        XCTAssertTrue(screen.showPermissionWarning)
        XCTAssertEqual(screen.state, .idle, "경고에 답하기 전에는 시작하지 않는다")
    }

    func test_later_startsTimer_andDoesNotAskAgain() {
        let screen = makeDeniedScreen()
        screen.start()
        screen.showPermissionWarning = false
        screen.continueStartWithoutPermission()
        XCTAssertEqual(screen.state, .running)

        screen.timerVM.stop()
        screen.start()
        XCTAssertFalse(screen.showPermissionWarning, "한 번 실행에 한 번만 묻는다")
        XCTAssertEqual(screen.state, .running)
        screen.timerVM.stop()
    }
}
