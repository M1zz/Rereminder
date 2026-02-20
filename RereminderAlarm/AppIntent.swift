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

struct PauseIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        // Broadcast notification to pause timer
        NotificationCenter.default.post(
            name: NSNotification.Name("PauseTimerIntent"),
            object: nil
        )
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
        // Broadcast notification to resume timer
        NotificationCenter.default.post(
            name: NSNotification.Name("ResumeTimerIntent"),
            object: nil
        )
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
        // Broadcast notification to stop timer
        NotificationCenter.default.post(
            name: NSNotification.Name("StopTimerIntent"),
            object: nil
        )
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
        NotificationCenter.default.post(
            name: NSNotification.Name("StopTimerIntent"),
            object: nil
        )
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
