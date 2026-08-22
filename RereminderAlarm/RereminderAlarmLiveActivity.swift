//
//  RereminderAlarmLiveActivity.swift
//  RereminderAlarm
//
//  ActivityKit 기반 Live Activity
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Activity Attributes
//
// 타입 선언은 `Shared/Models/TimerActivityAttributes.swift` 하나뿐이다(확장 타겟에도 포함).
// 예전에는 앱과 확장에 같은 선언이 각각 있었는데, ActivityKit 은 이름과 필드가 정확히 맞아야
// 디코딩되므로 한쪽만 고치면 다이나믹 아일랜드가 조용히 갱신을 멈춘다.
//
// MARK: - 색
//
// ⚠️ **앱과 같은 색 체계를 쓴다.** 예전에는 여기만 초록(재개)·주황(일시정지)·빨강(정지) 세 가지
//    원색을 `.borderedProminent` 로 칠하고 keyline 도 주황 고정이라, 앱을 보다가 잠금화면을 보면
//    다른 앱처럼 보였다. 규칙은 앱과 동일하다:
//      • 진행·강조 = **사용자가 고른 테마 강조색**(`SharedAccent` — 앱 그룹으로 건너온다)
//      • 시작·재개 = `DSColor.positive` / 일시정지 = `DSColor.negativeSoft` / 정지 = `DSColor.plain`
//    ⚠️ 주황을 진행 표시에 쓰지 말 것 — 이 앱에서 주황은 **알림 종**의 색이다.

struct RereminderAlarmLiveActivity: Widget {
    /// 사용자가 앱에서 고른 강조색 — 앱 그룹을 통해 건너온다(확장은 앱의 표준 저장소를 못 읽는다).
    private var accent: Color { SharedAccent.color }

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
                    Image(systemName: context.state.isPaused ? "pause.circle.fill" : "timer")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        timerText(context: context)
                            .dsScaledFont(28, weight: .bold, design: .rounded, relativeTo: .title, maxSize: 34)
                            .minimumScaleFactor(0.7)
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
                    .foregroundStyle(accent)
            }
            // 앱의 강조색과 같아야 한다 — 주황 고정이면 잠금화면만 다른 앱처럼 보인다.
            .keylineTint(accent)
        }
    }

    func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        VStack(spacing: DSSpacing.md) {
            HStack(alignment: .top) {
                Text(displayName(context.attributes.timerName))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "timer")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }

            HStack {
                timerText(context: context)
                    .dsScaledFont(32, weight: .bold, design: .rounded, relativeTo: .title, maxSize: 38)
                    .minimumScaleFactor(0.8)
                Spacer()
                controlButtons(context: context)
            }
        }
        .padding(.all, DSSpacing.lg)
    }

    @ViewBuilder
    func timerText(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        if context.state.isPaused {
            // Pause 상태: 정적 표시
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
            // 실행 중: 실시간 카운트다운.
            //
            // ⚠️ `Text(endDate, style: .timer)` 를 쓰지 말 것 — 잠금화면의 큰 글씨에서 iOS 가
            //    "8 minutes" 같은 **자연어 표현**으로 대체해 버린다. 초가 사라지면 타이머로서
            //    쓸모가 없다(다이나믹 아일랜드 컴팩트에서는 "9:10" 으로 나와서 더 헷갈렸다).
            //    `timerInterval:countsDown:` 은 언제나 mm:ss 로 센다.
            Text(timerInterval: Date()...max(endDate, Date().addingTimeInterval(1)),
                 countsDown: true)
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
        .tint(accent)
    }

    /// 동작 버튼 — **앱의 원 안 버튼과 같은 색·같은 모양(동그라미)** 이다.
    /// 앱에서는 정지가 회색 원, 일시정지가 주황 원, 재개가 분홍 원이다. 여기서 초록·빨강을 쓰면
    /// 같은 동작이 화면마다 다른 색을 갖게 되어 매번 다시 읽어야 한다.
    @ViewBuilder
    func controlButtons(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        HStack(spacing: DSSpacing.sm) {
            // 정지가 **왼쪽** — 앱의 원 안 배치와 같다(왼쪽 ✕, 오른쪽 재생/일시정지).
            circleButton(intent: StopIntent(alarmID: ""),
                         systemImage: "xmark",
                         tint: DSColor.plain,
                         label: String(localized: "Stop timer"))

            if context.state.isPaused {
                circleButton(intent: ResumeIntent(alarmID: ""),
                             systemImage: "play.fill",
                             tint: DSColor.positive,
                             label: String(localized: "Resume timer"))
            } else {
                circleButton(intent: PauseIntent(alarmID: ""),
                             systemImage: "pause.fill",
                             tint: DSColor.negativeSoft,
                             label: String(localized: "Pause timer"))
            }
        }
    }

    private func circleButton<I: AppIntent>(intent: I,
                                            systemImage: String,
                                            tint: Color,
                                            label: String) -> some View {
        Button(intent: intent) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Helper

    func displayName(_ name: String) -> String {
        if name.isEmpty {
            return "Timer"
        }
        return name
    }
}
