//
//  TimerIntents.swift
//  Rereminder
//
//  Siri / App Intents로 타이머 제어
//  Spotlight 검색 및 Siri 음성 명령 지원
//

import AppIntents
import WidgetKit

// MARK: - Start Timer

struct StartTimerSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let description = IntentDescription("Start a timer in Rereminder")
    static let openAppWhenRun = true

    @Parameter(title: "Minutes", default: 0)
    var minutes: Int

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        shared?.set("start", forKey: "controlWidgetAction")
        if minutes > 0 {
            shared?.set(minutes * 60, forKey: "siriTimerDuration")
        }
        WidgetCenter.shared.reloadAllTimelines()
        let message: String = minutes > 0
            ? String(localized: "Starting \(minutes) minute timer")
            : String(localized: "Starting timer")
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

// MARK: - Stop Timer

struct StopTimerSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Timer"
    static let description = IntentDescription("Stop the current timer")
    static let openAppWhenRun = true

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        shared?.set("stop", forKey: "controlWidgetAction")
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Timer stopped")))
    }
}

// MARK: - Pause Timer

struct PauseTimerSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Timer"
    static let description = IntentDescription("Pause the current timer")
    static let openAppWhenRun = true

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        shared?.set("pause", forKey: "controlWidgetAction")
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Timer paused")))
    }
}

// MARK: - Resume Timer

struct ResumeTimerSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Timer"
    static let description = IntentDescription("Resume the paused timer")
    static let openAppWhenRun = true

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        shared?.set("resume", forKey: "controlWidgetAction")
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Timer resumed")))
    }
}

// MARK: - App Shortcuts Provider

struct TimerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTimerSiriIntent(),
            phrases: [
                "Start a timer in \(.applicationName)",
                "Start \(.applicationName)",
                "\(.applicationName) timer start",
                "\(.applicationName) 타이머 시작"
            ],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: StopTimerSiriIntent(),
            phrases: [
                "Stop timer in \(.applicationName)",
                "Stop \(.applicationName)",
                "\(.applicationName) timer stop",
                "\(.applicationName) 타이머 중지"
            ],
            shortTitle: "Stop Timer",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: PauseTimerSiriIntent(),
            phrases: [
                "Pause timer in \(.applicationName)",
                "Pause \(.applicationName)",
                "\(.applicationName) 타이머 일시정지"
            ],
            shortTitle: "Pause Timer",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeTimerSiriIntent(),
            phrases: [
                "Resume timer in \(.applicationName)",
                "Resume \(.applicationName)",
                "\(.applicationName) 타이머 재개"
            ],
            shortTitle: "Resume Timer",
            systemImageName: "play.circle"
        )
    }
}
