//
//  TokiAlarmLiveActivity.swift
//  TokiAlarm
//
//  ActivityKit 기반 Live Activity
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Activity Attributes

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var isPaused: Bool
        var timestamp: Date
    }

    var timerName: String
    var totalDuration: TimeInterval
    var startTime: Date
}

struct TokiAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // Lock Screen presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island presentation
                DynamicIslandExpandedRegion(.leading) {
                    Text(displayName(context.attributes.timerName))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "timer")
                        .font(.body)
                        .fontWeight(.medium)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        timerText(remainingTime: context.state.remainingTime)
                            .font(.system(size: 40, design: .rounded))
                            .fontWeight(.bold)
                        Spacer()
                        controlButtons(context: context)
                    }
                }
            } compactLeading: {
                // Compact leading presentation
                timerText(remainingTime: context.state.remainingTime)
                    .font(.caption)
                    .monospacedDigit()
            } compactTrailing: {
                // Compact trailing presentation
                progressView(context: context)
            } minimal: {
                // Minimal presentation
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
            }
            .keylineTint(.orange)
        }
    }

    func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Text(displayName(context.attributes.timerName))
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "timer")
                    .font(.body)
                    .fontWeight(.medium)
            }

            HStack {
                timerText(remainingTime: context.state.remainingTime)
                    .font(.system(size: 40, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
                controlButtons(context: context)
            }
        }
        .padding(.all, 16)
    }

    func timerText(remainingTime: TimeInterval) -> some View {
        let total = Int(remainingTime.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        return Group {
            if hours > 0 {
                Text(String(format: "%d:%02d:%02d", hours, minutes, seconds))
            } else {
                Text(String(format: "%02d:%02d", minutes, seconds))
            }
        }
        .monospacedDigit()
    }

    func progressView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        let progress = context.state.remainingTime / context.attributes.totalDuration

        return ProgressView(value: max(0, progress)) {
            EmptyView()
        } currentValueLabel: {
            Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                .scaleEffect(0.8)
        }
        .progressViewStyle(.circular)
        .tint(.orange)
    }

    @ViewBuilder
    func controlButtons(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        HStack(spacing: 8) {
            if context.state.isPaused {
                Button(intent: ResumeIntent(alarmID: "")) {
                    Label("재개", systemImage: "play.fill")
                        .font(.caption)
                        .lineLimit(1)
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
                .frame(width: 90, height: 32)
            } else {
                Button(intent: PauseIntent(alarmID: "")) {
                    Label("일시정지", systemImage: "pause.fill")
                        .font(.caption)
                        .lineLimit(1)
                }
                .tint(.orange)
                .buttonStyle(.borderedProminent)
                .frame(width: 90, height: 32)
            }

            Button(intent: StopIntent(alarmID: "")) {
                Label("중지", systemImage: "stop.fill")
                    .font(.caption)
                    .lineLimit(1)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .frame(width: 90, height: 32)
        }
    }

    // MARK: - Helper

    func displayName(_ name: String) -> String {
        if name.isEmpty {
            return "타이머"
        }
        return name
    }
}
