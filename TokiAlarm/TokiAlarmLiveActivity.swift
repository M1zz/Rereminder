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
        var endDate: Date?  // 타이머 종료 시각 (자동 카운트다운용)
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
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "timer")
                        .font(.body)
                        .fontWeight(.medium)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        timerText(context: context)
                            .font(.system(size: 28, design: .rounded))
                            .fontWeight(.bold)
                        Spacer()
                        controlButtons(context: context)
                    }
                }
            } compactLeading: {
                // Compact leading presentation
                timerText(context: context)
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
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: "timer")
                    .font(.body)
                    .fontWeight(.medium)
            }

            HStack {
                timerText(context: context)
                    .font(.system(size: 32, design: .rounded))
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.8)
                Spacer()
                controlButtons(context: context)
            }
        }
        .padding(.all, 16)
    }

    @ViewBuilder
    func timerText(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        if context.state.isPaused {
            // 일시정지 상태: 정적 표시
            let total = Int(context.state.remainingTime.rounded())
            let hours = total / 3600
            let minutes = (total % 3600) / 60
            let seconds = total % 60

            if hours > 0 {
                Text(String(format: "%d:%02d:%02d", hours, minutes, seconds))
                    .monospacedDigit()
            } else {
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .monospacedDigit()
            }
        } else if let endDate = context.state.endDate {
            // 실행 중: 실시간 카운트다운
            Text(endDate, style: .timer)
                .monospacedDigit()
        } else {
            // fallback
            let total = Int(context.state.remainingTime.rounded())
            let hours = total / 3600
            let minutes = (total % 3600) / 60
            let seconds = total % 60

            if hours > 0 {
                Text(String(format: "%d:%02d:%02d", hours, minutes, seconds))
                    .monospacedDigit()
            } else {
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .monospacedDigit()
            }
        }
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
        HStack(spacing: 6) {
            if context.state.isPaused {
                Button(intent: ResumeIntent(alarmID: "")) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                }
                .tint(.green)
                .buttonStyle(.borderedProminent)
                .frame(width: 40, height: 32)
            } else {
                Button(intent: PauseIntent(alarmID: "")) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 16))
                }
                .tint(.orange)
                .buttonStyle(.borderedProminent)
                .frame(width: 40, height: 32)
            }

            Button(intent: StopIntent(alarmID: "")) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16))
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .frame(width: 40, height: 32)
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
