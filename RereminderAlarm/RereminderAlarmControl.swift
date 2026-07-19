//
//  RereminderAlarmControl.swift
//  RereminderAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import AppIntents
import SwiftUI
import WidgetKit

struct RereminderAlarmControl: ControlWidget {
    static let kind: String = "com.xa.rereminder.RereminderAlarm"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Start Timer",
                isOn: value.isRunning,
                action: StartTimerIntent(value.name)
            ) { isRunning in
                Label(isRunning ? "On" : "Off", systemImage: "timer")
            }
        }
        .displayName("Timer")
        .description("A an example control that runs a timer.")
    }
}

extension RereminderAlarmControl {
    struct Value {
        var isRunning: Bool
        var name: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: TimerConfiguration) -> Value {
            RereminderAlarmControl.Value(isRunning: false, name: configuration.timerName)
        }

        func currentValue(configuration: TimerConfiguration) async throws -> Value {
            let isRunning = UserDefaults(suiteName: "group.leeo.toki")?.bool(forKey: "timerIsRunning") ?? false
            return RereminderAlarmControl.Value(isRunning: isRunning, name: configuration.timerName)
        }
    }
}

struct TimerConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Timer Name Configuration"

    @Parameter(title: "Timer Name", default: "Timer")
    var timerName: String
}

struct StartTimerIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Start a timer"
    static let openAppWhenRun = true

    @Parameter(title: "Timer Name")
    var name: String

    @Parameter(title: "Timer is running")
    var value: Bool

    private static let suiteName = "group.leeo.toki"

    init() {}

    init(_ name: String) {
        self.name = name
    }

    func perform() async throws -> some IntentResult {
        let shared = UserDefaults(suiteName: Self.suiteName)
        if value {
            // 타이머 시작 요청
            shared?.set("start", forKey: "controlWidgetAction")
        } else {
            // 타이머 중지 요청
            shared?.set("stop", forKey: "controlWidgetAction")
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
