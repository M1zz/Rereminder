//
//  AppIntent.swift
//  RereminderAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import WidgetKit
import AppIntents
import ActivityKit

// MARK: - Live Activity Intents
//
// ⚠️ 이 인텐트들은 **위젯 확장 프로세스**에서 돈다. NotificationCenter 는 프로세스 경계를 넘지 못하므로
//    그것만으로는 앱에 아무것도 전달되지 않는다(예전 버그: 버튼을 눌러도 아무 일도 일어나지 않음).
//    그래서 세 가지를 함께 한다:
//     ① 앱 그룹에 명령을 남긴다 — 앱이 꺼져 있어도 다음에 열릴 때 적용된다
//     ② 같은 프로세스에 앱이 있다면 알림도 보낸다 — 즉시 반영
//     ③ 눈에 보이는 결과를 그 자리에서 만든다 — 정지는 활동을 바로 없애고, 일시정지/재개는 표시를 바꾼다

struct PauseIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        LiveActivityCommand.pause.dispatch()
        // 앱이 실제로 멈출 때까지 기다리지 않고 표시부터 멈춘다 — 버튼이 죽은 것처럼 보이지 않게
        LiveActivityController.markPaused()
        return .result()
    }

    static var title: LocalizedStringResource = "Pause"
    static var description = IntentDescription("Pause the timer")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}

struct ResumeIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        LiveActivityCommand.resume.dispatch()
        return .result()
    }

    static var title: LocalizedStringResource = "Resume"
    static var description = IntentDescription("Resume the timer")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}

struct StopIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        LiveActivityCommand.stop.dispatch()
        // 정지는 눌렀으면 사라져야 한다 — 앱이 꺼져 있어도 여기서 끝낸다
        LiveActivityController.endAll()
        return .result()
    }

    static var title: LocalizedStringResource = "Stop"
    static var description = IntentDescription("Stop the timer")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}

struct OpenAlarmAppIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        // 앱만 열고 타이머는 중지하지 않음
        return .result()
    }

    static var title: LocalizedStringResource = "Open App"
    static var description = IntentDescription("Open Rereminder app")
    static var openAppWhenRun = true

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}
