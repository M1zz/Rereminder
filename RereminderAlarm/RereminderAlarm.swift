//
//  RereminderAlarm.swift
//  RereminderAlarm
//
//  홈 화면 위젯: App Group UserDefaults에서 타이머 상태를 읽어 표시
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TimerWidgetEntry: TimelineEntry {
    let date: Date
    let isRunning: Bool
    let isPaused: Bool
    let endDate: Date?
    let totalDuration: TimeInterval
    let timerName: String
    let prealertOffsets: [Int]
}

// MARK: - Timeline Provider

struct TimerWidgetProvider: TimelineProvider {
    private let suiteName = "group.leeo.toki"

    func placeholder(in context: Context) -> TimerWidgetEntry {
        TimerWidgetEntry(
            date: Date(),
            isRunning: false,
            isPaused: false,
            endDate: nil,
            totalDuration: 0,
            timerName: "",
            prealertOffsets: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerWidgetEntry) -> Void) {
        completion(readCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerWidgetEntry>) -> Void) {
        let entry = readCurrentEntry()

        if entry.isRunning, let endDate = entry.endDate {
            // 타이머 실행 중: endDate에 다시 업데이트하여 "종료" 상태 반영
            var entries = [entry]
            let finishedEntry = TimerWidgetEntry(
                date: endDate,
                isRunning: false,
                isPaused: false,
                endDate: nil,
                totalDuration: 0,
                timerName: "",
                prealertOffsets: []
            )
            entries.append(finishedEntry)
            completion(Timeline(entries: entries, policy: .atEnd))
        } else {
            // 대기/일시정지 상태: 15분 후 다시 확인
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func readCurrentEntry() -> TimerWidgetEntry {
        let shared = UserDefaults(suiteName: suiteName)
        let isRunning = shared?.bool(forKey: "timerIsRunning") ?? false
        let isPaused = shared?.bool(forKey: "timerIsPaused") ?? false
        let endEpoch = shared?.double(forKey: "timerEndDate") ?? 0
        let totalDuration = shared?.double(forKey: "timerMainDuration") ?? 0
        let timerName = shared?.string(forKey: "timerName") ?? ""
        let prealertOffsets = (shared?.array(forKey: "timerPrealertOffsets") as? [Int]) ?? []

        let endDate: Date? = endEpoch > 0 ? Date(timeIntervalSince1970: endEpoch) : nil

        return TimerWidgetEntry(
            date: Date(),
            isRunning: isRunning,
            isPaused: isPaused,
            endDate: endDate,
            totalDuration: totalDuration,
            timerName: timerName,
            prealertOffsets: prealertOffsets
        )
    }
}

// MARK: - Widget View

struct TimerWidgetEntryView: View {
    var entry: TimerWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        case .systemLarge:
            if entry.isRunning || entry.isPaused {
                largeActiveView
            } else {
                idleView
            }
        default:
            Group {
                if entry.isRunning || entry.isPaused {
                    activeTimerView
                } else {
                    idleView
                }
            }
        }
    }

    // MARK: - Active Timer

    private var activeTimerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: entry.isPaused ? "pause.circle.fill" : "timer")
                    .font(.caption)
                    .foregroundStyle(entry.isPaused ? .orange : .green)
                Text(entry.isPaused
                     ? String(localized: "Paused")
                     : String(localized: "Running"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(entry.isPaused ? .orange : .green)
                Spacer()
                if !entry.timerName.isEmpty {
                    Text(entry.timerName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            timerDisplay
                .font(family == .systemSmall
                      ? .system(size: 28, design: .rounded)
                      : .system(size: 36, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .minimumScaleFactor(0.6)

            if entry.totalDuration > 0 {
                progressBar
            }
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        if entry.isPaused, let endDate = entry.endDate {
            // 일시정지: 남은 시간 정적 표시
            let remaining = max(0, endDate.timeIntervalSinceNow)
            Text(formatTime(remaining))
        } else if let endDate = entry.endDate, endDate > Date() {
            // 실행 중: 실시간 카운트다운
            Text(endDate, style: .timer)
        } else {
            Text("00:00")
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let progress: Double = {
                guard entry.totalDuration > 0, let endDate = entry.endDate else { return 0 }
                let remaining = max(0, endDate.timeIntervalSinceNow)
                return min(1, remaining / entry.totalDuration)
            }()

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)
                Capsule()
                    .fill(entry.isPaused ? .orange : .green)
                    .frame(width: geo.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Large Active Timer

    private var largeActiveView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 상단: 상태 + 이름
            HStack {
                Image(systemName: entry.isPaused ? "pause.circle.fill" : "timer")
                    .font(.subheadline)
                    .foregroundStyle(entry.isPaused ? .orange : .green)
                Text(entry.isPaused
                     ? String(localized: "Paused")
                     : String(localized: "Running"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(entry.isPaused ? .orange : .green)
                Spacer()
                if !entry.timerName.isEmpty {
                    Text(entry.timerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // 카운트다운
            timerDisplay
                .font(.system(size: 48, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .center)

            // 진행률 바
            if entry.totalDuration > 0 {
                progressBar
            }

            Divider()

            // 사전알림 스케줄
            if !entry.prealertOffsets.isEmpty, let endDate = entry.endDate {
                Text(String(localized: "Pre-alerts"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(entry.prealertOffsets.sorted().prefix(5), id: \.self) { offset in
                    let alertTime = endDate.addingTimeInterval(-TimeInterval(offset))
                    let hasPassed = alertTime <= Date()
                    HStack(spacing: 8) {
                        Image(systemName: hasPassed ? "checkmark.circle.fill" : "bell.circle")
                            .font(.caption)
                            .foregroundStyle(hasPassed ? .green : .secondary)
                        Text(formatOffsetLabel(offset))
                            .font(.caption)
                            .foregroundStyle(hasPassed ? .secondary : .primary)
                        Spacer()
                        Text(alertTime, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func formatOffsetLabel(_ seconds: Int) -> String {
        if seconds < 60 {
            return String(localized: "\(seconds) sec before")
        }
        let min = seconds / 60
        return String(localized: "\(min) min before")
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: family == .systemSmall ? 28 : 36))
                .foregroundStyle(.secondary)
            Text(String(localized: "No active timer"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lock Screen: Circular

    private var accessoryCircularView: some View {
        ZStack {
            if entry.isRunning || entry.isPaused {
                if let endDate = entry.endDate, entry.totalDuration > 0 {
                    let remaining = max(0, endDate.timeIntervalSinceNow)
                    let progress = min(1, remaining / entry.totalDuration)
                    Gauge(value: progress) {
                        Image(systemName: "timer")
                    } currentValueLabel: {
                        if entry.isPaused {
                            Text(formatTime(remaining))
                                .font(.system(size: 11, design: .rounded))
                        } else {
                            Text(endDate, style: .timer)
                                .font(.system(size: 11, design: .rounded))
                        }
                    }
                    .gaugeStyle(.accessoryCircular)
                } else {
                    Image(systemName: "timer")
                }
            } else {
                Gauge(value: 0) {
                    Image(systemName: "timer")
                }
                .gaugeStyle(.accessoryCircular)
            }
        }
    }

    // MARK: - Lock Screen: Rectangular

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption2)
                Text(entry.isPaused
                     ? String(localized: "Paused")
                     : entry.isRunning
                     ? String(localized: "Running")
                     : String(localized: "Timer"))
                    .font(.caption2)
                    .fontWeight(.medium)
            }

            if entry.isRunning || entry.isPaused, let endDate = entry.endDate {
                if entry.isPaused {
                    let remaining = max(0, endDate.timeIntervalSinceNow)
                    Text(formatTime(remaining))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                } else {
                    Text(endDate, style: .timer)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                if entry.totalDuration > 0 {
                    let remaining = max(0, endDate.timeIntervalSinceNow)
                    let progress = min(1, remaining / entry.totalDuration)
                    ProgressView(value: progress)
                        .tint(entry.isPaused ? .orange : .green)
                }
            } else {
                Text(String(localized: "No active timer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Lock Screen: Inline

    private var accessoryInlineView: some View {
        Group {
            if entry.isRunning, let endDate = entry.endDate, endDate > Date() {
                Label {
                    Text(endDate, style: .timer)
                } icon: {
                    Image(systemName: "timer")
                }
            } else if entry.isPaused, let endDate = entry.endDate {
                let remaining = max(0, endDate.timeIntervalSinceNow)
                Label(formatTime(remaining) + " ⏸", systemImage: "timer")
            } else {
                Label(String(localized: "Timer"), systemImage: "timer")
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Widget Definition

struct RereminderAlarm: Widget {
    let kind: String = "RereminderAlarm"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerWidgetProvider()) { entry in
            TimerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Timer"))
        .description(String(localized: "Shows current timer status"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    RereminderAlarm()
} timeline: {
    TimerWidgetEntry(
        date: .now,
        isRunning: true,
        isPaused: false,
        endDate: Date().addingTimeInterval(600),
        totalDuration: 1800,
        timerName: "Study 25 min",
        prealertOffsets: [300, 60]
    )
    TimerWidgetEntry(
        date: .now,
        isRunning: false,
        isPaused: false,
        endDate: nil,
        totalDuration: 0,
        timerName: "",
        prealertOffsets: []
    )
}
