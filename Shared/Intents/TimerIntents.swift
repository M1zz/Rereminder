//
//  TimerIntents.swift
//  Rereminder
//
//  Siri / App Intents로 타이머 제어
//  Spotlight 검색 및 Siri 음성 명령 지원
//

import AppIntents
import WidgetKit

// MARK: - 명령 기록

/// Siri 명령을 앱 그룹에 남기는 자리 — 앱이 앞으로 나오면 `TimerUnifiedView.handleControlWidgetAction` 이 꺼낸다.
enum SiriTimerCommand {
    static let actionKey = "controlWidgetAction"
    static let issuedAtKey = "controlWidgetActionAt"
    /// 이보다 오래된 명령은 버린다. ⚠️ 없으면 앱에 닿지 못한 "시작"·"정지"가 몇 시간 뒤 앱을 연 순간 적용돼
    ///    원하지 않은 타이머가 돌거나 손으로 건 타이머가 꺼졌다(`QuickStartShelf.requestLifetime` 과 같은 값).
    static let lifetime: TimeInterval = 60
    /// 단축어로 넣을 수 있는 가장 긴 시간(분)
    static let maxMinutes = 24 * 60

    static func post(_ action: String, to defaults: UserDefaults?, now: Date = Date()) {
        defaults?.set(action, forKey: actionKey)
        defaults?.set(now.timeIntervalSince1970, forKey: issuedAtKey)
    }

    /// 남은 명령을 꺼낸다(꺼내면 지워진다). 시각이 없거나 오래된 명령은 버린다.
    static func take(from defaults: UserDefaults?, now: Date = Date()) -> String? {
        guard let action = defaults?.string(forKey: actionKey) else { return nil }
        let issuedAt = defaults?.double(forKey: issuedAtKey) ?? 0
        defaults?.removeObject(forKey: actionKey)
        defaults?.removeObject(forKey: issuedAtKey)
        let age = now.timeIntervalSince1970 - issuedAt
        guard issuedAt > 0, age >= -lifetime, age <= lifetime else {
            // 버리는 시작 명령의 시간도 함께 치운다 — 남겨 두면 다음 시작에 엉뚱한 시간이 실린다.
            defaults?.removeObject(forKey: "siriTimerDuration")
            return nil
        }
        return action
    }
}

// MARK: - Start Timer

struct StartTimerSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let description = IntentDescription("Start a timer in Rereminder")
    // ⚠️ `openAppWhenRun` 은 iOS 26 SDK 에서 무시된다 — 앱이 열리지 않아 명령이 남은 채 아무 일도 없었다
    //    (`QuickStartIntents` 와 같은 이유). 앱을 열어야 명령이 적용된다.
    static var supportedModes: IntentModes { .foreground }

    @Parameter(title: "Minutes", description: "How long the timer runs, in minutes. Leave at 0 to use the time already set.", default: 0)
    var minutes: Int

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        SiriTimerCommand.post("start", to: shared)
        if minutes > 0 {
            // 단축어에서는 아무 숫자나 넣을 수 있다 — 하루로 자른다(곱하다 넘치면 그 자리에서 죽는다).
            shared?.set(min(minutes, SiriTimerCommand.maxMinutes) * 60, forKey: "siriTimerDuration")
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
    // ⚠️ `openAppWhenRun` 은 iOS 26 SDK 에서 무시된다 — 앱이 열리지 않아 명령이 남은 채 아무 일도 없었다
    //    (`QuickStartIntents` 와 같은 이유). 앱을 열어야 명령이 적용된다.
    static var supportedModes: IntentModes { .foreground }

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        SiriTimerCommand.post("stop", to: shared)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Timer stopped")))
    }
}

// MARK: - Pause Timer

struct PauseTimerSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Timer"
    static let description = IntentDescription("Pause the current timer")
    // ⚠️ `openAppWhenRun` 은 iOS 26 SDK 에서 무시된다 — 앱이 열리지 않아 명령이 남은 채 아무 일도 없었다
    //    (`QuickStartIntents` 와 같은 이유). 앱을 열어야 명령이 적용된다.
    static var supportedModes: IntentModes { .foreground }

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        SiriTimerCommand.post("pause", to: shared)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "Timer paused")))
    }
}

// MARK: - Resume Timer

struct ResumeTimerSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Timer"
    static let description = IntentDescription("Resume the paused timer")
    // ⚠️ `openAppWhenRun` 은 iOS 26 SDK 에서 무시된다 — 앱이 열리지 않아 명령이 남은 채 아무 일도 없었다
    //    (`QuickStartIntents` 와 같은 이유). 앱을 열어야 명령이 적용된다.
    static var supportedModes: IntentModes { .foreground }

    private static let suiteName = "group.leeo.toki"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shared = UserDefaults(suiteName: Self.suiteName)
        SiriTimerCommand.post("resume", to: shared)
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
