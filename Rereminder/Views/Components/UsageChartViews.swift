//
//  UsageChartViews.swift
//  Rereminder
//
//  사용 통계 화면(개발자 전용)의 **그림 조각들** — 분포·퍼널·리텐션·비율을 같은 규칙으로 그린다.
//  숫자만 늘어놓으면 "어디가 크고 어디서 새는지"를 매번 머리로 계산해야 해서, 비교가 있는 값은
//  전부 차트로 세운다(숫자는 차트 위·옆에 그대로 남긴다 — 막대 높이로는 3인지 4인지 못 읽는다).
//
//  규칙 (여기 있는 모든 차트가 공유한다)
//   • **한 차트에 축은 하나.** 단위가 다른 두 값(실행 수 vs 사람 수)은 겹쳐 그리지 않고
//     피커로 갈아 끼운다 — 축이 둘이면 아무 관계나 만들어 낸다.
//   • 계열이 하나면 색도 하나(테마 강조색). 색으로 구분해야 하는 건 리텐션(D1·D7·D30)뿐이고,
//     그 세 색은 색각 이상에서도 갈라지는 조합으로 고정해 두고 점 모양·직접 라벨을 함께 붙인다.
//   • 값은 막대에 직접 붙인다. 축 눈금은 물러나고(회색·얇게), 강조는 데이터가 한다.
//
//  ⚠️ 개발자 전용 화면이라 문구는 한국어 그대로 두되 `Text(verbatim:)`으로 쓴다 —
//     문자열 카탈로그(Localizable.xcstrings)에 추출되면 다국어 검사(predeploy)가 막힌다.
//     Charts 의 `.value("한글", …)` 리터럴도 같은 이유로 **String 상수를 넘겨야** 한다
//     (리터럴을 직접 쓰면 LocalizedStringKey 오버로드가 잡혀 카탈로그로 새어 나간다).
//

import SwiftUI
import Charts

// MARK: - 색

enum UsageChartPalette {
    /// 계열이 하나뿐인 차트의 색 — 앱 테마 강조색을 그대로 쓴다.
    static let single = Color.accentColor

    /// 계열이 여럿일 때만 쓰는 고정 3색(파랑·주황·초록).
    /// 색각 이상(적록·청황) 시뮬레이션과 밝기 대비를 통과한 조합이라 **임의로 바꾸지 말 것.**
    /// 라이트/다크에서 각각 다른 단계를 쓴다 — 한쪽에서만 보이는 색은 없는 색이다.
    private static let lightSeries: [Color] = [
        Color(red: 0.165, green: 0.471, blue: 0.839),   // #2A78D6
        Color(red: 0.922, green: 0.408, blue: 0.204),   // #EB6834
        Color(red: 0.106, green: 0.686, blue: 0.478)    // #1BAF7A
    ]
    private static let darkSeries: [Color] = [
        Color(red: 0.224, green: 0.529, blue: 0.898),   // #3987E5
        Color(red: 0.851, green: 0.349, blue: 0.149),   // #D95926
        Color(red: 0.098, green: 0.620, blue: 0.439)    // #199E70
    ]

    static func series(_ index: Int, _ scheme: ColorScheme) -> Color {
        let palette = scheme == .dark ? darkSeries : lightSeries
        return palette[index % palette.count]
    }
}

// MARK: - 분포 (세로 막대)

/// 구간별 개수를 세로 막대로. 칸 수가 적고 순서가 정해진 값(완주 횟수·알림 개수)에 쓴다.
struct UsageDistributionChart: View {
    struct Item: Identifiable {
        let label: String
        let value: Int
        /// 눈이 먼저 가야 하는 칸(예: 완주 0회). 색이 아니라 **테두리 + 굵은 라벨**로 표시한다.
        var isKey: Bool = false
        var id: String { label }
    }

    let items: [Item]
    /// 막대 위에 붙는 단위 — "곳"(설치) / "회"(실행) 처럼.
    var unit: String = "곳"
    var height: CGFloat = 170

    private static let bucketAxis = "구간"
    private static let countAxis = "개수"

    private var total: Int { items.reduce(0) { $0 + $1.value } }

    var body: some View {
        Chart(items) { item in
            BarMark(
                x: .value(Self.bucketAxis, item.label),
                y: .value(Self.countAxis, item.value)
            )
            .cornerRadius(4)
            .foregroundStyle(UsageChartPalette.single.gradient)
            .opacity(item.isKey || !items.contains(where: \.isKey) ? 1 : 0.55)
            .annotation(position: .top, spacing: 2) {
                Text(verbatim: "\(item.value)")
                    .font(.caption2.monospacedDigit().weight(item.isKey ? .bold : .regular))
                    .foregroundStyle(item.isKey ? .primary : .secondary)
            }
            .accessibilityLabel(item.label)
            .accessibilityValue(Text(verbatim: "\(item.value)\(unit)"))
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(verbatim: label).font(.caption2)
                    }
                }
            }
        }
        .frame(height: height)
        .padding(.top, 8)
        .overlay(alignment: .topTrailing) {
            if total > 0 {
                Text(verbatim: "합계 \(total)\(unit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 퍼널 (가로 막대)

/// 단계별 인원을 가로 막대로 — 이름이 길고 칸이 줄어드는 모양을 봐야 해서 가로로 눕힌다.
struct UsageFunnelChart: View {
    let stages: [UsageInsights.FunnelStage]

    private static let stageAxis = "단계"
    private static let installAxis = "설치"

    var body: some View {
        Chart(stages) { stage in
            BarMark(
                x: .value(Self.installAxis, stage.installs),
                y: .value(Self.stageAxis, stage.name)
            )
            .cornerRadius(4)
            .foregroundStyle(UsageChartPalette.single.gradient)
            .annotation(position: .trailing, spacing: 4) {
                Text(verbatim: Self.annotation(stage))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(stage.name)
            .accessibilityValue(Self.annotation(stage))
        }
        // 단계 순서는 데이터의 뜻 그 자체다 — 값 크기로 정렬되면 퍼널이 아니게 된다.
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(verbatim: label).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        // 오른쪽 주석이 잘리지 않게 여유를 준다.
        .chartXScale(domain: 0...max(1, Int(Double(stages.first?.installs ?? 1) * 1.45)))
        .chartYScale(domain: .automatic(dataType: String.self) { $0 = stages.map(\.name) })
        .frame(height: CGFloat(stages.count) * 34 + 12)
    }

    private static func annotation(_ stage: UsageInsights.FunnelStage) -> String {
        let rate = String(format: "%.0f%%", stage.rateFromTop * 100)
        return "\(stage.installs)곳 · \(rate)"
    }
}

// MARK: - 비율 (가로 막대, 0~100%)

/// 서로 다른 항목의 **같은 단위(%) 비율**을 한 축에 세운다.
struct UsageRatioChart: View {
    struct Item: Identifiable {
        let label: String
        /// 0.0 ~ 1.0
        let ratio: Double
        var id: String { label }
    }

    let items: [Item]

    private static let itemAxis = "항목"
    private static let ratioAxis = "비율"

    var body: some View {
        Chart(items) { item in
            BarMark(
                x: .value(Self.ratioAxis, item.ratio),
                y: .value(Self.itemAxis, item.label)
            )
            .cornerRadius(4)
            .foregroundStyle(UsageChartPalette.single.gradient)
            .annotation(position: .trailing, spacing: 4) {
                Text(verbatim: String(format: "%.0f%%", item.ratio * 100))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(item.label)
            .accessibilityValue(String(format: "%.0f%%", item.ratio * 100))
        }
        .chartXScale(domain: 0...1.15)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(verbatim: label).font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(dataType: String.self) { $0 = items.map(\.label) })
        .frame(height: CGFloat(items.count) * 28 + 12)
    }
}

// MARK: - 개수 나열 (버전·플랫폼·이벤트)

/// 이름표가 붙은 개수 목록을 큰 것부터 가로 막대로. 꼬리는 잘라내고 몇 개를 잘랐는지 밝힌다.
struct UsageBreakdownChart: View {
    struct Item: Identifiable {
        let label: String
        let value: Int
        /// 막대 옆에 덧붙일 설명(예: "설치 12곳").
        var detail: String?
        var id: String { label }
    }

    let items: [Item]
    var unit: String = "곳"
    var limit: Int = 8

    private static let itemAxis = "항목"
    private static let countAxis = "개수"

    private var shown: [Item] { Array(items.prefix(limit)) }
    private var hidden: Int { max(0, items.count - shown.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart(shown) { item in
                BarMark(
                    x: .value(Self.countAxis, item.value),
                    y: .value(Self.itemAxis, item.label)
                )
                .cornerRadius(4)
                .foregroundStyle(UsageChartPalette.single.gradient)
                .annotation(position: .trailing, spacing: 4) {
                    Text(verbatim: item.detail ?? "\(item.value)\(unit)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(item.label)
                .accessibilityValue(item.detail ?? "\(item.value)\(unit)")
            }
            .chartXScale(domain: 0...max(1, Int(Double(shown.map(\.value).max() ?? 1) * 1.5)))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(verbatim: label).font(.caption2)
                        }
                    }
                }
            }
            .chartYScale(domain: .automatic(dataType: String.self) { $0 = shown.map(\.label) })
            .frame(height: CGFloat(shown.count) * 26 + 12)

            // 잘라낸 걸 숨기면 "이게 전부"로 읽힌다.
            if hidden > 0 {
                Text(verbatim: "그 밖에 \(hidden)개는 생략했어요.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 리텐션 (선 3개)

/// 주간 코호트의 D1·D7·D30 잔존율. **이 화면에서 유일하게 색으로 계열을 구분하는 차트**라
/// 점 모양과 범례를 함께 붙인다(색만으로 구분하면 색각 이상에서 읽히지 않는다).
struct UsageRetentionChart: View {
    @Environment(\.colorScheme) private var colorScheme

    let rows: [UsageInsights.RetentionRow]

    private static let cohortAxis = "코호트"
    private static let rateAxis = "잔존율"
    private static let seriesAxis = "기준일"

    private struct Point: Identifiable {
        let cohort: Date
        let series: String
        let rate: Double
        let order: Int
        var id: String { "\(cohort.timeIntervalSince1970)-\(series)" }
    }

    private var points: [Point] {
        rows.flatMap { row in
            [
                Point(cohort: row.cohortStart, series: "D1", rate: row.rate(row.day1), order: 0),
                Point(cohort: row.cohortStart, series: "D7", rate: row.rate(row.day7), order: 1),
                Point(cohort: row.cohortStart, series: "D30", rate: row.rate(row.day30), order: 2)
            ]
        }
    }

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value(Self.cohortAxis, point.cohort, unit: .weekOfYear),
                y: .value(Self.rateAxis, point.rate)
            )
            .foregroundStyle(by: .value(Self.seriesAxis, point.series))
            .symbol(by: .value(Self.seriesAxis, point.series))
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.monotone)

            PointMark(
                x: .value(Self.cohortAxis, point.cohort, unit: .weekOfYear),
                y: .value(Self.rateAxis, point.rate)
            )
            .foregroundStyle(by: .value(Self.seriesAxis, point.series))
            .symbol(by: .value(Self.seriesAxis, point.series))
            .symbolSize(60)
            .accessibilityLabel(Text(verbatim: point.series))
            .accessibilityValue(String(format: "%.0f%%", point.rate * 100))
        }
        .chartForegroundStyleScale([
            "D1": UsageChartPalette.series(0, colorScheme),
            "D7": UsageChartPalette.series(1, colorScheme),
            "D30": UsageChartPalette.series(2, colorScheme)
        ])
        // 점 모양까지 계열마다 다르게 — 색만으로 구분하면 색각 이상에서 세 선이 한 색이 된다.
        .chartSymbolScale([
            "D1": BasicChartSymbolShape.circle,
            "D7": BasicChartSymbolShape.square,
            "D30": BasicChartSymbolShape.triangle
        ])
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.25, 0.5, 0.75, 1]) { value in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text(verbatim: String(format: "%.0f%%", rate * 100)).font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(verbatim: Self.weekLabel(date)).font(.caption2)
                    }
                }
            }
        }
        .chartLegend(position: .bottom, spacing: 8)
        .frame(height: 190)
    }

    private static func weekLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }
}
