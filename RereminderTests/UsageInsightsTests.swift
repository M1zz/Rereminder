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

    // MARK: - 결제 관점 사용자 구분
    //
    // 이 앱의 결제는 알림 개수(무료 1개 + 5+5 체험)로 갈린다. 여기 판정이 틀리면
    // "지금 몇 명이 결제 직전인가"가 통째로 틀린 숫자가 된다.

    private func user(_ id: String,
                      _ metrics: [String: Double],
                      lastActiveDaysAgo: Int? = 0,
                      now: Date = Date()) -> UsageInsights.UserRecord {
        UsageInsights.UserRecord(
            id: id,
            metrics: metrics,
            installDate: now.addingTimeInterval(-30 * 86_400),
            lastActiveAt: lastActiveDaysAgo.map { now.addingTimeInterval(-Double($0) * 86_400) },
            appVersion: "2.1.1",
            platform: "iOS"
        )
    }

    func test_profiles_stageFollowsAlertLimitDistance() {
        let users = [
            user("pro", ["flag.isPro": 1, "timerCompletions": 1]),
            user("blocked", ["trial.prealerts": 5, "alertsMax": 3, "timerCompletions": 4]),
            user("nearLimit", ["trial.prealerts": 4, "alertsMax": 2, "timerCompletions": 3]),
            user("trialing", ["trial.prealerts": 1, "alertsMax": 2, "timerCompletions": 2]),
            user("demand", ["timerCompletions": 5, "alertsMax": 1]),
            user("freeFit", ["timerCompletions": 1, "alertsMax": 1]),
            user("dormant", ["timerStarts": 2])
        ]
        let byID = Dictionary(uniqueKeysWithValues: UsageInsights.profiles(from: users).map { ($0.id, $0.stage) })

        XCTAssertEqual(byID["pro"], .pro)
        XCTAssertEqual(byID["blocked"], .blocked, "1차 체험 5회를 다 쓰면 결제해야 더 켠다")
        XCTAssertEqual(byID["nearLimit"], .nearLimit)
        XCTAssertEqual(byID["trialing"], .trialing)
        XCTAssertEqual(byID["demand"], .demand, "무료 범위지만 반복 사용 — 곧 필요해질 사람")
        XCTAssertEqual(byID["freeFit"], .freeFit)
        XCTAssertEqual(byID["dormant"], .dormant, "완주가 없으면 결제 이전에 가치 경험이 먼저다")
    }

    func test_profiles_extendedTrialPushesLimitToTen() {
        let users = [
            user("extended", ["trial.prealerts": 6, "flag.prealertTrialExtended": 1, "timerCompletions": 3]),
            user("notExtended", ["trial.prealerts": 6, "timerCompletions": 3])
        ]
        let byID = Dictionary(uniqueKeysWithValues: UsageInsights.profiles(from: users).map { ($0.id, $0) })

        XCTAssertEqual(byID["extended"]?.stage, .trialing)
        XCTAssertEqual(byID["extended"]?.trialRemaining, 4)
        XCTAssertEqual(byID["notExtended"]?.stage, .blocked)
        XCTAssertEqual(byID["notExtended"]?.trialRemaining, 0)
    }

    func test_profiles_limitHitMeansBlockedEvenWithoutTrialCounter() {
        // 옛 버전에서 넘어와 체험 카운터는 비어 있지만 막힌 기록은 있는 설치.
        let profile = UsageInsights.profiles(from: [user("x", ["alertLimitHits": 2, "timerCompletions": 3])]).first
        XCTAssertEqual(profile?.stage, .blocked)
    }

    func test_profiles_sortedByReadinessAndStaleUserRanksLower() {
        let base: [String: Double] = ["trial.prealerts": 5, "alertsMax": 3, "timerCompletions": 4]
        let profiles = UsageInsights.profiles(from: [
            user("stale", base, lastActiveDaysAgo: 90),
            user("fresh", base, lastActiveDaysAgo: 1)
        ])
        XCTAssertEqual(profiles.first?.id, "fresh", "같은 조건이면 최근에 쓴 사람이 먼저다")
        XCTAssertGreaterThan(profiles[0].readiness, profiles[1].readiness)
    }

    func test_paymentFunnel_isMonotonicAndCountsProInEveryStage() {
        let users = [
            // 결제자는 완주·알림 기록이 없어도 앞 단계를 지난 것으로 센다.
            user("pro", ["flag.isPro": 1]),
            user("blocked", ["trial.prealerts": 5, "alertsMax": 3, "timerCompletions": 4, "paywallViews": 2]),
            user("freeFit", ["timerCompletions": 1, "alertsMax": 1]),
            user("dormant", [:])
        ]
        let stages = UsageInsights.paymentFunnel(profiles: UsageInsights.profiles(from: users))

        XCTAssertEqual(stages.map(\.installs), [4, 3, 2, 2, 2, 1])
        for (index, stage) in stages.enumerated() where index > 0 {
            XCTAssertLessThanOrEqual(stage.installs, stages[index - 1].installs, "퍼널이 뒤집히면 안 된다")
        }
        XCTAssertEqual(stages.last?.name, "결제")
    }

    func test_purchaseReadiness_reachableExcludesUsersWhoLeft() {
        let hot: [String: Double] = ["trial.prealerts": 5, "alertsMax": 3, "timerCompletions": 4]
        let profiles = UsageInsights.profiles(from: [
            user("blockedFresh", hot, lastActiveDaysAgo: 2),
            user("blockedGone", hot, lastActiveDaysAgo: 60),
            user("near", ["trial.prealerts": 4, "alertsMax": 2, "timerCompletions": 2], lastActiveDaysAgo: 3),
            user("demand", ["timerCompletions": 4], lastActiveDaysAgo: 1),
            user("pro", ["flag.isPro": 1], lastActiveDaysAgo: 1)
        ])
        let readiness = UsageInsights.purchaseReadiness(profiles: profiles)

        XCTAssertEqual(readiness.blocked, 2)
        XCTAssertEqual(readiness.nearLimit, 1)
        XCTAssertEqual(readiness.nearPurchase, 3)
        XCTAssertEqual(readiness.reachable, 2, "60일 전에 마지막으로 쓴 사람은 두드릴 대상이 아니다")
        XCTAssertEqual(readiness.latentDemand, 1)
        XCTAssertEqual(readiness.paying, 1)
        XCTAssertEqual(readiness.total, 5)
    }

    func test_hotLeads_dropsPayingAndStaleUsers() {
        let hot: [String: Double] = ["trial.prealerts": 5, "alertsMax": 3, "timerCompletions": 4]
        let profiles = UsageInsights.profiles(from: [
            user("a", hot, lastActiveDaysAgo: 1),
            user("b", hot, lastActiveDaysAgo: 40),
            user("c", ["flag.isPro": 1, "trial.prealerts": 5], lastActiveDaysAgo: 1),
            user("d", ["timerCompletions": 1], lastActiveDaysAgo: 1)
        ])
        XCTAssertEqual(UsageInsights.hotLeads(profiles: profiles).map(\.id), ["a"])
    }

    func test_alertDemandDistribution_countsEveryInstallExactlyOnce() {
        let profiles = UsageInsights.profiles(from: [
            user("none", ["timerCompletions": 1]),          // 2.1.1 이전 설치 — 기록 없음
            user("one", ["alertsMax": 1]),
            user("two", ["alertsMax": 2]),
            user("three", ["alertsMax": 3]),
            user("four", ["alertsMax": 4]),
            user("five", ["alertsMax": 5]),
            user("many", ["alertsMax": 12])
        ])
        let buckets = UsageInsights.alertDemandDistribution(profiles: profiles)

        XCTAssertEqual(buckets.map(\.installs), [1, 1, 1, 1, 1, 2])
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.installs }, profiles.count)
    }

    func test_segmentCounts_coversEveryProfile() {
        let profiles = UsageInsights.profiles(from: [
            user("pro", ["flag.isPro": 1]),
            user("blocked", ["trial.prealerts": 5]),
            user("dormant", [:]),
            user("dormant2", ["timerStarts": 3])
        ])
        let counts = UsageInsights.segmentCounts(profiles: profiles)
        XCTAssertEqual(counts.reduce(0) { $0 + $1.count }, profiles.count)
        XCTAssertEqual(counts.first { $0.stage == .dormant }?.count, 2)
    }
}
