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

        // 설정 ▸ 더 보기 — 개발자 메일 행이 있다.
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let more = app.buttons["More"].firstMatch
        for _ in 0..<8 where !more.isHittable { app.collectionViews.firstMatch.swipeUp() }
        more.tap()
        XCTAssertTrue(app.navigationBars["More"].waitForExistence(timeout: 5))
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

    // MARK: - 심사용 녹화

    /// App Review 가 요구한 "앱을 켜는 순간부터 흐름 전체" 녹화를 시뮬레이터에서 찍을 때 쓴다.
    /// 평소 테스트(배포 전 검사)에서는 건너뛴다 — 1분 타이머를 끝까지 기다려 느리다.
    /// 찍는 법: `docs/app-review/review-information.md` ▸ 녹화.
    func testReviewDemo() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["REVIEW_DEMO"] == "1", "심사 녹화 때만")
        app.terminate()
        app.launchArguments = ["-screenshotScene", "reviewDemo",
                               "-hasSeenOnboarding", "YES",
                               "-blankStart.completions", "9",
                               "-blankStart.complexityAsked", "YES",
                               "-dev.testPaywall", "YES",
                               "-AppleLanguages", "(en)",
                               "-AppleLocale", "en_US"]
        app.launch()
        pause(3)

        // 1) 1분 타이머 — 시작, 일시정지, 재개, 30초 전 예비 알림, 끝
        let start = app.buttons["Start Timer"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        dismissPermissionWarningIfShown()
        pause(2)
        app.buttons["Pause Timer"].tap()
        pause(2)
        app.buttons["Resume Timer"].tap()
        let done = app.buttons["Dismiss timer alert"]
        XCTAssertTrue(done.waitForExistence(timeout: 90))
        pause(3)
        done.tap()
        pause(2)
        // 끝난 뒤에는 넘긴 시간(+00:05)을 센다 — 정지로 처음으로 돌아간다
        let stop = app.buttons["Cancel Timer"]
        if stop.waitForExistence(timeout: 3) { stop.tap() }
        pause(2)

        // 2) 반복 — 구간 목록에서 0:30 + 0:30 을 세 번
        let time = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Timer, Ready")).firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        time.tap()
        let intervals = app.buttons["Intervals"]
        XCTAssertTrue(intervals.waitForExistence(timeout: 5))
        pause(1)
        intervals.tap()
        pause(2)
        let repeatRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Repeat")).firstMatch
        XCTAssertTrue(repeatRow.waitForExistence(timeout: 5))
        repeatRow.swipeUp(); pause(1)
        let plus = repeatRow.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -58, dy: 0))
        plus.tap(); pause(1)
        plus.tap(); pause(2)
        app.buttons["Apply"].firstMatch.tap()
        pause(3)
        start.tap()
        dismissPermissionWarningIfShown()
        pause(3)
        app.buttons["Cancel Timer"].tap()
        pause(2)

        // 3) 세션 모드 — 구간 이름과 대본이 도는 동안 보인다
        let session = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Session Mode")).firstMatch
        if session.waitForExistence(timeout: 5) {
            session.tap()
            pause(3)
            let startSession = app.buttons["Start Session"]
            if startSession.waitForExistence(timeout: 5) {
                startSession.tap()
                dismissPermissionWarningIfShown()
                pause(5)
                app.buttons["Cancel Timer"].tap()
                pause(2)
            }
            session.tap()
            pause(2)
        }

        // 4) 설정 ▸ 요금제 ▸ 페이월(구매 복원)
        app.buttons["Settings"].firstMatch.tap()
        pause(2)
        // 무료면 "Upgrade to …" 줄이, 이미 Pro 면(개발 빌드) "내 혜택 ▸ 기능 전체 보기" 가 같은 페이월을 연다
        let upgrade = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Upgrade to")).firstMatch
        let proRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Rereminder Pro")).firstMatch
        if upgrade.waitForExistence(timeout: 3) {
            upgrade.tap()
        } else if proRow.exists {
            proRow.tap()
            pause(3)
            let all = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "See all features")).firstMatch
            for _ in 0..<5 where !all.isHittable { app.swipeUp(); pause(1) }
            if all.exists { all.tap() }
        }
        pause(3)
        for _ in 0..<3 { app.swipeUp(); pause(1.5) }
        pause(2)
    }

    /// 가로로 눕힌 화면을 눈으로 확인할 때 쓴다(시뮬레이터를 명령줄로 돌릴 길이 없다).
    /// `LANDSCAPE_SCENE=<dial|running|session|sessionRunning>` 일 때만 돌고, 눕힌 채 40초 머문다 —
    /// 그동안 `xcrun simctl io <기기> screenshot` 으로 찍는다.
    func testLandscapeHold() throws {
        let scene = ProcessInfo.processInfo.environment["LANDSCAPE_SCENE"] ?? ""
        try XCTSkipIf(scene.isEmpty, "가로 확인 때만")
        app.terminate()
        app.launchArguments = ["-screenshotScene", scene,
                               "-hasSeenOnboarding", "YES",
                               "-blankStart.completions", "9",
                               "-blankStart.complexityAsked", "YES",
                               "-AppleLanguages", "(ko)",
                               "-AppleLocale", "ko_KR"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        pause(40)
    }

    /// 링을 두 번 눌러 종이 그 자리에서 생기는지 녹화로 본다. `BELL_APPEAR=1` 일 때만.
    func testBellAppearInPlace() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BELL_APPEAR"] == "1", "눈 확인 때만")
        let time = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Timer,")).firstMatch
        XCTAssertTrue(time.waitForExistence(timeout: 10))
        pause(3)
        // 아이패드 13 가로(1376×1032pt)에서 3시 방향 링 위 = 15분
        let ring = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 636, dy: 497))
        ring.doubleTap()
        pause(3)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
