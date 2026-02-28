//
//  TimerIntents.swift
//  Rereminder
//
//  App Intents for AlarmKit timer controls
//

import Foundation

#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
import AppIntents
import AlarmKit

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
        print("⏸️ Intent: Pause 요청 - \(alarmID)")

        guard let uuid = UUID(uuidString: alarmID) else {
            print("❌ Invalid alarmID: \(alarmID)")
            return .result()
        }
        try AlarmManager.shared.pause(id: uuid)

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
        print("▶️ Intent: Resume 요청 - \(alarmID)")

        guard let uuid = UUID(uuidString: alarmID) else {
            print("❌ Invalid alarmID: \(alarmID)")
            return .result()
        }
        try AlarmManager.shared.resume(id: uuid)

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
        print("⏹️ Intent: Stop 요청 - \(alarmID)")

        guard let uuid = UUID(uuidString: alarmID) else {
            print("❌ Invalid alarmID: \(alarmID)")
            return .result()
        }
        try AlarmManager.shared.stop(id: uuid)

        return .result()
    }
}
#endif
