//
//  UsageInsightsTests.swift
//  RereminderTests
//
//  사용 통계 집계(순수 함수)의 계산 규칙 검증 — 네트워크·CloudKit은 건드리지 않는다.
//  이 숫자들로 제품 판단을 하므로, 조용히 틀리면 잘못된 결정을 내리게 된다.
//

import XCTest
@testable import Rereminder

final class UsageInsightsTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func sample(_ name: String, _ install: String?, daysAgo: Double, now: Date) -> ActivityReporter.EventSample {
        ActivityReporter.EventSample(name: name,
                                     installID: install,
                                     date: now.addingTimeInterval(-daysAgo * 86_400))
    }

    // MARK: - 핵심 가치

    func test_valueSummary_completionRateAndActivation() {
        let metrics: [[String: Double]] = [
            ["timerStarts": 10, "timerCompletions": 6, "focusMinutes": 120],
            ["timerStarts": 5, "timerCompletions": 2, "focusMinutes": 30],
            ["timerStarts": 5]   // 시작만 하고 한 번도 완주 안 한 설치
        ]
        let summary = UsageInsights.valueSummary(metrics: metrics)

        XCTAssertEqual(summary.totalInstalls, 3)
        XCTAssertEqual(summary.totalStarts, 20)
        XCTAssertEqual(summary.totalCompletions, 8)
        XCTAssertEqual(summary.totalFocusMinutes, 150)
        XCTAssertEqual(summary.completedInstalls, 2)
        XCTAssertEqual(summary.completionRate, 0.4, accuracy: 0.0001)
        XCTAssertEqual(summary.activationRate, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(summary.completionsPerActiveInstall, 4, accuracy: 0.0001)
    }

    func test_valueSummary_emptyInput_doesNotDivideByZero() {
        let summary = UsageInsights.valueSummary(metrics: [])
        XCTAssertEqual(summary.completionRate, 0)
        XCTAssertEqual(summary.activationRate, 0)
        XCTAssertEqual(summary.completionsPerActiveInstall, 0)
    }

    // MARK: - 완주 횟수 분포

    func test_completionDistribution_countsEveryInstallExactlyOnce() {
        let metrics: [[String: Double]] = [
            [:],                          // 0회 (지표 자체가 없는 신규 설치)
            ["timerCompletions": 0],      // 0회
            ["timerCompletions": 2],
            ["timerCompletions": 5],
            ["timerCompletions": 30],
            ["timerCompletions": 31],
            ["timerCompletions": 900]
        ]
        let buckets = UsageInsights.completionDistribution(metrics: metrics)

        XCTAssertEqual(buckets.map(\.installs).reduce(0, +), metrics.count, "구간이 겹치거나 비면 분포가 거짓말을 한다")
        XCTAssertEqual(buckets.first?.installs, 2, "지표가 없는 설치도 0회로 잡혀야 한다")
        XCTAssertEqual(buckets.last?.installs, 2)
    }

    // MARK: - 퍼널

    func test_activationFunnel_countsDistinctInstallsPerStage() {
        let now = Date()
        let samples = [
            sample("app_open", "A", daysAgo: 1, now: now),
            sample("app_open", "A", daysAgo: 2, now: now),   // 같은 설치 재방문 → 1곳으로 센다
            sample("app_open", "B", daysAgo: 1, now: now),
            sample("app_open", "C", daysAgo: 1, now: now),
            sample("timer_start", "A", daysAgo: 1, now: now),
            sample("timer_start", "B", daysAgo: 1, now: now),
            sample("timer_complete", "A", daysAgo: 1, now: now)
        ]
        let stages = UsageInsights.activationFunnel(from: samples)

        XCTAssertEqual(stages.map(\.installs), [3, 2, 1])
        XCTAssertEqual(stages[1].rateFromTop, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(stages[2].rateFromPrevious, 0.5, accuracy: 0.0001)
    }

    func test_funnel_matchesSlicedEventNames() {
        let now = Date()
        // 페이월 이벤트는 "paywall_shown:presentationMode" 처럼 슬라이스를 달고 온다
        let samples = [
            sample("paywall_shown:presentationMode", "A", daysAgo: 1, now: now),
            sample("paywall_shown", "B", daysAgo: 1, now: now),
            sample("purchase_started", "A", daysAgo: 1, now: now)
        ]
        let stages = UsageInsights.paywallFunnel(from: samples)
        XCTAssertEqual(stages[0].installs, 2, "슬라이스가 붙어도 같은 단계로 세야 한다")
        XCTAssertEqual(stages[1].installs, 1)
        XCTAssertEqual(stages[2].installs, 0)
    }

    func test_funnel_withNoData_hasZeroRatesInsteadOfCrashing() {
        let stages = UsageInsights.activationFunnel(from: [])
        XCTAssertEqual(stages.map(\.installs), [0, 0, 0])
        XCTAssertEqual(stages[1].rateFromTop, 0)
    }

    // MARK: - 리텐션

    func test_weeklyRetention_countsOnlyElapsedDays() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15)))
        let installedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let day1 = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: installedAt))

        let installs = [UsageInsights.Install(id: "A", installDate: installedAt),
                        UsageInsights.Install(id: "B", installDate: installedAt)]
        let events = [ActivityReporter.EventSample(name: "app_open", installID: "A", date: day1)]

        let rows = UsageInsights.weeklyRetention(installs: installs, events: events,
                                                 calendar: calendar, now: now)
        let row = try XCTUnwrap(rows.first)

        XCTAssertEqual(row.size, 2)
        XCTAssertEqual(row.day1, 1)
        XCTAssertEqual(row.rate(row.day1), 0.5, accuracy: 0.0001)
        XCTAssertEqual(row.day30, 0, "설치 후 30일이 아직 오지 않았으면 잔존으로 세지 않는다")
    }

    func test_weeklyRetention_ignoresNonAppOpenEvents() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15)))
        let installedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let day1 = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: installedAt))

        let rows = UsageInsights.weeklyRetention(
            installs: [UsageInsights.Install(id: "A", installDate: installedAt)],
            events: [ActivityReporter.EventSample(name: "timer_start", installID: "A", date: day1)],
            calendar: calendar, now: now
        )
        XCTAssertEqual(rows.first?.day1, 0, "활동일 판정은 app_open(하루 1건 쓰로틀)만 본다")
    }

    // MARK: - 기간별 추이

    func test_trend_fillsEmptyBucketsSoChartDoesNotBreak() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12)))
        let events = [
            ActivityReporter.EventSample(name: "app_open", installID: "A",
                                         date: now.addingTimeInterval(-4 * 86_400)),
            ActivityReporter.EventSample(name: "app_open", installID: "B",
                                         date: now.addingTimeInterval(-4 * 86_400)),
            ActivityReporter.EventSample(name: "timer_start", installID: "A", date: now)
        ]

        let points = ActivityReporter.trend(unit: .day, events: events, installDates: [],
                                            calendar: calendar, now: now)

        XCTAssertEqual(points.count, 5, "가운데 빈 날도 0으로 채워야 차트가 끊기지 않는다")
        XCTAssertEqual(points.first?.events, 2)
        XCTAssertEqual(points.first?.activeInstalls, 2)
        XCTAssertEqual(points[1].events, 0)
        XCTAssertEqual(points.last?.activeInstalls, 1)
    }

    func test_trend_countsNewInstallsFromInstallDates() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12)))
        let points = ActivityReporter.trend(unit: .day, events: [],
                                            installDates: [now, now, now.addingTimeInterval(-86_400)],
                                            calendar: calendar, now: now)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points.first?.newInstalls, 1)
        XCTAssertEqual(points.last?.newInstalls, 2)
    }

    func test_trend_withNoData_returnsEmpty() {
        XCTAssertTrue(ActivityReporter.trend(unit: .day, events: [], installDates: []).isEmpty)
    }

    // MARK: - 이벤트 집계

    func test_eventStats_separatesCountFromInstallReach() {
        let now = Date()
        let samples = [
            sample("timer_start", "A", daysAgo: 0, now: now),
            sample("timer_start", "A", daysAgo: 1, now: now),
            sample("timer_start", "B", daysAgo: 1, now: now),
            sample("timer_complete", nil, daysAgo: 1, now: now)   // 구버전 레코드(installID 없음)
        ]
        let stats = ActivityReporter.eventStats(from: samples)

        let start = stats.first { $0.name == "timer_start" }
        XCTAssertEqual(start?.count, 3)
        XCTAssertEqual(start?.installs, 2)

        let complete = stats.first { $0.name == "timer_complete" }
        XCTAssertEqual(complete?.count, 1)
        XCTAssertEqual(complete?.installs, 0, "installID가 없는 옛 레코드는 설치 수에 못 넣는다")
    }
}
