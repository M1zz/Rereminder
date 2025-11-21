//
//  AppIntent.swift
//  TokiAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import WidgetKit
import AppIntents
import ActivityKit

// MARK: - Live Activity Intents

struct PauseIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        // Broadcast notification to pause timer
        NotificationCenter.default.post(
            name: NSNotification.Name("PauseTimerIntent"),
            object: nil,
            userInfo: ["alarmID": alarmID]
        )
        return .result()
    }

    static var title: LocalizedStringResource = "일시정지"
    static var description = IntentDescription("타이머를 일시정지합니다")

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
        // Broadcast notification to resume timer
        NotificationCenter.default.post(
            name: NSNotification.Name("ResumeTimerIntent"),
            object: nil,
            userInfo: ["alarmID": alarmID]
        )
        return .result()
    }

    static var title: LocalizedStringResource = "재개"
    static var description = IntentDescription("타이머를 재개합니다")

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
        // Broadcast notification to stop timer
        NotificationCenter.default.post(
            name: NSNotification.Name("StopTimerIntent"),
            object: nil,
            userInfo: ["alarmID": alarmID]
        )
        return .result()
    }

    static var title: LocalizedStringResource = "중지"
    static var description = IntentDescription("타이머를 중지합니다")

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
        NotificationCenter.default.post(
            name: NSNotification.Name("StopTimerIntent"),
            object: nil,
            userInfo: ["alarmID": alarmID]
        )
        return .result()
    }

    static var title: LocalizedStringResource = "앱 열기"
    static var description = IntentDescription("Toki 앱을 엽니다")
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
