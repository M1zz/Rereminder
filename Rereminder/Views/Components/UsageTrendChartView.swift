//
//  UsageTrendChartView.swift
//  Rereminder
//
//  사용 통계 화면(개발자 전용)의 기간별 추이 차트 — 일/주/월/연 단위를 고르고,
//  그 단위만큼 좌우로 스크롤하며 과거를 훑어본다. 데이터는 허브에서 읽어온 것을
//  ActivityReporter.trend(...)가 빈 구간까지 채워 만든 묶음이다.
//
//  ⚠️ 개발자 전용 화면이라 문구를 한국어 그대로 둔다(Text(verbatim:) — 문자열 카탈로그에
//     추출되지 않게). 사용자에게 보이는 화면에서는 이렇게 쓰지 말 것.
//  ⚠️ 통계 화면 본문이 이미 큰 List라 차트는 별도 뷰로 떼어 둔다(타입체크 부담 분산).
//

import SwiftUI
import Charts

struct UsageTrendChartView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let events: [ActivityReporter.EventSample]
    let installDates: [Date]

    @State private var unit: ActivityReporter.BucketUnit = .day
    @State private var metric: TrendMetric = .activeInstalls
    @State private var scrollPosition = Date()

    /// 탭한 막대의 시각 — 막대 높이만으로는 "3인지 4인지"를 읽을 수 없어서 값을 글자로 못박는다.
    @State private var selectedDate: Date?

    // MARK: - 표시할 값

    enum TrendMetric: String, CaseIterable, Identifiable {
        case activeInstalls, events, newInstalls
        var id: String { rawValue }

        var label: String {
            switch self {
            case .activeInstalls: return "활동한 사용자"
            case .events: return "사용 건수"
            case .newInstalls: return "신규 사용자"
            }
        }

        func value(_ point: ActivityReporter.TrendPoint) -> Int {
            switch self {
            case .activeInstalls: return point.activeInstalls
            case .events: return point.events
            case .newInstalls: return point.newInstalls
            }
        }
    }

    private var points: [ActivityReporter.TrendPoint] {
        ActivityReporter.trend(unit: unit, events: events, installDates: installDates)
    }

    /// 스크롤 창 길이(초) — 보이는 묶음 개수만큼.
    private var visibleDomain: TimeInterval {
        let bucketSeconds: TimeInterval
        switch unit {
        case .day: bucketSeconds = 86_400
        case .week: bucketSeconds = 7 * 86_400
        case .month: bucketSeconds = 30.5 * 86_400
        case .year: bucketSeconds = 365.25 * 86_400
        }
        return bucketSeconds * Double(unit.visibleBuckets)
    }

    private var visiblePoints: [ActivityReporter.TrendPoint] {
        let end = scrollPosition.addingTimeInterval(visibleDomain)
        return points.filter { $0.date >= scrollPosition && $0.date < end }
    }

    /// 탭한 x 좌표에 해당하는 묶음. `chartXSelection`이 주는 건 **누른 자리의 시각**이지
    /// 막대가 아니라, 가장 가까운 묶음을 직접 찾는다(묶음 사이 빈틈을 눌러도 답이 나온다).
    private var selectedPoint: ActivityReporter.TrendPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private func isSelected(_ point: ActivityReporter.TrendPoint) -> Bool {
        selectedPoint?.id == point.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ⚠️ Picker("", …)를 쓰면 빈 문자열이 문자열 카탈로그에 추출돼 다국어 검사가 막힌다.
            //    라벨은 verbatim으로 주고 화면에서만 숨긴다.
            Picker(selection: $unit) {
                ForEach(ActivityReporter.BucketUnit.allCases) { unit in
                    Text(verbatim: unit.label).tag(unit)
                }
            } label: {
                Text(verbatim: "기간 단위")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Picker(selection: $metric) {
                ForEach(TrendMetric.allCases) { metric in
                    Text(verbatim: metric.label).tag(metric)
                }
            } label: {
                Text(verbatim: "표시할 값")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if points.isEmpty {
                Text(verbatim: "아직 그릴 데이터가 없어요.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                chart
                summary
            }
        }
        .padding(.vertical, 4)
        .onAppear { scrollToLatest() }
        // 단위가 바뀌면 고른 자리도 뜻이 달라진다(같은 날을 가리켜도 이제 '그 달'이다) — 지운다.
        .onChange(of: unit) { _, _ in
            selectedDate = nil
            scrollToLatest()
        }
        .onChange(of: points.count) { _, _ in scrollToLatest() }
    }

    // MARK: - 차트

    /// 축 라벨 — **문자열 리터럴로 넘기면** LocalizedStringKey 오버로드가 잡혀 카탈로그에
    /// 한글 키가 추출된다(다국어 검사 실패). 변수로 넘겨 String 오버로드를 고른다.
    private static let periodAxisLabel = "기간"

    private var chart: some View {
        Chart(points) { point in
            BarMark(
                x: .value(Self.periodAxisLabel, point.date, unit: unit.calendarComponent),
                y: .value(metric.label, metric.value(point))
            )
            // 고른 막대만 제 색으로 두고 나머지는 물린다 — 어느 것을 읽고 있는지 한눈에.
            .foregroundStyle(Color.accentColor.gradient)
            .opacity(selectedPoint == nil || isSelected(point) ? 1 : 0.35)
            .accessibilityLabel(Self.axisLabel(point.date, unit: unit))
            .accessibilityValue("\(metric.value(point))")

            if let selected = selectedPoint, isSelected(point) {
                RuleMark(x: .value(Self.periodAxisLabel, selected.date, unit: unit.calendarComponent))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .zIndex(-1)
                    .annotation(position: .top, spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        readout(for: selected)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(verbatim: Self.axisLabel(date, unit: unit))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDomain)
        .chartScrollPosition(x: $scrollPosition)
        .chartScrollTargetBehavior(.valueAligned(matching: scrollAlignment))
        .frame(height: 200)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: metric)
    }

    /// 고른 막대의 정확한 날짜와 숫자 — 이 차트를 탭하는 이유 그 자체다.
    private func readout(for point: ActivityReporter.TrendPoint) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: Self.fullLabel(point.date, unit: unit))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(verbatim: "\(metric.label) \(metric.value(point))")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// 스크롤이 묶음 경계에 딱 맞게 멈추도록 — 단위별 정렬 기준.
    private var scrollAlignment: DateComponents {
        switch unit {
        case .day: return DateComponents(hour: 0)
        case .week: return DateComponents(hour: 0, weekday: Calendar.current.firstWeekday)
        case .month: return DateComponents(day: 1)
        case .year: return DateComponents(month: 1, day: 1)
        }
    }

    // MARK: - 보이는 구간 요약

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: visibleRangeText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: "이 구간 합계 \(metric.label) \(visiblePoints.reduce(0) { $0 + metric.value($1) })")
                .font(.body.weight(.semibold))
        }
        .accessibilityElement(children: .combine)
    }

    private var visibleRangeText: String {
        guard let first = visiblePoints.first?.date, let last = visiblePoints.last?.date else {
            return "좌우로 넘겨서 다른 기간을 보세요."
        }
        let start = Self.axisLabel(first, unit: unit)
        let end = Self.axisLabel(last, unit: unit)
        return start == end ? start : "\(start) ~ \(end)"
    }

    // MARK: - 라벨 / 스크롤 위치

    /// 탭했을 때 보여줄 **정확한** 날짜 — 축은 자리가 좁아 연도를 빼지만 여기서는 밝힌다.
    private static func fullLabel(_ date: Date, unit: ActivityReporter.BucketUnit) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        switch unit {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
            return formatter.string(from: date)
        case .week:
            formatter.setLocalizedDateFormatFromTemplate("yMMMd")
            return "\(formatter.string(from: date)) 주 시작"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMMM")
            return formatter.string(from: date)
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
            return formatter.string(from: date)
        }
    }

    private static func axisLabel(_ date: Date, unit: ActivityReporter.BucketUnit) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        switch unit {
        case .day, .week:
            formatter.setLocalizedDateFormatFromTemplate("Md")
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("yMMM")
        case .year:
            formatter.setLocalizedDateFormatFromTemplate("y")
        }
        return formatter.string(from: date)
    }

    /// 가장 최근 구간이 보이도록 스크롤 위치를 옮긴다.
    private func scrollToLatest() {
        guard let last = points.last?.date else { return }
        scrollPosition = last.addingTimeInterval(-visibleDomain + 1)
    }
}
