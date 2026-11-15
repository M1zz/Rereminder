//
//  RereminderAlarm.swift
//  RereminderAlarm
//
//  홈 화면 위젯: App Group UserDefaults에서 타이머 상태를 읽어 표시
//  쉬는 동안에는 저장한 설정을 버튼으로 보여 주고, 누르면 바로 시작한다(`QuickStartShelf`).
//

import AppIntents
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
    /// 쉬는 동안 보여 줄 저장한 설정(자주 쓰는 순)
    let setups: [QuickStartItem]
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
            prealertOffsets: [],
            setups: Self.sampleSetups
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerWidgetEntry) -> Void) {
        let entry = readCurrentEntry()
        // 위젯 고르는 화면에서 빈 칸을 보여 주면 무엇을 하는 위젯인지 모른다. 저장한 설정이 없으면 예시로 보여 준다.
        // (고르는 화면의 그림은 눌리지 않는다. 홈 화면에 놓인 뒤에는 실제 목록만 쓴다.)
        guard context.isPreview, entry.setups.isEmpty, !entry.isRunning, !entry.isPaused else {
            completion(entry)
            return
        }
        completion(TimerWidgetEntry(date: entry.date, isRunning: false, isPaused: false, endDate: nil,
                                    totalDuration: 0, timerName: "", prealertOffsets: [],
                                    setups: Self.sampleSetups))
    }

    /// 고르는 화면·자리표시용 예시. 이름은 시드 라벨의 번역을, 길이는 시스템 표기를 쓴다(새 문구 없음).
    static var sampleSetups: [QuickStartItem] {
        func minutes(_ m: Int) -> String {
            Duration.seconds(m * 60).formatted(.units(allowed: [.minutes], width: .abbreviated))
        }
        return [
            QuickStartItem(id: "", name: String(localized: "Presentation"), durationText: minutes(15), alertCount: 3,
                          mainSeconds: 900, alertOffsets: [300, 120, 60]),
            QuickStartItem(id: "", name: String(localized: "Study"), durationText: minutes(25), alertCount: 2,
                          mainSeconds: 1500, alertOffsets: [300, 60]),
            QuickStartItem(id: "", name: String(localized: "Exercise"), durationText: minutes(30), alertCount: 2,
                          mainSeconds: 1800, alertOffsets: [600, 300]),
            QuickStartItem(id: "", name: String(localized: "Meeting"), durationText: minutes(60), alertCount: 3,
                          mainSeconds: 3600, alertOffsets: [900, 300, 60]),
        ]
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerWidgetEntry>) -> Void) {
        let entry = readCurrentEntry()

        if entry.isRunning, let endDate = entry.endDate {
            // 타이머 실행 중: endDate에 다시 업데이트하여 "종료" 상태 반영
            // 링이 남은 만큼 줄어들게 1분마다 항목을 미리 세운다(숫자는 시스템이 센다). 많아도 90개.
            var entries = [entry]
            var t = entry.date.addingTimeInterval(60)
            while t < endDate && entries.count < 90 {
                entries.append(TimerWidgetEntry(date: t, isRunning: true, isPaused: false, endDate: endDate,
                                                totalDuration: entry.totalDuration, timerName: entry.timerName,
                                                prealertOffsets: entry.prealertOffsets, setups: entry.setups))
                t = t.addingTimeInterval(60)
            }
            let finishedEntry = TimerWidgetEntry(
                date: endDate,
                isRunning: false,
                isPaused: false,
                endDate: nil,
                totalDuration: 0,
                timerName: "",
                prealertOffsets: [],
                setups: entry.setups
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
            prealertOffsets: prealertOffsets,
            setups: QuickStartShelf.items
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

    /// 남은 비율 — 링이 아이콘처럼 남은 만큼만 색을 남긴다(타임라인 항목마다 다시 그린다).
    private var remainingFraction: Double {
        guard entry.totalDuration > 0, let endDate = entry.endDate else { return 1 }
        return min(1, max(0, endDate.timeIntervalSince(entry.date) / entry.totalDuration))
    }

    /// 앱 아이콘 그대로의 링 + 가운데 카운트다운
    private var runningDial: some View {
        ZStack {
            IconDial(mainSeconds: Int(entry.totalDuration), offsets: entry.prealertOffsets, remaining: remainingFraction)
            IconDialTime { timerDisplay }
        }
    }

    private var statusLine: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isPaused ? "pause.fill" : "play.fill")
            Text(entry.timerName.isEmpty
                 ? (entry.isPaused ? String(localized: "Paused") : String(localized: "Running"))
                 : entry.timerName)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(entry.isPaused ? Color.orange : Color.secondary)
    }

    @ViewBuilder
    private var activeTimerView: some View {
        if family == .systemSmall {
            VStack(spacing: 6) {
                runningDial
                statusLine
            }
        } else {
            HStack(spacing: 16) {
                runningDial
                VStack(alignment: .leading, spacing: 6) {
                    statusLine
                    nextAlertLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// 다음 알림 — 이 앱이 기본 타이머와 다른 이유라 빼지 않는다.
    @ViewBuilder
    private var nextAlertLine: some View {
        if let endDate = entry.endDate,
           let next = entry.prealertOffsets.sorted(by: >).first(where: { endDate.addingTimeInterval(-TimeInterval($0)) > entry.date }) {
            let at = endDate.addingTimeInterval(-TimeInterval(next))
            HStack(spacing: 4) {
                Image(systemName: "bell.fill")
                Text(formatOffsetLabel(next))
                Text(at, style: .time).foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        if entry.isPaused, let endDate = entry.endDate {
            // 일시정지: 남은 시간 정적 표시
            Text(iconClockText(Int(max(0, endDate.timeIntervalSince(entry.date)).rounded())))
        } else if let endDate = entry.endDate, endDate > entry.date {
            // 실행 중: 시스템이 센다(잠금화면처럼 "8 minutes" 로 바뀌지 않게 timerInterval 로)
            Text(timerInterval: entry.date...endDate, countsDown: true)
        } else {
            Text(iconClockText(0))
        }
    }

    // MARK: - Large Active Timer

    private var largeActiveView: some View {
        VStack(alignment: .leading, spacing: 10) {
            runningDial
                .frame(maxWidth: .infinity, maxHeight: 190)
            statusLine
                .frame(maxWidth: .infinity)

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

    /// 크기마다 보여 줄 칸 수 — 작은 것 1 · 중간 2 · 큰 것 4(2×2).
    /// ⚠️ 칸을 더 넣지 말 것. 작은 2·중간 4·큰 6일 때는 칸마다 글자가 눌려 찌그러져 보였다.
    ///    시간 숫자가 한눈에 읽히는 크기가 먼저다.
    private var setupSlots: Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 2
        default: return 4
        }
    }

    @ViewBuilder
    private var idleView: some View {
        let setups = Array(entry.setups.prefix(setupSlots))
        if setups.isEmpty {
            // 저장한 설정이 없으면 앱으로 들어가는 자리다(위젯 탭 = 앱 열기).
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "timer")
                    .font(.system(size: family == .systemSmall ? 28 : 36))
                    .foregroundStyle(.secondary)
                Text(String(localized: "Save a setup in the app to start it here."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if family == .systemSmall, let only = setups.first {
            // 작은 위젯은 위젯 전체가 버튼 하나다 — 안에 상자를 또 그리면 상자 속 상자가 된다.
            setupButton(only) { SetupTile(item: only) }
        } else {
            let rows = (setups.count + 1) / 2
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { col in
                            let index = row * 2 + col
                            if index < setups.count {
                                setupButton(setups[index]) { SetupTile(item: setups[index]) }
                            } else {
                                Color.clear
                            }
                        }
                    }
                }
            }
        }
    }

    /// 누르면 앱이 열리며 바로 시작한다 — 🔖 시트에서 누른 것과 같다(`StartSavedSetupIntent`).
    private func setupButton(_ item: QuickStartItem, @ViewBuilder label: () -> some View) -> some View {
        Button(intent: StartSavedSetupIntent(templateID: item.id), label: label)
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: "\(item.name), \(item.durationText)"))
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
                .containerBackground(for: .widget) { IconBackdrop() }
        }
        .configurationDisplayName(String(localized: "Timer"))
        .description(String(localized: "Start a saved setup, or see the running timer."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Preview


// MARK: - 저장한 설정 칸

/// 앱 아이콘 모양의 링(가운데 시간) + 아래 이름. 누르면 그 설정으로 시작한다.
struct SetupTile: View {
    let item: QuickStartItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                IconDial(mainSeconds: item.mainSeconds ?? 0, offsets: item.alertOffsets ?? [])
                IconDialTime { Text(item.mainSeconds.map(iconClockText) ?? item.durationText) }
            }
            // 사용자가 지은 이름, 또는 알림 시각("5분 전, 1분 전"). 재생 표시가 '누르면 시작'을 말한다.
            HStack(spacing: 4) {
                Image(systemName: "play.fill").foregroundStyle(SharedAccent.color)
                Text(item.name.isEmpty ? item.durationText : item.name).foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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
        prealertOffsets: [300, 60],
        setups: []
    )
    TimerWidgetEntry(
        date: .now,
        isRunning: false,
        isPaused: false,
        endDate: nil,
        totalDuration: 0,
        timerName: "",
        prealertOffsets: [],
        setups: [
            QuickStartItem(id: "a", name: "Pomodoro", durationText: "25 min", alertCount: 2, mainSeconds: 1500, alertOffsets: [300, 60]),
            QuickStartItem(id: "b", name: "Talk", durationText: "15 min", alertCount: 3, mainSeconds: 900, alertOffsets: [300, 120, 60]),
        ]
    )
}
