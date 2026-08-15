//
//  UsageInsights.swift
//  Rereminder
//
//  "이 앱이 실제로 쓸모가 있나"를 **이미 모으고 있는 데이터만으로** 계산한다.
//  새 수집 항목을 늘리지 않는다 — 수집이 늘면 개인정보 신고 범위도 같이 늘어난다.
//
//  근거
//   • 활성화 퍼널·리텐션: UsageEvent (app_open / timer_start / timer_complete)
//   • 가치·기능 채택: UsageSnapshot.metrics (UsageMetrics가 기기에서 센 값)
//   • 결제/온보딩 퍼널: AnalyticsManager가 허브로 보내는 이벤트 이름들
//
//  ⚠️ 전부 **순수 함수**다. 네트워크·CloudKit을 모르기 때문에 유닛 테스트가 가능하고,
//     화면(UsageStatsView)은 이미 받아온 표본을 넘겨주기만 하면 된다.
//  ⚠️ 이벤트에는 이름당 6시간 쓰로틀이 걸려 있다 — 같은 사람이 하루에 타이머를 열 번 돌려도
//     이벤트는 1건이다. **절대 건수가 아니라 설치 수와 단계 간 비율**을 보는 용도다.
//     "몇 번 했는지"는 이벤트가 아니라 스냅샷 metrics(로컬 카운터)가 답한다.
//

import Foundation

enum UsageInsights {

    // MARK: - 공통

    /// 이벤트 이름이 슬라이스(`paywall_shown:presentationMode`)를 달고 오므로 접두사로 맞춘다.
    static func installs(in samples: [ActivityReporter.EventSample], named prefix: String) -> Set<String> {
        var result = Set<String>()
        for sample in samples where sample.name == prefix || sample.name.hasPrefix(prefix + ":") {
            if let id = sample.installID { result.insert(id) }
        }
        return result
    }

    static func count(in samples: [ActivityReporter.EventSample], named prefix: String) -> Int {
        samples.filter { $0.name == prefix || $0.name.hasPrefix(prefix + ":") }.count
    }

    // MARK: - 퍼널

    struct FunnelStage: Identifiable {
        let name: String
        /// 이 단계에 도달한 서로 다른 설치 수.
        let installs: Int
        /// 첫 단계 대비 비율 (0.0 ~ 1.0).
        let rateFromTop: Double
        /// 직전 단계 대비 비율 (0.0 ~ 1.0). 첫 단계는 1.0.
        let rateFromPrevious: Double
        var id: String { name }
    }

    private static func funnel(_ steps: [(String, String)],
                               from samples: [ActivityReporter.EventSample]) -> [FunnelStage] {
        var stages: [FunnelStage] = []
        var topCount = 0
        var previousCount = 0

        for (index, step) in steps.enumerated() {
            let count = installs(in: samples, named: step.1).count
            if index == 0 { topCount = count }
            stages.append(FunnelStage(
                name: step.0,
                installs: count,
                rateFromTop: topCount > 0 ? Double(count) / Double(topCount) : 0,
                rateFromPrevious: index == 0 ? 1.0 : (previousCount > 0 ? Double(count) / Double(previousCount) : 0)
            ))
            previousCount = count
        }
        return stages
    }

    /// **이 앱에서 가장 중요한 퍼널** — 앱을 연 사람 중 몇이 타이머를 걸고, 몇이 끝까지 갔나.
    /// 마지막 칸이 이 앱이 실제로 쓸모를 낸 순간이다(알림이 울릴 때까지 함께 있었다는 뜻).
    static func activationFunnel(from samples: [ActivityReporter.EventSample]) -> [FunnelStage] {
        funnel([
            ("앱 열기", ActivityReporter.appOpenEvent),
            ("타이머 시작", "timer_start"),
            ("끝까지 완주", "timer_complete")
        ], from: samples)
    }

    /// 온보딩을 본 사람 중 몇이 끝까지 봤나.
    static func onboardingFunnel(from samples: [ActivityReporter.EventSample]) -> [FunnelStage] {
        funnel([
            ("온보딩 시작", "onboarding_shown"),
            ("온보딩 완료", "onboarding_completed")
        ], from: samples)
    }

    /// 페이월 노출 → 결제 시도 → 결제 완료.
    static func paywallFunnel(from samples: [ActivityReporter.EventSample]) -> [FunnelStage] {
        funnel([
            ("페이월 노출", "paywall_shown"),
            ("결제 시도", "purchase_started"),
            ("결제 완료", "purchase_completed")
        ], from: samples)
    }

    struct DropoffReason: Identifiable {
        let name: String
        /// 건수 — 단계 수치(설치 수)와 달리 같은 설치가 여러 번 잡힐 수 있다.
        let events: Int
        var id: String { name }
    }

    /// 이탈 사유별 건수 — 퍼널만으로는 "왜 안 샀는지"가 안 보인다.
    static func dropoffReasons(from samples: [ActivityReporter.EventSample]) -> [DropoffReason] {
        [
            DropoffReason(name: "그냥 닫음", events: count(in: samples, named: "paywall_dismissed")),
            DropoffReason(name: "결제 실패·취소", events: count(in: samples, named: "purchase_failed")),
            DropoffReason(name: "온보딩 건너뜀", events: count(in: samples, named: "onboarding_skipped")),
            DropoffReason(name: "체험 소진", events: count(in: samples, named: "premium_trial_exhausted"))
        ]
    }

    // MARK: - 의견 요청(피드백 넛지) 반응

    struct NudgeResponse {
        /// 의견 요청을 본 설치 수.
        let shownInstalls: Int
        /// 그중 "의견 남기기"를 누른 설치 수.
        let acceptedInstalls: Int

        var acceptRate: Double { shownInstalls > 0 ? Double(acceptedInstalls) / Double(shownInstalls) : 0 }
    }

    /// 먼저 물어봤을 때 사람들이 실제로 답하는지 — 낮으면 묻는 시점이나 문구가 문제다.
    static func feedbackNudgeResponse(from samples: [ActivityReporter.EventSample]) -> NudgeResponse {
        NudgeResponse(shownInstalls: installs(in: samples, named: "feedback_nudge_shown").count,
                      acceptedInstalls: installs(in: samples, named: "feedback_nudge_accepted").count)
    }

    // MARK: - 핵심 가치

    struct ValueSummary {
        /// 스냅샷을 보낸 전체 설치 수.
        let totalInstalls: Int
        /// 타이머를 한 번이라도 완주한 설치 수 — 이 앱의 가치를 한 번은 받아 본 사람.
        let completedInstalls: Int
        /// 완주 총 횟수.
        let totalCompletions: Int
        /// 시작 총 횟수.
        let totalStarts: Int
        /// 완주한 타이머의 시간 합계(분) — "이 앱으로 관리한 시간"의 총량.
        let totalFocusMinutes: Int

        /// 시작한 타이머 중 끝까지 간 비율. **효용의 직접 지표** — 낮으면 도중에 그만두게 만드는 무언가가 있다.
        var completionRate: Double { totalStarts > 0 ? Double(totalCompletions) / Double(totalStarts) : 0 }
        /// 설치 중 한 번이라도 완주한 비율 — 온보딩·첫인상의 성패.
        var activationRate: Double { totalInstalls > 0 ? Double(completedInstalls) / Double(totalInstalls) : 0 }
        /// 완주해 본 설치당 평균 완주 횟수 — 한 번 써 본 사람이 계속 쓰는지.
        var completionsPerActiveInstall: Double {
            completedInstalls > 0 ? Double(totalCompletions) / Double(completedInstalls) : 0
        }
    }

    static func valueSummary(metrics snapshots: [[String: Double]]) -> ValueSummary {
        func total(_ key: String) -> Int {
            Int(snapshots.reduce(0.0) { $0 + ($1[key] ?? 0) }.rounded())
        }
        return ValueSummary(
            totalInstalls: snapshots.count,
            completedInstalls: snapshots.filter { ($0["timerCompletions"] ?? 0) > 0 }.count,
            totalCompletions: total("timerCompletions"),
            totalStarts: total("timerStarts"),
            totalFocusMinutes: total("focusMinutes")
        )
    }

    // MARK: - 완주 횟수 분포

    struct DistributionBucket: Identifiable {
        let label: String
        /// 이 구간에 속한 설치 수.
        let installs: Int
        let lowerBound: Int
        var id: String { label }
    }

    /// 완주 횟수로 설치를 나눈다 — **0회 칸이 이 화면에서 가장 중요한 숫자다.**
    /// 깔았지만 한 번도 끝까지 안 간 사람의 수이고, 그 크기가 곧 첫인상에서 새는 양이다.
    /// ⚠️ 라벨은 짧게 — x축에 여섯 칸이 서므로 길면 잘린다. 범위는 물결표로 쓴다.
    static func completionDistribution(metrics snapshots: [[String: Double]]) -> [DistributionBucket] {
        let bounds: [(String, Int, Int)] = [
            ("0회", 0, 0),
            ("1~2", 1, 2),
            ("3~5", 3, 5),
            ("6~10", 6, 10),
            ("11~30", 11, 30),
            ("31회 이상", 31, Int.max)
        ]
        return bounds.map { label, lower, upper in
            let count = snapshots.filter { metrics in
                let n = Int((metrics["timerCompletions"] ?? 0).rounded())
                return n >= lower && n <= upper
            }.count
            return DistributionBucket(label: label, installs: count, lowerBound: lower)
        }
    }

    // MARK: - 기능 채택률

    struct AdoptionSignal: Identifiable {
        let name: String
        let value: String
        /// 이 숫자를 어떻게 읽어야 하는지 — 숫자만 있으면 판단을 못 한다.
        let hint: String
        var id: String { name }
    }

    /// 제품·마케팅 판단에 바로 쓰이는 비율들.
    static func adoptionSignals(metrics snapshots: [[String: Double]]) -> [AdoptionSignal] {
        guard !snapshots.isEmpty else { return [] }
        let n = Double(snapshots.count)

        func ratio(_ predicate: ([String: Double]) -> Bool) -> String {
            String(format: "%.0f%%", Double(snapshots.filter(predicate).count) / n * 100)
        }

        let starts = snapshots.reduce(0.0) { $0 + ($1["timerStarts"] ?? 0) }
        let cancels = snapshots.reduce(0.0) { $0 + ($1["timerCancels"] ?? 0) }
        let cancelRate = starts > 0 ? cancels / starts * 100 : 0
        let avgFocus = snapshots.reduce(0.0) { $0 + ($1["focusMinutes"] ?? 0) } / n

        return [
            AdoptionSignal(name: "Pro 전환율",
                           value: ratio { ($0["flag.isPro"] ?? 0) > 0 },
                           hint: "결제까지 간 비율이에요."),
            AdoptionSignal(name: "알림 권한 허용",
                           value: ratio { ($0["flag.notificationsOn"] ?? 0) > 0 },
                           hint: "알림이 이 앱의 전부예요. 낮으면 타이머가 울리지 않는 사람이 그만큼 있다는 뜻이에요."),
            AdoptionSignal(name: "템플릿 사용",
                           value: ratio { ($0["flag.templateUser"] ?? 0) > 0 },
                           hint: "매번 다시 맞추지 않고 저장해 둔 걸 쓰는 비율 — 반복 사용의 신호예요."),
            AdoptionSignal(name: "발표 모드 사용",
                           value: ratio { ($0["flag.presentationUser"] ?? 0) > 0 },
                           hint: "Pro 기능을 실제로 쓰는 비율이에요."),
            AdoptionSignal(name: "워치 사용",
                           value: ratio { ($0["flag.watchUser"] ?? 0) > 0 },
                           hint: "워치 앱에 들이는 노력이 값을 하는지의 근거예요."),
            AdoptionSignal(name: "도중 취소 비율",
                           value: String(format: "%.0f%%", cancelRate),
                           hint: "시작한 타이머를 도중에 끄는 비율. 높으면 시간을 잘못 맞추거나 도중에 흥미를 잃는 거예요."),
            AdoptionSignal(name: "설치당 관리 시간",
                           value: String(format: "%.0f분", avgFocus),
                           hint: "한 설치가 이 앱으로 관리한 시간 평균이에요.")
        ]
    }

    // MARK: - 리텐션 코호트

    struct RetentionRow: Identifiable {
        /// 설치 주 시작일 (코호트 라벨).
        let cohortStart: Date
        /// 이 코호트의 설치 수.
        let size: Int
        /// D1 / D7 / D30 잔존 설치 수.
        let day1: Int
        let day7: Int
        let day30: Int
        var id: Date { cohortStart }

        func rate(_ retained: Int) -> Double { size > 0 ? Double(retained) / Double(size) : 0 }
    }

    /// 코호트 계산에 실제로 필요한 것만 담은 입력.
    /// ⚠️ `Snapshot`(CKRecord 전용 생성자만 있음)에 직접 의존하면 유닛 테스트로 검증할 수 없다.
    struct Install {
        let id: String
        let installDate: Date?
    }

    /// 주간 코호트 리텐션.
    /// - installDate로 코호트를 나누고, `app_open` 이벤트로 "그날 활동했는가"를 본다.
    /// - ⚠️ `app_open`은 20시간 쓰로틀이라 하루 1건 이하다 → 날짜 단위 판정에 적합하다.
    /// - ⚠️ 아직 그날이 오지 않은 설치는 잔존으로 세지 않는다 → 최근 코호트의 D30은 낮게 보인다.
    static func weeklyRetention(installs snapshots: [Install],
                                events: [ActivityReporter.EventSample],
                                calendar: Calendar = .current,
                                now: Date = Date()) -> [RetentionRow] {

        var activeDays: [String: Set<Date>] = [:]
        for event in events where event.name == ActivityReporter.appOpenEvent {
            guard let id = event.installID else { continue }
            activeDays[id, default: []].insert(calendar.startOfDay(for: event.date))
        }

        var cohorts: [Date: [(id: String, installedAt: Date)]] = [:]
        for snapshot in snapshots {
            guard let installDate = snapshot.installDate,
                  let week = calendar.dateInterval(of: .weekOfYear, for: installDate)?.start else { continue }
            cohorts[week, default: []].append((snapshot.id, installDate))
        }

        return cohorts.map { week, members in
            func retained(after offset: Int) -> Int {
                members.filter { member in
                    guard let target = calendar.date(byAdding: .day, value: offset,
                                                     to: calendar.startOfDay(for: member.installedAt)),
                          target <= now else { return false }   // 아직 안 온 날은 잔존으로 세지 않는다
                    return activeDays[member.id]?.contains(target) ?? false
                }.count
            }
            return RetentionRow(cohortStart: week,
                                size: members.count,
                                day1: retained(after: 1),
                                day7: retained(after: 7),
                                day30: retained(after: 30))
        }
        .sorted { $0.cohortStart > $1.cohortStart }
    }
}
