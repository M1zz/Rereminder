//
//  UsageMetrics.swift
//  Rereminder
//
//  이 설치의 **로컬 누적 카운터** — 익명 사용 스냅샷(metrics JSON)에 실려 나가는 값의 원천.
//
//  왜 따로 두나: 허브의 이벤트 스트림은 이름당 6시간 쓰로틀이 걸려 있어 "몇 번 했는지"를
//  셀 수 없다. 횟수는 기기에서 세고, 스냅샷 한 건에 요약해서 보낸다(설치당 1건 upsert).
//
//  ⚠️ 개수·분(分) 같은 집계 수치와 0/1 플래그만 담는다. 타이머 이름·메시지·시각 등
//     내용이나 식별자는 절대 넣지 않는다 — 이 딕셔너리는 그대로 서버로 나간다.
//  ⚠️ 이 파일은 LeeoKit/CloudKit을 모른다. 전송은 ActivityReporter가 담당한다.
//

import Foundation

enum UsageMetrics {

    /// 위젯·확장과 같은 값을 보게 앱 그룹에 쓴다(없으면 표준 저장소로 떨어진다).
    private static var store: UserDefaults {
        UserDefaults(suiteName: "group.leeo.toki") ?? .standard
    }

    /// 스냅샷 `metrics` JSON의 키 — **서버·과거 스냅샷과의 계약이다. 변경 금지.**
    /// (이름을 바꾸면 예전 스냅샷과 합산되지 않아 지표가 조용히 반토막 난다.)
    enum Key: String, CaseIterable {
        /// 타이머를 시작한 횟수.
        case timerStarts
        /// 타이머를 끝까지 마친 횟수.
        case timerCompletions
        /// **예비 알림이 실제로 울린 채로** 끝까지 마친 횟수 — 이 앱의 aha moment 카운터.
        ///
        /// 왜 `timerCompletions` 로는 부족한가: 알림이 한 번도 울리지 않은 완주는 평범한
        /// 타이머를 쓴 것과 같다. 이 앱이 파는 것은 "끝나기 전에 여러 번 알려 준다"이므로,
        /// **그 알림을 실제로 들은 완주**만이 가치를 경험했다는 증거다.
        /// 결제 판단(무료 한도를 몇 개로 둘까)의 기준선이 되는 값이라 따로 센다.
        case alertedCompletions
        /// 도중에 그만둔 횟수.
        case timerCancels
        /// 완주한 타이머의 시간 합계(분) — "이 앱으로 관리한 시간"의 총량.
        case focusMinutes
        /// 발표 모드로 들어간 횟수.
        case presentationRuns
        /// 템플릿을 저장한 횟수.
        case presetSaves
        /// 템플릿으로 타이머를 채운 횟수.
        case presetUses
        /// 워치와 동기화한 횟수.
        case watchSyncUses
        /// 지금 가지고 있는 템플릿 수(누적이 아니라 현재값).
        case templates
        /// 한 타이머에 걸어 본 알림 개수의 **최대값**(누적이 아니라 최고 기록).
        /// 결제 경계는 아니지만(무제한 무료) 이 값이 곧 그 사람의 **수요 크기**다.
        case alertsMax
        /// **알림을 2개 이상** 걸고 시작한 횟수 — 이 앱의 문장("여러 번 알려 준다")이 실제로
        /// 쓰인 횟수다. ⚠️ 기준(2개)은 게이트와 무관하게 **고정**이다(`multiAlertThreshold`) —
        /// 게이트를 따라 바꾸면 과거 스냅샷과 합산되지 않아 지표가 조용히 끊긴다.
        case multiAlertRuns
        /// 알림을 더 켜려다 한도에 막힌 횟수.
        /// ⚠️ **더 이상 늘지 않는다** — 알림 한도를 없앴다(`ProGate` 머리말). 키를 지우면 예전
        ///    스냅샷이 통째로 읽히지 않으므로 **역사 기록으로 남겨 둔다.** 되살리지 말 것.
        case alertLimitHits
        /// 막힌 자리에서 이번 한 번을 내준 횟수(하루 1회 유예).
        /// ⚠️ `alertLimitHits` 와 같은 이유로 **늘지 않지만 남겨 둔** 키다.
        case graceGrants
        /// 페이월을 본 횟수.
        case paywallViews

        var storageKey: String { "usage.metric.\(rawValue)" }
    }

    /// `multiAlertRuns` 가 세는 기준 — **고정값이다.** 게이트가 바뀌어도 이 정의는 그대로 둬야
    /// 변경 전후를 같은 자로 비교할 수 있다.
    static let multiAlertThreshold = 2

    /// 한 타이머에 **알림을 몇 개 걸었는지**의 히스토그램 — 실행할 때마다 그 개수 칸을 하나 올린다.
    ///
    /// 왜 `alertsMax` 로는 부족한가: 한 번 5개를 걸어 본 사람과 늘 5개를 거는 사람이 같은 값으로
    /// 보인다. "주로 몇 개를 쓰나"(=이 앱이 실제로 팔고 있는 크기)는 실행마다 세야만 나온다.
    ///
    /// 스냅샷 키는 `alertRuns.0` … `alertRuns.6plus` — **서버·과거 스냅샷과의 계약이다. 변경 금지.**
    enum AlertRun {
        /// 이 개수부터는 한 칸에 모은다 — 그 위는 표본이 얇아 칸만 늘어난다.
        static let topBucket = 6

        /// 알림 개수 → 칸 번호(0…topBucket).
        static func bucket(for alertCount: Int) -> Int {
            min(max(0, alertCount), topBucket)
        }

        /// 칸 번호 → 스냅샷 키.
        static func metricKey(_ bucket: Int) -> String {
            bucket >= topBucket ? "alertRuns.\(topBucket)plus" : "alertRuns.\(bucket)"
        }

        static var allBuckets: [Int] { Array(0...topBucket) }

        fileprivate static func storageKey(_ bucket: Int) -> String { "usage.metric.\(metricKey(bucket))" }
    }

    // MARK: - 기록

    /// 분석 이벤트 1건을 로컬 카운터에 반영한다. `AnalyticsManager.log`가 단독으로 부른다.
    static func apply(_ event: AnalyticsManager.Event) {
        switch event {
        case .timerStarted(_, let alertCount, _):
            increment(.timerStarts)
            // 알림 개수는 이제 결제 경계가 아니지만(무제한 무료), **수요의 크기**를 재는 값으로
            // 계속 센다 — "이 앱이 실제로 팔고 있는 크기"가 여기서 나온다.
            // 최대값만으로는 "한 번 해 봤다"와 "늘 그렇게 쓴다"가 구분되지 않아 히스토그램도 남긴다.
            noteMax(.alertsMax, Double(alertCount))
            incrementAlertRun(alertCount)
            // ⚠️ 임계값은 **"알림 2개 이상"으로 고정된 정의다.** 게이트가 어떻게 바뀌든 따라가지
            //    말 것 — 정의가 바뀌면 과거 스냅샷과 합산되지 않아 지표가 조용히 끊긴다.
            if alertCount >= multiAlertThreshold { increment(.multiAlertRuns) }
        case .timerCompleted(let durationSeconds, let firedAlertCount):
            increment(.timerCompletions)
            // 알림을 실제로 들은 완주만 따로 센다 — 이게 "이 앱이 도움이 됐다"의 유일한 증거다.
            if firedAlertCount > 0 { increment(.alertedCompletions) }
            // 초가 아니라 분으로 누적한다 — 초로 쌓으면 Double 정밀도만 낭비되고 읽기도 어렵다.
            increment(.focusMinutes, by: Double(max(0, durationSeconds)) / 60)
        case .timerCancelled:
            increment(.timerCancels)
        case .presetSaved:
            increment(.presetSaves)
        case .presetUsed:
            increment(.presetUses)
        case .presentationModeStarted:
            increment(.presentationRuns)
        case .watchSyncUsed:
            increment(.watchSyncUses)
        case .paywallShown:
            increment(.paywallViews)
        default:
            break
        }
    }

    /// 현재 보유 템플릿 수를 갱신한다(누적이 아니라 덮어쓰기).
    static func setTemplateCount(_ count: Int) {
        store.set(Double(max(0, count)), forKey: Key.templates.storageKey)
    }

    private static let notificationsAuthorizedKey = "usage.flag.notificationsAuthorized"

    /// 알림 권한 상태 미러 — 스냅샷을 만드는 시점에는 권한 조회가 비동기라 물어볼 수 없어서,
    /// 앱이 활성화될 때마다 확인하는 값(AppStateManager)을 여기에 적어 둔다.
    static func setNotificationsAuthorized(_ isAuthorized: Bool) {
        store.set(isAuthorized, forKey: notificationsAuthorizedKey)
    }

    static var isNotificationsAuthorized: Bool {
        store.bool(forKey: notificationsAuthorizedKey)
    }

    static func value(_ key: Key) -> Double {
        store.double(forKey: key.storageKey)
    }

    /// 최고 기록 갱신 — 누적이 아니라 "가장 컸을 때"를 남긴다.
    private static func noteMax(_ key: Key, _ candidate: Double) {
        guard candidate > store.double(forKey: key.storageKey) else { return }
        store.set(candidate, forKey: key.storageKey)
    }

    private static func increment(_ key: Key, by amount: Double = 1) {
        store.set(store.double(forKey: key.storageKey) + amount, forKey: key.storageKey)
    }

    private static func incrementAlertRun(_ alertCount: Int) {
        let key = AlertRun.storageKey(AlertRun.bucket(for: alertCount))
        store.set(store.double(forKey: key) + 1, forKey: key)
    }

    /// 이 기기가 알림 개수별로 타이머를 몇 번 시작했나 (칸 번호 → 횟수).
    static func alertRunCount(bucket: Int) -> Double {
        store.double(forKey: AlertRun.storageKey(bucket))
    }

    // MARK: - 스냅샷용 묶음

    /// 스냅샷에 실어 보낼 지표 — 값이 0인 키는 빼서 전송량과 평균 계산을 깔끔하게 유지한다
    /// (통계 화면의 "설치당 평균"은 값을 가진 설치만 분모로 세므로, 0을 보내면 뜻이 달라진다).
    static func reportedMetrics() -> [String: Double] {
        var metrics: [String: Double] = [:]
        for key in Key.allCases {
            let value = value(key)
            guard value > 0 else { continue }
            metrics[key.rawValue] = (value * 10).rounded() / 10
        }
        // 알림 개수 히스토그램 — 0인 칸은 빼서 전송량을 줄인다(없는 칸 = 0회).
        for bucket in AlertRun.allBuckets {
            let runs = alertRunCount(bucket: bucket)
            guard runs > 0 else { continue }
            metrics[AlertRun.metricKey(bucket)] = runs.rounded()
        }
        return metrics
    }

    #if DEBUG
    /// 테스트·디버그 전용 초기화.
    static func resetAll() {
        for key in Key.allCases { store.removeObject(forKey: key.storageKey) }
        for bucket in AlertRun.allBuckets { store.removeObject(forKey: AlertRun.storageKey(bucket)) }
    }
    #endif
}
