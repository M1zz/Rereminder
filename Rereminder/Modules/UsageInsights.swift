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
        /// 0~1 비율. 차트로 나란히 세울 수 있는 값만 채운다(분·시간처럼 단위가 다른 값은 nil).
        let ratio: Double?
        var id: String { name }

        init(name: String, value: String, hint: String, ratio: Double? = nil) {
            self.name = name
            self.value = value
            self.hint = hint
            self.ratio = ratio
        }
    }

    /// 제품·마케팅 판단에 바로 쓰이는 비율들.
    static func adoptionSignals(metrics snapshots: [[String: Double]]) -> [AdoptionSignal] {
        guard !snapshots.isEmpty else { return [] }
        let n = Double(snapshots.count)

        func share(_ predicate: ([String: Double]) -> Bool) -> Double {
            Double(snapshots.filter(predicate).count) / n
        }
        func percentText(_ value: Double) -> String { String(format: "%.0f%%", value * 100) }

        let starts = snapshots.reduce(0.0) { $0 + ($1["timerStarts"] ?? 0) }
        let cancels = snapshots.reduce(0.0) { $0 + ($1["timerCancels"] ?? 0) }
        let cancelRate = starts > 0 ? cancels / starts * 100 : 0
        let avgFocus = snapshots.reduce(0.0) { $0 + ($1["focusMinutes"] ?? 0) } / n

        let pro = share { ($0["flag.isPro"] ?? 0) > 0 }
        let notifications = share { ($0["flag.notificationsOn"] ?? 0) > 0 }
        let templates = share { ($0["flag.templateUser"] ?? 0) > 0 }
        let presentation = share { ($0["flag.presentationUser"] ?? 0) > 0 }
        let watch = share { ($0["flag.watchUser"] ?? 0) > 0 }

        return [
            AdoptionSignal(name: "Pro 전환율",
                           value: percentText(pro),
                           hint: "결제까지 간 비율이에요.",
                           ratio: pro),
            AdoptionSignal(name: "알림 권한 허용",
                           value: percentText(notifications),
                           hint: "알림이 이 앱의 전부예요. 낮으면 타이머가 울리지 않는 사람이 그만큼 있다는 뜻이에요.",
                           ratio: notifications),
            AdoptionSignal(name: "템플릿 사용",
                           value: percentText(templates),
                           hint: "매번 다시 맞추지 않고 저장해 둔 걸 쓰는 비율 — 반복 사용의 신호예요.",
                           ratio: templates),
            AdoptionSignal(name: "발표 모드 사용",
                           value: percentText(presentation),
                           hint: "Pro 기능을 실제로 쓰는 비율이에요.",
                           ratio: presentation),
            AdoptionSignal(name: "워치 사용",
                           value: percentText(watch),
                           hint: "워치 앱에 들이는 노력이 값을 하는지의 근거예요.",
                           ratio: watch),
            AdoptionSignal(name: "도중 취소 비율",
                           value: String(format: "%.0f%%", cancelRate),
                           hint: "시작한 타이머를 도중에 끄는 비율. 높으면 시간을 잘못 맞추거나 도중에 흥미를 잃는 거예요.",
                           ratio: cancelRate / 100),
            // 분 단위라 위 비율들과 같은 축에 세울 수 없다 — 차트에서는 빠지고 숫자로만 남는다.
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

    // MARK: - 결제 관점의 사용자 구분 (설치별 **현재** 상태)
    //
    // 이 앱의 결제는 **알림을 몇 개까지 켤 수 있나**로 갈린다 — 무료는 1개, 그 위는 5+5 체험을
    // 다 쓴 뒤 결제다(ProGate). 그래서 "결제에 가까운 사람" = **알림 한도에 다가간 사람**이고,
    // 여기 있는 계산은 전부 그 거리를 재는 것이다.
    //
    // ⚠️ 이벤트가 아니라 **스냅샷**으로 계산한다. 이벤트는 이름당 6시간 쓰로틀이 걸린 과거형이라
    //    "지금 몇 명"을 셀 수 없다. 스냅샷은 설치당 1건 upsert라 그 설치의 현재 상태 그 자체다.
    // ⚠️ 알림 관련 지표(alertsMax·alertLimitHits·trial.prealerts)는 2.1.1에서 추가됐다.
    //    그 전에 깔려서 아직 새 스냅샷을 안 올린 설치는 값이 0이라 "기록 없음"으로 보인다.

    /// 집계에 실제로 필요한 것만 담은 설치 1건.
    /// ⚠️ `Snapshot`(CKRecord 전용 생성자만 있음)에 직접 의존하면 유닛 테스트로 검증할 수 없다.
    struct UserRecord {
        let id: String
        let metrics: [String: Double]
        let installDate: Date?
        let lastActiveAt: Date?
        let appVersion: String
        let platform: String

        init(id: String,
             metrics: [String: Double],
             installDate: Date? = nil,
             lastActiveAt: Date? = nil,
             appVersion: String = "-",
             platform: String = "-") {
            self.id = id
            self.metrics = metrics
            self.installDate = installDate
            self.lastActiveAt = lastActiveAt
            self.appVersion = appVersion
            self.platform = platform
        }
    }

    /// 결제까지의 거리로 나눈 사용자 구분. 위가 결제에 가깝다.
    enum PaymentStage: String, CaseIterable, Identifiable {
        /// 이미 결제했다.
        case pro
        /// 체험을 다 썼다 — **지금 알림을 더 켜려면 결제밖에 없는 사람.** 가장 가까운 후보다.
        case blocked
        /// 체험이 1~2회 남았다. 곧 위 칸으로 간다.
        case nearLimit
        /// 알림을 여러 개 쓰며 체험을 소비하는 중.
        case trialing
        /// 아직 무료 범위(알림 1개)지만 반복해서 완주하는 사람 — **곧 필요해질 사람.**
        case demand
        /// 쓰긴 쓰는데 알림 1개로 충분하다. 지금 구조로는 결제하지 않는다.
        case freeFit
        /// 아직 한 번도 완주하지 않았다. 결제 이전에 가치 경험이 먼저다.
        case dormant

        var id: String { rawValue }

        var label: String {
            switch self {
            case .pro:       return "결제함"
            case .blocked:   return "막힘 (결제해야 더 씀)"
            case .nearLimit: return "한도 임박 (체험 1~2회)"
            case .trialing:  return "체험 사용 중"
            case .demand:    return "곧 필요할 사람"
            case .freeFit:   return "무료로 충분"
            case .dormant:   return "가치 경험 전"
            }
        }

        /// 이 칸을 보고 무엇을 해야 하는지.
        var detail: String {
            switch self {
            case .pro:       return "결제를 마친 설치예요."
            case .blocked:   return "알림을 더 켜려다 막혀 있어요. 결제 안내가 가장 잘 먹히는 사람들이에요."
            case .nearLimit: return "체험이 곧 끝나요. 여기서 값을 못 느끼면 그냥 떠나요."
            case .trialing:  return "알림을 여러 개 쓰는 중이에요. 아직 여유가 있어요."
            case .demand:    return "무료 범위지만 반복해서 쓰는 사람이에요. 알림이 하나로 부족해지는 건 시간 문제예요."
            case .freeFit:   return "알림 1개로 충분한 사람이에요. 결제를 기대하기 어렵고, 다른 값을 줘야 움직여요."
            case .dormant:   return "아직 완주가 없어요. 결제 이전에 첫 성공이 먼저예요."
            }
        }

        /// 지금 결제 안내가 의미 있는 상태인지 (= 결제에 가까워진 사람).
        var isNearPurchase: Bool { self == .blocked || self == .nearLimit }
    }

    /// 설치 하나를 결제 관점에서 읽은 결과.
    struct UserProfile: Identifiable {
        let id: String
        let stage: PaymentStage
        /// 결제 근접도 0~100 — 명단을 정렬하는 용도다. 절대적인 확률이 아니다.
        let readiness: Int
        let isPro: Bool
        let starts: Int
        let completions: Int
        let focusMinutes: Int
        /// 한 타이머에 걸어 본 알림 개수의 최대값(0이면 아직 기록 없음).
        let alertsMax: Int
        /// 무료 한도를 넘겨 타이머를 시작한 횟수.
        let multiAlertRuns: Int
        /// 알림을 더 켜려다 막힌 횟수.
        let limitHits: Int
        let paywallViews: Int
        /// 발표 모드로 들어간 횟수 — 지금의 유료 축이 실제로 쓰인 횟수다.
        let presentationRuns: Int
        /// 지금 가지고 있는 템플릿 수.
        let templates: Int
        let trialUsed: Int
        /// 남은 체험 횟수(0이면 결제해야 더 쓴다).
        let trialRemaining: Int
        let lastActiveAt: Date?
        /// 마지막 활동으로부터 며칠 지났나(모르면 nil).
        let daysSinceActive: Int?
        let appVersion: String
        let platform: String

        /// 화면에 쓰는 짧은 식별자 — 익명 설치 UUID의 앞부분(레코드명은 `usage-<uuid>` 꼴).
        var shortID: String {
            let raw = id.hasPrefix("usage-") ? String(id.dropFirst("usage-".count)) : id
            return String(raw.prefix(8)).uppercased()
        }

        /// 알림을 **여러 개 쓰는** 사람인지(고정 기준 `heavyAlertThreshold`).
        /// ⚠️ 이제 결제 신호가 아니라 **수요의 크기**다 — 알림은 무료다.
        var hasAlertDemand: Bool {
            alertsMax >= heavyAlertThreshold || multiAlertRuns > 0 || limitHits > 0
        }

        /// 지금의 유료 영역(세션 운영 도구)을 실제로 건드려 본 사람인지.
        /// 과거 스냅샷을 위해 옛 축(알림 한도)의 흔적도 함께 본다 — 그때 막혔던 사람은
        /// 지금 기준으로도 "유료를 원한 사람"이다.
        var hasPaidToolDemand: Bool {
            presentationRuns > 0 || templates > ProGate.freeTemplateLimit || trialUsed > 0
                || limitHits > 0 || alertsMax > legacyFreeAlertLimit
        }
    }

    /// 반복 사용으로 "곧 유료 기능이 필요해질 사람"으로 보는 완주 횟수 기준.
    /// 3회면 우연이 아니라 습관으로 쓰는 쪽에 가깝다.
    static let repeatUseThreshold = 3

    /// "알림을 여러 개 쓰는 사람" 판정 기준 — **고정값 3이다.**
    ///
    /// ⚠️ 게이트를 따라가게 만들지 말 것. 예전에는 `ProGate.freePrealertLimit` 을 봤는데,
    ///    한도를 없애자 이 지표의 뜻이 통째로 바뀌어 **변경 전후를 같은 자로 비교할 수 없게**
    ///    된다. 알림은 이제 무료지만 개수는 여전히 **수요의 크기**를 말해 주므로, 자를 고정해
    ///    계속 잰다(`UsageMetrics.multiAlertThreshold` 와 같은 이유·다른 값).
    static let heavyAlertThreshold = 3

    /// 예전 무료 알림 한도(2개). **과거 스냅샷을 읽을 때만** 쓴다 —
    /// 그때 "한도에 막혔다"는 기록이 지금 축에서도 유료 수요의 흔적이기 때문이다.
    static let legacyFreeAlertLimit = 2

    /// 스냅샷 한 묶음을 결제 관점 프로필로 바꾼다.
    static func profiles(from users: [UserRecord],
                         calendar: Calendar = .current,
                         now: Date = Date()) -> [UserProfile] {
        users.map { user in
            func metric(_ key: String) -> Int { Int((user.metrics[key] ?? 0).rounded()) }
            func flag(_ key: String) -> Bool { (user.metrics[key] ?? 0) > 0 }

            let isPro = flag("flag.isPro")
            // 지금 축(발표 모드)의 체험 소진을 먼저 보고, 없으면 옛 축(알림)의 기록을 읽는다 —
            // 예전 스냅샷에는 `trial.presentation` 이 아예 없다.
            let trialUsed = max(metric("trial.presentation"), metric("trial.prealerts"))
            let trialLimit = (flag("flag.presentationTrialExtended") || flag("flag.prealertTrialExtended"))
                ? TrialCounter.secondStageLimit
                : TrialCounter.firstStageLimit
            let trialRemaining = max(0, trialLimit - trialUsed)
            let completions = metric("timerCompletions")
            let alertsMax = metric("alertsMax")
            let multiAlertRuns = metric("multiAlertRuns")
            let limitHits = metric("alertLimitHits")
            let paywallViews = metric("paywallViews")
            let presentationRuns = metric("presentationRuns")
            let templates = metric("templates")

            let daysSinceActive = user.lastActiveAt.map {
                calendar.dateComponents([.day], from: calendar.startOfDay(for: $0),
                                        to: calendar.startOfDay(for: now)).day ?? 0
            }

            let stage = self.stage(isPro: isPro,
                                   trialUsed: trialUsed,
                                   trialRemaining: trialRemaining,
                                   limitHits: limitHits,
                                   alertsMax: alertsMax,
                                   presentationRuns: presentationRuns,
                                   templates: templates,
                                   completions: completions)

            return UserProfile(
                id: user.id,
                stage: stage,
                readiness: readiness(stage: stage,
                                     limitHits: limitHits,
                                     paywallViews: paywallViews,
                                     completions: completions,
                                     alertsMax: alertsMax,
                                     daysSinceActive: daysSinceActive),
                isPro: isPro,
                starts: metric("timerStarts"),
                completions: completions,
                focusMinutes: metric("focusMinutes"),
                alertsMax: alertsMax,
                multiAlertRuns: multiAlertRuns,
                limitHits: limitHits,
                paywallViews: paywallViews,
                presentationRuns: presentationRuns,
                templates: templates,
                trialUsed: trialUsed,
                trialRemaining: trialRemaining,
                lastActiveAt: user.lastActiveAt,
                daysSinceActive: daysSinceActive,
                appVersion: user.appVersion,
                platform: user.platform
            )
        }
        .sorted { $0.readiness > $1.readiness }
    }

    /// 구분 규칙 한 곳 — 화면·명단·퍼널이 전부 이걸 쓴다(따로 판정하면 숫자가 갈라진다).
    private static func stage(isPro: Bool,
                              trialUsed: Int,
                              trialRemaining: Int,
                              limitHits: Int,
                              alertsMax: Int,
                              presentationRuns: Int,
                              templates: Int,
                              completions: Int) -> PaymentStage {
        if isPro { return .pro }

        // 지금의 유료 영역은 **세션 운영 도구**(발표 모드·템플릿)다.
        // 옛 축(알림 한도)의 흔적도 함께 본다 — 예전 스냅샷을 계속 읽어야 하고,
        // 그때 막혔던 사람은 지금 기준으로도 유료를 원한 사람이다.
        let touchedPaidArea = trialUsed > 0 || presentationRuns > 0
            || templates > ProGate.freeTemplateLimit
            || limitHits > 0 || alertsMax > legacyFreeAlertLimit

        if touchedPaidArea {
            if trialRemaining == 0 || limitHits > 0 { return .blocked }
            if trialRemaining <= 2 { return .nearLimit }
            return .trialing
        }
        if completions >= repeatUseThreshold { return .demand }
        if completions > 0 { return .freeFit }
        return .dormant
    }

    /// 결제 근접도 점수 — **명단 정렬용 순서값**이지 확률이 아니다.
    /// 규칙: 지금 막혀 있을수록, 막힌 경험이 많을수록, 앱을 실제로 쓸수록 위로 온다.
    /// 오래 안 들어온 사람은 내린다(막혀 있어도 이미 떠났으면 결제하지 않는다).
    private static func readiness(stage: PaymentStage,
                                  limitHits: Int,
                                  paywallViews: Int,
                                  completions: Int,
                                  alertsMax: Int,
                                  daysSinceActive: Int?) -> Int {
        if stage == .pro { return 100 }

        var score: Int
        switch stage {
        case .blocked:   score = 45
        case .nearLimit: score = 30
        case .trialing:  score = 15
        case .demand:    score = 8
        case .freeFit:   score = 3
        case .dormant:   score = 0
        case .pro:       score = 100
        }
        score += min(15, limitHits * 5)          // 막힌 경험 = 필요를 몸으로 겪은 횟수
        score += min(10, paywallViews * 3)       // 가격을 이미 본 사람
        score += min(15, completions)            // 값을 실제로 받은 정도
        if alertsMax >= heavyAlertThreshold { score += 10 }   // 알림을 여러 개 쓰는 = 수요가 큰

        switch daysSinceActive {
        case .some(let days) where days <= 7:  score += 5
        case .some(let days) where days <= 30: break
        case .some:                            score -= 15   // 한 달 넘게 안 들어온 사람
        case .none:                            break
        }
        return max(0, min(100, score))
    }

    // MARK: - 결제 퍼널 (지금 상태 기준)

    /// **알림 개수로 이어지는 결제 퍼널.** 각 칸은 "지금 이 상태인 설치 수"다.
    /// 결제한 사람은 앞 단계를 모두 지난 것으로 센다(그래야 칸이 뒤집히지 않는다).
    static func paymentFunnel(profiles: [UserProfile]) -> [FunnelStage] {
        let steps: [(String, (UserProfile) -> Bool)] = [
            ("설치", { _ in true }),
            ("가치 경험 (완주 1회+)", { $0.isPro || $0.completions > 0 }),
            ("알림 3개 이상 사용", { $0.isPro || $0.hasAlertDemand }),
            ("한도 도달·임박", { $0.isPro || $0.stage.isNearPurchase }),
            ("페이월 노출", { $0.isPro || $0.paywallViews > 0 }),
            ("결제", { $0.isPro })
        ]

        var stages: [FunnelStage] = []
        var topCount = 0
        var previousCount = 0
        for (index, step) in steps.enumerated() {
            let count = profiles.filter(step.1).count
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

    /// 사용자 구분별 인원 — 구분 순서(결제에 가까운 쪽부터) 그대로 돌려준다.
    static func segmentCounts(profiles: [UserProfile]) -> [(stage: PaymentStage, count: Int)] {
        PaymentStage.allCases.map { stage in
            (stage, profiles.filter { $0.stage == stage }.count)
        }
    }

    /// 지금 결제에 가까운 사람이 몇인지 — 화면 맨 위에 놓는 숫자들.
    struct PurchaseReadiness {
        /// 지금 알림을 더 켜려면 결제해야 하는 사람.
        let blocked: Int
        /// 체험이 1~2회 남은 사람.
        let nearLimit: Int
        /// 위 둘 중 최근에도 앱을 쓰는 사람 — **실제로 두드릴 수 있는 대상.**
        let reachable: Int
        /// 아직 무료 범위지만 반복해서 쓰는 사람 (곧 필요해질 사람).
        let latentDemand: Int
        /// 이미 결제한 사람.
        let paying: Int
        /// 전체 설치 수.
        let total: Int
        /// "최근"의 기준(일).
        let recentDays: Int

        /// 결제에 가까워진 사람(막힘 + 임박).
        var nearPurchase: Int { blocked + nearLimit }
        /// 전체 대비 비율.
        var nearPurchaseRate: Double { total > 0 ? Double(nearPurchase) / Double(total) : 0 }
        var payingRate: Double { total > 0 ? Double(paying) / Double(total) : 0 }
    }

    static func purchaseReadiness(profiles: [UserProfile], recentDays: Int = 14) -> PurchaseReadiness {
        func isRecent(_ profile: UserProfile) -> Bool {
            guard let days = profile.daysSinceActive else { return false }
            return days <= recentDays
        }
        return PurchaseReadiness(
            blocked: profiles.filter { $0.stage == .blocked }.count,
            nearLimit: profiles.filter { $0.stage == .nearLimit }.count,
            reachable: profiles.filter { $0.stage.isNearPurchase && isRecent($0) }.count,
            latentDemand: profiles.filter { $0.stage == .demand }.count,
            paying: profiles.filter(\.isPro).count,
            total: profiles.count,
            recentDays: recentDays
        )
    }

    /// 결제 안내를 지금 보낼 만한 사람 명단(근접도 순). 이미 결제한 사람은 빼고,
    /// 오래 안 들어온 사람도 뺀다 — 떠난 사람에게 파는 건 계산이 아니라 희망이다.
    static func hotLeads(profiles: [UserProfile], recentDays: Int = 14, limit: Int = 20) -> [UserProfile] {
        profiles
            .filter { !$0.isPro && $0.stage.isNearPurchase }
            .filter { ($0.daysSinceActive ?? Int.max) <= recentDays }
            .sorted { $0.readiness > $1.readiness }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - 알림 개수 수요 분포

    /// **몇 명이 알림을 몇 개까지 쓰는가** — 이 앱의 가격 경계가 어디에 놓여야 하는지를 말해 준다.
    /// 무료 한도(1개) 바로 위 칸이 크면 지금 경계가 매출을 만든다는 뜻이고,
    /// 1개 칸만 크면 아무리 조여도 결제가 늘지 않는다.
    static func alertDemandDistribution(profiles: [UserProfile]) -> [DistributionBucket] {
        let bounds: [(String, Int, Int)] = [
            ("기록 없음", 0, 0),
            ("1개", 1, 1),
            ("2개", 2, 2),
            ("3개", 3, 3),
            ("4개", 4, 4),
            ("5개 이상", 5, Int.max)
        ]
        return bounds.map { label, lower, upper in
            DistributionBucket(label: label,
                               installs: profiles.filter { $0.alertsMax >= lower && $0.alertsMax <= upper }.count,
                               lowerBound: lower)
        }
    }

    // MARK: - 주로 쓰는 알림 개수 (실행마다 센 히스토그램)

    /// 알림 개수 한 칸 — 같은 칸을 **실행 기준**과 **사람 기준** 두 가지로 읽는다.
    ///
    /// 두 숫자가 갈리는 게 이 칸의 요점이다: 실행 수가 큰 칸은 "이 앱이 실제로 굴러가는 모양"이고,
    /// 사람 수가 큰 칸은 "이 개수를 자기 기본값으로 삼은 사람"이다. 알림을 한 번 5개 걸어 본
    /// 사람은 앞의 칸만 올리고 뒤의 칸은 1개 칸에 남는다.
    struct AlertRunBucket: Identifiable {
        /// 알림 개수(`UsageMetrics.AlertRun.topBucket` 이면 "그 이상"을 모은 칸).
        let alerts: Int
        /// 이 개수로 시작한 타이머 실행 수(모든 설치 합).
        let runs: Int
        /// 이 개수를 **주로** 쓰는(=최빈값이 이 칸인) 설치 수.
        let installs: Int

        var isOpenEnded: Bool { alerts >= UsageMetrics.AlertRun.topBucket }
        /// x축에 일곱 칸이 서므로 짧게.
        var label: String {
            if alerts == 0 { return "없음" }
            return isOpenEnded ? "\(alerts)+" : "\(alerts)개"
        }
        var id: Int { alerts }
    }

    /// 스냅샷 1건의 알림 개수 히스토그램 (칸 번호 → 실행 수). 기록이 없으면 빈 딕셔너리.
    static func alertRunHistogram(metrics: [String: Double]) -> [Int: Int] {
        var histogram: [Int: Int] = [:]
        for bucket in UsageMetrics.AlertRun.allBuckets {
            let runs = Int((metrics[UsageMetrics.AlertRun.metricKey(bucket)] ?? 0).rounded())
            if runs > 0 { histogram[bucket] = runs }
        }
        return histogram
    }

    /// 이 설치가 **주로 쓰는** 알림 개수 = 히스토그램의 최빈값. 기록이 없으면 nil.
    /// ⚠️ 동률이면 **작은 쪽**을 고른다 — 수요를 부풀리지 않기 위해서다(결제 판단에 쓰는 값이라
    ///    과대평가가 과소평가보다 비싸다).
    static func typicalAlertCount(metrics: [String: Double]) -> Int? {
        let histogram = alertRunHistogram(metrics: metrics)
        guard let maxRuns = histogram.values.max() else { return nil }
        return histogram.filter { $0.value == maxRuns }.keys.min()
    }

    /// 결제 여부로 표본을 가르는 필터.
    ///
    /// **무료 한도를 몇 개로 둘지는 이 두 갈래를 나란히 놓고서만 정할 수 있다.**
    /// 무료 사용자의 분포는 한도에 눌린 값이라(1개에서 잘린다) 그것만 보면 "다들 1개면 충분하다"는
    /// 잘못된 결론이 난다. 눌리지 않은 값은 **결제한 사람의 분포**뿐이다 — 거기서 주로 쓰는
    /// 개수가 3개 이상이라면 무료를 2개로 올려도 팔 것이 남고, 2개라면 파는 것을 그대로 주는 셈이다.
    enum PlanFilter: String, CaseIterable, Identifiable {
        case all, free, paid
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:  return "전체"
            case .free: return "무료"
            case .paid: return "결제"
            }
        }

        func includes(_ metrics: [String: Double]) -> Bool {
            let isPro = (metrics["flag.isPro"] ?? 0) > 0
            switch self {
            case .all:  return true
            case .free: return !isPro
            case .paid: return isPro
            }
        }
    }

    /// 알림 개수 분포 — 실행 기준 합계와 "주로 그 개수를 쓰는 사람" 수를 한 칸에 담아 돌려준다.
    static func alertRunDistribution(metrics snapshots: [[String: Double]],
                                     plan: PlanFilter = .all) -> [AlertRunBucket] {
        var runsByBucket: [Int: Int] = [:]
        var typicalByBucket: [Int: Int] = [:]

        for metrics in snapshots where plan.includes(metrics) {
            for (bucket, runs) in alertRunHistogram(metrics: metrics) {
                runsByBucket[bucket, default: 0] += runs
            }
            if let typical = typicalAlertCount(metrics: metrics) {
                typicalByBucket[typical, default: 0] += 1
            }
        }

        return UsageMetrics.AlertRun.allBuckets.map { bucket in
            AlertRunBucket(alerts: bucket,
                           runs: runsByBucket[bucket] ?? 0,
                           installs: typicalByBucket[bucket] ?? 0)
        }
    }

    /// **가치를 경험했나** — 알림을 실제로 듣고 끝까지 간 실행이 얼마나 되나.
    ///
    /// 이 앱의 aha 는 "타이머를 끝냈다"가 아니라 **"끝나기 전에 알림이 울려서 도움이 됐다"** 다.
    /// 그래서 완주(`timerCompletions`) 중 **알림이 울린 완주**(`alertedCompletions`)의 몫을 따로 본다.
    /// 이 비율이 낮으면 사람들이 이 앱을 *평범한 타이머로* 쓰고 있다는 뜻이고, 그러면 알림 개수로
    /// 돈을 받는 지금 구조 자체가 어긋나 있다.
    struct AlertedValueSummary {
        /// 완주가 한 번이라도 있는 설치 수.
        let installsWithCompletion: Int
        /// 알림을 들은 완주가 한 번이라도 있는 설치 수 = **가치를 경험한 사람.**
        let installsWithAlertedCompletion: Int
        /// 완주 횟수 합계.
        let completions: Int
        /// 그중 알림이 울린 완주 횟수 합계.
        let alertedCompletions: Int

        /// 실행 기준 — 완주 중 알림을 들은 몫.
        var alertedRunRate: Double {
            completions > 0 ? Double(alertedCompletions) / Double(completions) : 0
        }
        /// 사람 기준 — 완주해 본 사람 중 알림까지 들어 본 몫.
        var alertedInstallRate: Double {
            installsWithCompletion > 0
                ? Double(installsWithAlertedCompletion) / Double(installsWithCompletion)
                : 0
        }
    }

    static func alertedValueSummary(metrics snapshots: [[String: Double]],
                                    plan: PlanFilter = .all) -> AlertedValueSummary {
        var installsWithCompletion = 0
        var installsWithAlerted = 0
        var completions = 0
        var alerted = 0

        for metrics in snapshots where plan.includes(metrics) {
            let done = Int((metrics[UsageMetrics.Key.timerCompletions.rawValue] ?? 0).rounded())
            let heard = Int((metrics[UsageMetrics.Key.alertedCompletions.rawValue] ?? 0).rounded())
            if done > 0 { installsWithCompletion += 1 }
            if heard > 0 { installsWithAlerted += 1 }
            completions += done
            // 옛 버전은 이 값을 보내지 않는다 — 없으면 0 이라 비율만 낮아지고 합계는 망가지지 않는다.
            alerted += min(heard, done)
        }

        return AlertedValueSummary(installsWithCompletion: installsWithCompletion,
                                   installsWithAlertedCompletion: installsWithAlerted,
                                   completions: completions,
                                   alertedCompletions: alerted)
    }

    /// 분포를 한 줄로 요약한 것 — 차트 위에 세우는 숫자들.
    struct AlertUsageSummary {
        /// 히스토그램을 보내온 설치 수(2.1.2 이전 버전은 아직 안 보낸다).
        let reportingInstalls: Int
        /// 전체 설치 수.
        let totalInstalls: Int
        /// 센 타이머 실행 수 합계.
        let totalRuns: Int
        /// 가장 많이 쓰인 알림 개수(실행 기준). 기록이 없으면 nil.
        let modeAlerts: Int?
        /// 실행 1회당 평균 알림 개수 — "6개 이상" 칸은 6으로 세므로 실제보다 낮게 나올 수 있다.
        let averageAlerts: Double
        /// **알림을 여러 개(3개 이상) 건** 실행의 비율 = 이 앱의 문장이 실제로 쓰이는 몫.
        /// ⚠️ 기준은 `heavyAlertThreshold` 로 **고정**이다 — 게이트를 따라가게 만들면
        ///    변경 전후를 같은 자로 비교할 수 없게 된다.
        let multiAlertRunRate: Double

        var coverageRate: Double {
            totalInstalls > 0 ? Double(reportingInstalls) / Double(totalInstalls) : 0
        }
    }

    static func alertUsageSummary(metrics snapshots: [[String: Double]],
                                  plan: PlanFilter = .all) -> AlertUsageSummary {
        let sample = snapshots.filter { plan.includes($0) }
        let buckets = alertRunDistribution(metrics: sample)
        let totalRuns = buckets.reduce(0) { $0 + $1.runs }
        let weighted = buckets.reduce(0) { $0 + $1.alerts * $1.runs }
        let heavyRuns = buckets.filter { $0.alerts >= heavyAlertThreshold }.reduce(0) { $0 + $1.runs }

        return AlertUsageSummary(
            reportingInstalls: sample.filter { !alertRunHistogram(metrics: $0).isEmpty }.count,
            totalInstalls: sample.count,
            totalRuns: totalRuns,
            modeAlerts: buckets.filter { $0.runs > 0 }.max { $0.runs < $1.runs }?.alerts,
            averageAlerts: totalRuns > 0 ? Double(weighted) / Double(totalRuns) : 0,
            multiAlertRunRate: totalRuns > 0 ? Double(heavyRuns) / Double(totalRuns) : 0
        )
    }
}
