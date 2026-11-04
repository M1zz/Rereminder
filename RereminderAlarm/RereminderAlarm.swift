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
            var entries = [entry]
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
                .dsScaledFont(family == .systemSmall ? 28 : 36,
                              weight: .bold, design: .rounded, relativeTo: .title,
                              maxSize: family == .systemSmall ? 32 : 42)
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
                .dsScaledFont(48, weight: .bold, design: .rounded, relativeTo: .largeTitle, maxSize: 56)
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
            setupButton(only) { SetupTile(item: only, size: .large, framed: false) }
        } else {
            let rows = (setups.count + 1) / 2
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { col in
                            let index = row * 2 + col
                            if index < setups.count {
                                setupButton(setups[index]) { SetupTile(item: setups[index], size: .regular, framed: true) }
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(String(localized: "Timer"))
        .description(String(localized: "Start a saved setup, or see the running timer."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Preview


/// 칸 속 작은 링. 한 바퀴가 그 설정의 전체 시간이고, 알림이 나눈 구간마다 `SectionPalette` 색이다.
/// 12시에서 시계 방향으로 "남은 시간" 좌표 — 앱 다이얼과 같다. 링 정보가 없는 옛 목록이면 강조색 한 바퀴다.
struct SetupRing: View {
    let mainSeconds: Int
    let offsets: [Int]

    /// (시작, 끝, 구간 번호) 비율. 구간 번호는 경과 순서(`TimerSections.derive`)와 같다.
    private var arcs: [(from: Double, to: Double, index: Int)] {
        guard mainSeconds > 0 else { return [] }
        let points = [mainSeconds] + offsets.filter { $0 > 0 && $0 < mainSeconds }.sorted(by: >) + [0]
        return (0..<(points.count - 1)).map { i in
            (Double(points[i + 1]) / Double(mainSeconds), Double(points[i]) / Double(mainSeconds), i)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let line = geo.size.width * 0.14
            ZStack {
                if arcs.isEmpty {
                    Circle().stroke(SharedAccent.color, lineWidth: line)
                } else {
                    ForEach(arcs, id: \.index) { arc in
                        Circle()
                            .trim(from: arc.from, to: arc.to)
                            .stroke(SectionPalette.color(arc.index), style: StrokeStyle(lineWidth: line, lineCap: .butt))
                    }
                }
            }
            .rotationEffect(.degrees(-90))
            .padding(line / 2)
        }
    }
}

// MARK: - 저장한 설정 칸

/// 위에 작은 링(가운데 재생), 아래에 시간(가장 크게)과 이름(또는 알림 시각).
/// 시간이 주인공이다. 이름은 사용자가 지은 말이라 길이가 제각각이고, 시간은 한눈에 읽혀야 한다.
struct SetupTile: View {
    enum Size { case regular, large }

    let item: QuickStartItem
    let size: Size
    /// 칸마다 상자를 그리나(중간·큰 위젯). 작은 위젯은 위젯 자체가 상자다.
    let framed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 앱의 다이얼을 작게 — 알림이 나눈 구간이 링에서와 같은 색이다. 가운데가 재생 버튼이다.
            SetupRing(mainSeconds: item.mainSeconds ?? 0, offsets: item.alertOffsets ?? [])
                .frame(width: size == .large ? 72 : 58, height: size == .large ? 72 : 58)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: size == .large ? 18 : 15, weight: .bold))
                        .foregroundStyle(SharedAccent.color)
                }
            Spacer(minLength: 6)
            Text(item.durationText)
                .font(.system(size: size == .large ? 30 : 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            // 사용자가 지은 이름, 또는 알림 시각("5분 전, 1분 전")
            Text(item.name.isEmpty ? " " : item.name)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(framed ? 12 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            if framed {
                ContainerRelativeShape().fill(SharedAccent.color.opacity(0.16))
            }
        }
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
