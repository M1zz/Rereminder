//
//  RereminderWatchTimerWidget.swift
//  RereminderWatchWidget
//
//  손목의 스마트 스택에 서는 타이머 위젯.
//
//  이 앱이 기본 시계 앱 대신 손목에 있을 이유는 "끝나기 전에 여러 번 알려 준다" 하나다.
//  그래서 카드에서 가장 큰 숫자는 전체 남은 시간이지만, 그 아래 한 줄은 **다음 알림까지**다 —
//  그 줄이 없으면 이 위젯은 기본 타이머 위젯과 구별되지 않는다.
//
//  ⚠️ 카운트다운을 타임라인 항목으로 세지 않는다. `Text(timerInterval:)`·
//     `ProgressView(timerInterval:)` 로 **시스템이** 세게 하고, 항목은 표시가 실제로 바뀌는
//     순간(알림 경계·종료)에만 세운다. 초마다 항목을 만들면 위젯 예산을 그날 안에 다 쓴다.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct WatchTimerEntry: TimelineEntry {
    let date: Date
    /// 돌고 있는 타이머. 없으면 대기 화면을 그린다.
    let state: WatchTimerState?
}

// MARK: - Timeline Provider

struct WatchTimerProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchTimerEntry {
        WatchTimerEntry(
            date: Date(),
            state: WatchTimerState(mainDuration: 1800,
                                   prealertOffsets: [600, 300, 60],
                                   startDate: Date())
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchTimerEntry) -> Void) {
        completion(WatchTimerEntry(date: Date(), state: WatchTimerStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchTimerEntry>) -> Void) {
        let now = Date()
        let state = WatchTimerStore.load()
        var entries = [WatchTimerEntry(date: now, state: state)]

        // 표시가 바뀌는 순간에만 항목을 더 세운다 — "다음 알림"이 넘어갈 때와 끝날 때.
        let upcoming = state?.refreshDates(after: now).prefix(Self.maxRefreshPoints) ?? []
        if let state {
            for date in upcoming {
                entries.append(WatchTimerEntry(date: date, state: state))
            }
        }

        // ⚠️ 앞으로 세울 항목이 없으면 **`.never`** 여야 한다(대기·일시정지·이미 끝난 타이머).
        //    항목이 지금 하나뿐인데 `.atEnd` 를 주면 그 날짜가 이미 지난 셈이라 WidgetKit 이
        //    곧바로 다음 타임라인을 다시 요청한다 — 아무것도 안 하는데 갱신 예산만 태우는 고리다.
        //    그 상태에서 위젯을 깨우는 건 앱이다(`WatchTimerStore` 의 reloadAllTimelines).
        completion(Timeline(entries: entries, policy: upcoming.isEmpty ? .never : .atEnd))
    }

    /// 스마트 스택이 이 위젯을 **언제 위로 올릴지**. 타이머가 도는 동안만 관련 있다.
    /// (이게 없으면 사용자가 직접 고정해 두지 않는 한 카드가 좀처럼 보이지 않는다.)
    func relevance() async -> WidgetRelevance<Void> {
        guard let state = WatchTimerStore.load(),
              let end = state.endDate,
              end > Date() else {
            return WidgetRelevance([])
        }
        return WidgetRelevance([
            WidgetRelevanceAttribute(context: .date(from: Date(), to: end))
        ])
    }

    /// 알림이 많아도 타임라인은 적당히 끊는다(위젯 갱신 예산은 하루 단위로 배분된다).
    private static let maxRefreshPoints = 8
}

// MARK: - View

struct WatchTimerWidgetView: View {
    var entry: WatchTimerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline:      inline
        case .accessoryCorner:      corner
        default:                    circular
        }
    }

    // MARK: 스마트 스택 카드 (accessoryRectangular)

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            header
            headline
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// 1줄: 상태 + (구간이 나뉘어 있으면) 지금 몇 번째 구간인지.
    private var header: some View {
        HStack(spacing: 3) {
            Image(systemName: statusSymbol)
            Text(statusText)
            Spacer(minLength: 0)
            if let sectionLabel {
                // 숫자 표기라 번역할 것이 없다 — 카탈로그에 끌려 들어가지 않게 verbatim.
                Text(verbatim: sectionLabel)
            }
        }
        .font(.caption2)
        .lineLimit(1)
        .widgetAccentable()
    }

    /// 2줄: 가장 큰 숫자 — 전체 남은 시간.
    @ViewBuilder
    private var headline: some View {
        Group {
            if let state = running {
                if let end = state.endDate {
                    Text(timerInterval: entry.date...end,
                         countsDown: true,
                         showsHours: state.mainDuration >= 3600)
                } else {
                    // 일시정지 중에는 흘러가는 카운트다운이 거짓말이 된다 — 멈춘 숫자를 그린다.
                    Text(verbatim: TimeMapper.clockText(state.remainingSeconds(at: entry.date)))
                }
            } else if finished != nil {
                Text("Done")
            } else {
                Text("No active timer")
            }
        }
        // 24pt — 세 줄이 서는 카드라 이보다 키우면 작은 워치(40mm)에서 아래 줄이 잘린다.
        .font(.system(size: 24, weight: .bold, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }

    /// 3줄: **다음 알림까지** — 이 앱이 기본 타이머 위젯과 다른 이유.
    /// 마지막 구간이라 다음 알림이 없으면 진행 막대가 그 자리를 대신한다.
    @ViewBuilder
    private var detail: some View {
        if let state = running, let alert = state.nextAlertDate(at: entry.date), alert > entry.date {
            HStack(spacing: 3) {
                Image(systemName: "bell.fill")
                Text("Next")
                Text(timerInterval: entry.date...alert, countsDown: true, showsHours: false)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else if let state = running, let end = state.endDate {
            ProgressView(timerInterval: entry.date...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
        } else if running == nil && finished == nil {
            Text("Tap to start")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: 원형 (accessoryCircular · 스마트 스택 옆자리와 워치 페이스)

    @ViewBuilder
    private var circular: some View {
        if let state = running, let end = state.endDate {
            ProgressView(timerInterval: entry.date...end, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                Text(timerInterval: entry.date...end, countsDown: true, showsHours: false)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .minimumScaleFactor(0.5)
            }
            .progressViewStyle(.circular)
        } else {
            // 일시정지·대기·종료는 모두 "지금 세고 있지 않다" — 심볼 하나로 충분하다.
            Gauge(value: pausedFraction) {
                Image(systemName: statusSymbol)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }

    // MARK: 한 줄 (accessoryInline)

    @ViewBuilder
    private var inline: some View {
        if let state = running, let end = state.endDate {
            Label {
                Text(timerInterval: entry.date...end, countsDown: true, showsHours: false)
            } icon: {
                Image(systemName: "timer")
            }
        } else if let state = running {
            Label(TimeMapper.clockText(state.remainingSeconds(at: entry.date)), systemImage: "pause.fill")
        } else {
            Label(AppName.display, systemImage: "timer")
        }
    }

    // MARK: 모서리 (accessoryCorner · 워치 페이스)

    @ViewBuilder
    private var corner: some View {
        if let state = running, let end = state.endDate {
            Image(systemName: "timer")
                .font(.title)
                .widgetLabel {
                    Text(timerInterval: entry.date...end, countsDown: true, showsHours: false)
                }
        } else {
            Image(systemName: statusSymbol)
                .font(.title)
        }
    }

    // MARK: - 상태 갈래
    //
    // 세 갈래뿐이다: 아직 돌고 있다 / 다 돌았다 / 아무것도 없다.

    /// 아직 남은 시간이 있는 타이머(일시정지 포함).
    private var running: WatchTimerState? {
        guard let state = entry.state, state.isActive(at: entry.date) else { return nil }
        return state
    }

    /// 다 돌았는데 앱에서 아직 정지하지 않은 타이머.
    private var finished: WatchTimerState? {
        guard let state = entry.state, !state.isActive(at: entry.date) else { return nil }
        return state
    }

    private var statusSymbol: String {
        if let state = running { return state.isPaused ? "pause.fill" : "timer" }
        if finished != nil { return "checkmark.circle.fill" }
        return "timer"
    }

    private var statusText: String {
        if let state = running {
            return state.isPaused ? String(localized: "Paused") : String(localized: "Running")
        }
        if finished != nil { return String(localized: "Timer") }
        return AppName.display
    }

    /// "2/3" — 알림으로 나뉜 구간이 둘 이상일 때만 붙인다(하나면 셀 것이 없다).
    private var sectionLabel: String? {
        guard let state = running,
              let progress = state.section(at: entry.date),
              progress.isDivided else { return nil }
        return "\(progress.index + 1)/\(progress.totalCount)"
    }

    /// 일시정지 중 원형 게이지가 멈춰 서 있을 자리.
    private var pausedFraction: Double {
        guard let state = running, state.mainDuration > 0 else { return 0 }
        let remaining = Double(state.remainingSeconds(at: entry.date))
        return min(1, max(0, remaining / Double(state.mainDuration)))
    }
}

// MARK: - Widget Definition

struct RereminderWatchTimerWidget: Widget {
    let kind: String = "RereminderWatchTimer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimerProvider()) { entry in
            WatchTimerWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName(AppName.display)
        .description(String(localized: "Shows current timer status"))
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}
