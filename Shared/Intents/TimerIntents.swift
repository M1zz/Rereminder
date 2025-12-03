//
//  TimerIntents.swift
//  Toki
//
//  App Intents for AlarmKit timer controls
//

import AppIntents
import AlarmKit
import Foundation

// MARK: - Pause Timer Intent

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause Timer"
    static var description = IntentDescription("Pause the running timer")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        print("⏸️ Intent: 일시정지 요청 - \(alarmID)")

        // AlarmManager를 통해 직접 제어
        try AlarmManager.shared.pause(id: UUID(uuidString: alarmID)!)

        return .result()
    }
}

// MARK: - Resume Timer Intent

struct ResumeTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Timer"
    static var description = IntentDescription("Resume the paused timer")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        print("▶️ Intent: 재개 요청 - \(alarmID)")

        // AlarmManager를 통해 직접 제어
        try AlarmManager.shared.resume(id: UUID(uuidString: alarmID)!)

        return .result()
    }
}

// MARK: - Stop Timer Intent

struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description = IntentDescription("Stop the timer")

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        print("⏹️ Intent: 중지 요청 - \(alarmID)")

        // AlarmManager를 통해 직접 제어
        try AlarmManager.shared.stop(id: UUID(uuidString: alarmID)!)

        return .result()
    }
}
