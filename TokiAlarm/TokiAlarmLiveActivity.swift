//
//  TokiAlarmLiveActivity.swift
//  TokiAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct TokiAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes.self) { context in
            // Lock Screen presentation
            lockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Dynamic Island presentation
                DynamicIslandExpandedRegion(.leading) {
                    alarmTitle(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "timer")
                        .font(.body)
                        .fontWeight(.medium)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    bottomView(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                // Compact leading presentation
                countdown(state: context.state, maxWidth: 44)
                    .foregroundStyle(Color(hex: context.attributes.tintColor) ?? .accentColor)
            } compactTrailing: {
                // Compact trailing presentation
                AlarmProgressView(
                    mode: context.state.mode,
                    tint: Color(hex: context.attributes.tintColor) ?? .accentColor
                )
            } minimal: {
                // Minimal presentation
                AlarmProgressView(
                    mode: context.state.mode,
                    tint: Color(hex: context.attributes.tintColor) ?? .accentColor
                )
            }
            .keylineTint(Color(hex: context.attributes.tintColor) ?? .accentColor)
        }
    }

    func lockScreenView(attributes: AlarmAttributes, state: AlarmAttributes.ContentState) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                alarmTitle(attributes: attributes, state: state)
                Spacer()
                Image(systemName: "timer")
                    .font(.body)
                    .fontWeight(.medium)
            }

            bottomView(attributes: attributes, state: state)
        }
        .padding(.all, 16)
    }

    func bottomView(attributes: AlarmAttributes, state: AlarmAttributes.ContentState) -> some View {
        HStack {
            countdown(state: state, maxWidth: 150)
                .font(.system(size: 40, design: .rounded))
                .fontWeight(.bold)
            Spacer()
            AlarmControls(presentation: attributes.presentation, state: state)
        }
    }

    func countdown(state: AlarmAttributes.ContentState, maxWidth: CGFloat = .infinity) -> some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                Text(timerInterval: Date.now ... countdown.fireDate, countsDown: true)
            case .paused(let pausedState):
                let remaining = Duration.seconds(pausedState.totalCountdownDuration - pausedState.previouslyElapsedDuration)
                let pattern: Duration.TimeFormatStyle.Pattern = remaining > .seconds(60 * 60) ? .hourMinuteSecond : .minuteSecond
                Text(remaining.formatted(.time(pattern: pattern)))
            default:
                EmptyView()
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    @ViewBuilder func alarmTitle(attributes: AlarmAttributes, state: AlarmAttributes.ContentState) -> some View {
        let title: String? = switch state.mode {
        case .countdown:
            attributes.presentation.countdown?.title
        case .paused:
            attributes.presentation.paused?.title
        case .alert:
            attributes.presentation.alert.title
        }

        Text(title ?? "타이머")
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
            .padding(.leading, 6)
    }
}

// MARK: - Progress View

struct AlarmProgressView: View {
    var mode: AlarmMode
    var tint: Color

    var body: some View {
        Group {
            switch mode {
            case .countdown(let countdown):
                ProgressView(
                    timerInterval: Date.now ... countdown.fireDate,
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: {
                        Image(systemName: "timer")
                            .scaleEffect(0.9)
                    })
            case .paused(let pausedState):
                let remaining = pausedState.totalCountdownDuration - pausedState.previouslyElapsedDuration
                ProgressView(value: remaining,
                             total: pausedState.totalCountdownDuration,
                             label: { EmptyView() },
                             currentValueLabel: {
                    Image(systemName: "pause.fill")
                        .scaleEffect(0.8)
                })
            default:
                EmptyView()
            }
        }
        .progressViewStyle(.circular)
        .foregroundStyle(tint)
        .tint(tint)
    }
}

// MARK: - Alarm Controls

struct AlarmControls: View {
    var presentation: AlarmPresentation
    var state: AlarmAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            switch state.mode {
            case .countdown:
                if let pauseButton = presentation.countdown?.pauseButton {
                    ButtonView(
                        config: pauseButton,
                        intent: PauseIntent(alarmID: state.alarmID.uuidString),
                        tint: .orange
                    )
                }
            case .paused:
                if let resumeButton = presentation.paused?.resumeButton {
                    ButtonView(
                        config: resumeButton,
                        intent: ResumeIntent(alarmID: state.alarmID.uuidString),
                        tint: .green
                    )
                }
            default:
                EmptyView()
            }

            ButtonView(
                config: presentation.alert.stopButton,
                intent: StopIntent(alarmID: state.alarmID.uuidString),
                tint: .red
            )
        }
    }
}

// MARK: - Button View

struct ButtonView<I>: View where I: AppIntent {
    var config: AlarmButton
    var intent: I
    var tint: Color

    init?(config: AlarmButton?, intent: I, tint: Color) {
        guard let config else { return nil }
        self.config = config
        self.intent = intent
        self.tint = tint
    }

    var body: some View {
        Button(intent: intent) {
            Label(config.text, systemImage: config.systemImageName)
                .font(.caption)
                .lineLimit(1)
        }
        .tint(tint)
        .buttonStyle(.borderedProminent)
        .frame(width: 90, height: 32)
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
