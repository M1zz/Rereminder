//
//  RereminderUITests.swift
//  RereminderUITests
//
//  실제 앱을 띄워 핵심 흐름 한 바퀴(시작 → 일시정지 → 재개 → 정지 → 설정)를 돌고,
//  주 화면의 접근성 감사를 한다.
//
//  화면 상태는 DEBUG 빌드의 `ScreenshotScene` 이 세운다(`-screenshotScene dial`) — 장면이 걸리면
//  온보딩·안내·알림 권한 창이 끼지 않는다. 언어는 영어로 고정해 버튼 이름으로 찾는다.
//

import XCTest

final class RereminderUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-screenshotScene", "dial",
                               "-hasSeenOnboarding", "YES",
                               "-AppleLanguages", "(en)",
                               "-AppleLocale", "en_US"]
        app.launch()
    }

    /// 시작 전 "알림 권한이 꺼져 있어요" 안내가 뜨면 "나중에"로 넘긴다(시뮬레이터는 권한이 없다).
    private func dismissPermissionWarningIfShown() {
        let later = app.alerts.buttons["Later"]
        if later.waitForExistence(timeout: 2) { later.tap() }
    }

    func testCoreTimerFlow() throws {
        let start = app.buttons["Start Timer"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        dismissPermissionWarningIfShown()

        let pause = app.buttons["Pause Timer"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()

        let resume = app.buttons["Resume Timer"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()

        let cancel = app.buttons["Cancel Timer"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.buttons["Start Timer"].waitForExistence(timeout: 5))

        // 설정 — 개발자 메일·새로 생긴 것 행이 있다.
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        // SwiftUI `Link` 는 버튼이 아니라 링크로 잡힌다 — 종류를 가리지 않고 이름으로 찾는다.
        let list = app.collectionViews.firstMatch
        let mail = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Email the Developer")).firstMatch
        for _ in 0..<8 where !mail.exists { list.swipeUp() }
        XCTAssertTrue(mail.exists)
    }

    func testMainScreenAccessibilityAudit() throws {
        XCTAssertTrue(app.buttons["Start Timer"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit { issue in
            // 글자 크기만 거른다: 다이얼 위 글자(가운데 시간·링의 구간 번호)는 원 크기에 맞춰 그려야 링 밖으로
            // 넘치지 않고, 원 아래 구간 길이 칩은 큰 글씨에서 링을 덮지 않게 일부러 상한을 두었다
            // (TimerMainView.centerTimeDisplay · SectionLengthBar). 대비·라벨·터치 영역 등 나머지는 그대로 실패시킨다.
            if issue.auditType == .dynamicType { return true }
            return false
        }
    }
}
