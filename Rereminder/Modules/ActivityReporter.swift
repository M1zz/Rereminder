//
//  ActivityReporter.swift
//  Rereminder
//
//  앱 활동을 익명으로 iCloud(공용 FeedbackHub 컨테이너)에 모아 개발자가 볼 수 있게 한다.
//  전송/조회 엔진은 LeeoKit(LeeoUsageReporter)이고, 여기서는 **이 앱의 수집 정책과 집계**만 정한다.
//
//  보내는 것
//   ① UsageSnapshot — 설치당 1건 upsert(익명 UUID recordName). 사용자 수·활성 사용자 집계용.
//      앱 버전·플랫폼·OS·로케일·실행 횟수·설치 후 경과일 + 로컬 카운터(UsageMetrics)의 metrics JSON.
//   ② UsageEvent — 주요 행동 스트림(이름 + 발생 시각 + 익명 설치 ID). **이름당 6시간 쓰로틀**.
//
//  ⚠️ 개인 식별 정보(PII)는 보내지 않는다. 설치 식별은 기기/계정과 무관한 무작위 UUID뿐이고
//     재설치하면 새 값이 된다. 타이머 이름·알림 메시지 같은 내용은 어떤 경로로도 나가지 않는다.
//  ⚠️ 사용자 옵트아웃은 없다. 대신 원격 킬스위치(usageReportingEnabled)로 즉시 중단할 수 있다.
//  조회는 설정 > Help > "Usage Stats (Developer)"(마스터 모드 전용) — 화면은 UsageStatsView.
//  스키마·권한 절차: docs/USAGE_STATS_HUB.md
//

import Foundation
import CloudKit
import LeeoKit

enum ActivityReporter {
    private static var reporter: LeeoUsageReporter { LeeoUsageReporter(spec: RereminderSpec.self) }

    /// 같은 이벤트 이름을 다시 보내기까지의 최소 간격 — 공개 DB 쓰기 폭주 방지.
    /// 그래서 이벤트 **건수**는 실제보다 작다. 건수 대신 "설치 몇 곳이 하는지"를 보는 지표다.
    private static let eventThrottle: TimeInterval = 6 * 3600

    /// "이 설치가 오늘 앱을 열었다"를 남기는 이벤트 — 일간 활성·리텐션 코호트의 근거.
    /// 스냅샷의 lastActiveAt은 덮어쓰기라 날짜별 이력이 남지 않아, 하루 1건 이벤트로 대신한다.
    static let appOpenEvent = "app_open"

    /// 유닛 테스트 중에는 허브에 쓰지 않는다(쓰로틀 로직 자체는 그대로 돈다).
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// 원격 킬스위치 — 끄면 스냅샷·이벤트 수집이 즉시 중단된다. 조회 실패 = 켬(가용성 우선).
    private static var isReportingEnabled: Bool {
        LeeoRemoteFlags.isEnabled(RereminderFlag.usageReportingEnabled)
    }

    // MARK: - 전송

    /// **프로세스가 뜰 때** 1회 — 설치 스냅샷 갱신(12시간 쓰로틀은 LeeoKit이 담당).
    ///
    /// ⚠️ 여기에 "사람이 앱을 열었다"는 신호를 두지 말 것. 위젯·알림 처리로 프로세스만
    ///    깨어난 경우에도 이 경로는 돈다 — 실행 횟수와 app_open은 화면이 실제로 뜨는
    ///    `reportForegroundOpen()`이 맡는다.
    static func reportProcessStart() {
        guard !isRunningTests, isReportingEnabled else { return }
        Task(priority: .utility) { @MainActor in
            reporter.reportInBackground(metrics: currentMetrics())
        }
    }

    /// 사람이 앱을 실제로 앞으로 가져온 순간 — 콜드 런치와 백그라운드 복귀 양쪽에서 불린다.
    @MainActor
    static func reportForegroundOpen() {
        // 실행 횟수는 프로세스당 1회만 — 복귀할 때마다 세면 만족도 게이트가 앞당겨진다.
        if !didRegisterLaunch {
            didRegisterLaunch = true
            LeeoEngagement.shared.registerLaunch()
        }
        // 하루 1건 — 며칠씩 살아 있는 프로세스에서도 날짜를 놓치지 않게 복귀마다 확인한다.
        log(appOpenEvent, minInterval: 20 * 3600)
    }

    private static var didRegisterLaunch = false

    /// 의미 있는 행동 1건을 이벤트 스트림으로 남긴다(예: "timer_start", "timer_complete").
    /// - Parameter minInterval: 같은 이름을 다시 보내기까지의 최소 간격(기본 6시간).
    static func log(_ event: String, minInterval: TimeInterval = eventThrottle) {
        let key = "usage.event.lastSentAt.\(event)"
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           Date().timeIntervalSince(last) < minInterval { return }
        UserDefaults.standard.set(Date(), forKey: key)

        guard !isRunningTests, isReportingEnabled else { return }
        reporter.logEventInBackground(String(event.prefix(60)))
    }

    /// 긍정 행동 누적 카운트(리뷰 게이트·스냅샷 지표에 반영) + 스냅샷 최신화.
    @MainActor
    static func recordSignificantEvent() {
        LeeoEngagement.shared.registerSignificantEvent()
        guard !isRunningTests, isReportingEnabled else { return }
        reporter.reportInBackground(metrics: currentMetrics())
    }

    /// 스냅샷에 함께 실어 보내는 이 설치의 대략 지표(스키마 필드를 늘리지 않는 JSON 한 필드).
    /// 개수·분 단위 수치와 0/1 플래그만 담는다 — 내용·식별자는 없다.
    @MainActor
    private static func currentMetrics() -> [String: Double] {
        var metrics = UsageMetrics.reportedMetrics()

        // 리뷰 게이트가 세는 완주 횟수 — UsageMetrics 도입 이전 설치의 값도 살아 있다.
        let completions = ReviewRequestManager.shared.getCurrentCompletionCount()
        if completions > 0 {
            metrics["timerCompletions"] = max(metrics["timerCompletions"] ?? 0, Double(completions))
        }

        // 0/1 플래그 — "몇 %가 이걸 쓰는가"를 보려는 값들이라 0도 함께 보낸다(분모가 필요하다).
        metrics["flag.isPro"] = StoreManager.isProUser ? 1 : 0
        metrics["flag.notificationsOn"] = UsageMetrics.isNotificationsAuthorized ? 1 : 0
        metrics["flag.presentationUser"] = UsageMetrics.value(.presentationRuns) > 0 ? 1 : 0
        metrics["flag.templateUser"] = UsageMetrics.value(.presetUses) > 0 ? 1 : 0
        metrics["flag.watchUser"] = UsageMetrics.value(.watchSyncUses) > 0 ? 1 : 0

        // 결제 경계(알림 개수)와의 거리 — 이벤트로는 "지금 몇 명이 결제 직전인가"를 셀 수 없다.
        // 이벤트에는 6시간 쓰로틀이 걸려 있고 과거형이지만, 스냅샷은 설치당 1건 upsert라 **현재 상태**다.
        // 남은 체험 횟수는 여기서 계산하지 않는다(한도 상수는 바뀔 수 있다) — 원자료만 보내고
        // 해석은 UsageInsights가 한다.
        metrics["trial.prealerts"] = Double(TrialCounter.count(for: .unlimitedPrealerts))
        metrics["flag.prealertTrialExtended"] = TrialCounter.extensionAccepted(for: .unlimitedPrealerts) ? 1 : 0

        // 워치·맥 보유 여부 — 앱이 직접 물어본 답이라 "아직 안 물어봄"과 "없음"이 다르다.
        // 그래서 답을 들은 설치만 보낸다(모르는 사람을 '없음'으로 세면 워치 앱의 값이 과소평가된다).
        for device in DeviceOwnership.Device.allCases {
            switch DeviceOwnership.answer(for: device) {
            case .yes:     metrics["flag.owns\(device.rawValue.capitalized)"] = 1
            case .no:      metrics["flag.owns\(device.rawValue.capitalized)"] = 0
            case .unknown: break
            }
        }
        return metrics
    }

    // MARK: - 조회 (개발자 통계 화면용)

    typealias Snapshot = LeeoUsageReporter.UsageSnapshot

    /// 설치 스냅샷 전체 (이 앱 것만, 최근 활동순).
    static func fetchSnapshots(limit: Int = 1000) async throws -> [Snapshot] {
        try await reporter.fetchSnapshots(limit: limit)
    }

    /// 이벤트 1건 (집계·차트용 원본 표본).
    struct EventSample: Sendable {
        let name: String
        let installID: String?
        let date: Date
    }

    /// 이벤트 이름별 집계 결과.
    struct EventStat: Identifiable, Sendable {
        let name: String
        /// 조회 범위 안에서 기록된 건수.
        let count: Int
        /// 그 이벤트를 남긴 서로 다른 설치 수.
        let installs: Int
        let lastAt: Date?
        var id: String { name }
    }

    /// 최근 이벤트를 원본 표본 그대로 읽는다 — 이름별 집계·퍼널·차트가 이 하나를 함께 쓴다.
    /// LeeoKit은 스냅샷 조회만 제공해서 이벤트 스트림은 여기서 직접 읽는다.
    /// ⚠️ 남의 레코드를 읽으므로 컨테이너 read 권한이 필요하다(피드백 인박스와 동일).
    static func fetchEvents(limit: Int = 3000) async throws -> [EventSample] {
        let config = RereminderSpec.feedback
        let database = CKContainer(identifier: config.containerIdentifier).publicCloudDatabase

        // 허브 전체를 읽고 appId는 클라이언트에서 거른다 — appId Queryable 인덱스 없이 동작하게.
        let query = CKQuery(recordType: LeeoUsageReporter.eventType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        var samples: [EventSample] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await database.records(continuingMatchFrom: cursor,
                                                  resultsLimit: min(200, limit - samples.count))
            } else {
                page = try await database.records(matching: query, resultsLimit: min(200, limit))
            }

            for record in page.matchResults.compactMap({ try? $0.1.get() }) {
                guard config.appIdentifier == nil || (record["appId"] as? String) == config.appIdentifier else { continue }
                // creationDate는 서버가 "쓴 시각"으로 찍는다 — 실제 발생 시각을 우선 본다.
                // 구버전(LeeoKit 2.7 이하)이 남긴 레코드엔 이 필드가 없어 creationDate로 떨어진다.
                let occurredAt = (record["occurredAt"] as? Date) ?? record.creationDate ?? Date()
                samples.append(EventSample(name: (record["event"] as? String) ?? "-",
                                           installID: record["installID"] as? String,
                                           date: occurredAt))
            }
            cursor = page.queryCursor
        } while cursor != nil && samples.count < limit

        return samples
    }

    /// 표본 → 이름별 집계 (화면 계산용, 네트워크 없음).
    static func eventStats(from samples: [EventSample]) -> [EventStat] {
        var counts: [String: (count: Int, installs: Set<String>, lastAt: Date?)] = [:]
        for sample in samples {
            var entry = counts[sample.name] ?? (0, [], nil)
            entry.count += 1
            if let install = sample.installID { entry.installs.insert(install) }
            if (entry.lastAt ?? .distantPast) < sample.date { entry.lastAt = sample.date }
            counts[sample.name] = entry
        }
        return counts
            .map { EventStat(name: $0.key, count: $0.value.count, installs: $0.value.installs.count, lastAt: $0.value.lastAt) }
            .sorted { $0.count > $1.count }
    }

    /// 허브에 접수된 이 앱의 피드백 (최신순). 통계 화면 요약용.
    static func fetchFeedback(limit: Int = 100) async throws -> [LeeoFeedbackService.FeedbackRecord] {
        try await LeeoFeedbackService(spec: RereminderSpec.self).fetchAll(limit: limit)
    }

    // MARK: - 기간별 추이 (일·주·월·연)

    /// 차트 묶음 단위.
    enum BucketUnit: String, CaseIterable, Identifiable {
        case day, week, month, year
        var id: String { rawValue }

        var calendarComponent: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            case .year: return .year
            }
        }

        /// 한 화면에 보이는 묶음 개수 — 나머지는 좌우로 스크롤해서 본다.
        var visibleBuckets: Int {
            switch self {
            case .day: return 14
            case .week: return 12
            case .month: return 12
            case .year: return 5
            }
        }

        var label: String {
            switch self {
            case .day: return "일간"
            case .week: return "주간"
            case .month: return "월간"
            case .year: return "연간"
            }
        }
    }

    /// 한 묶음(하루/한 주/한 달/한 해)의 집계값.
    struct TrendPoint: Identifiable, Sendable {
        /// 묶음의 시작 시각 (차트 X축 값).
        let date: Date
        /// 그 기간에 기록된 이벤트 건수.
        let events: Int
        /// 그 기간에 활동한 서로 다른 설치 수.
        let activeInstalls: Int
        /// 그 기간에 처음 설치된 수.
        let newInstalls: Int
        var id: Date { date }
    }

    /// 빈 구간까지 채운 연속 추이를 만든다 — 차트가 끊기지 않도록.
    /// 데이터가 없으면 빈 배열. 안전장치로 최대 400묶음까지만 만든다.
    static func trend(unit: BucketUnit,
                      events: [EventSample],
                      snapshots: [Snapshot],
                      calendar: Calendar = .current,
                      now: Date = Date()) -> [TrendPoint] {
        trend(unit: unit,
              events: events,
              installDates: snapshots.compactMap(\.installDate),
              calendar: calendar,
              now: now)
    }

    /// ⚠️ `Snapshot`은 CKRecord 전용 생성자뿐이라 그대로 받으면 유닛 테스트를 못 한다 —
    ///    실제로 필요한 값(설치일)만 받는 이쪽이 본체다.
    static func trend(unit: BucketUnit,
                      events: [EventSample],
                      installDates: [Date],
                      calendar: Calendar = .current,
                      now: Date = Date()) -> [TrendPoint] {
        func bucketStart(_ date: Date) -> Date? {
            calendar.dateInterval(of: unit.calendarComponent, for: date)?.start
        }

        var eventCounts: [Date: Int] = [:]
        var installsByBucket: [Date: Set<String>] = [:]
        for sample in events {
            guard let start = bucketStart(sample.date) else { continue }
            eventCounts[start, default: 0] += 1
            if let install = sample.installID {
                installsByBucket[start, default: []].insert(install)
            }
        }

        var newInstalls: [Date: Int] = [:]
        for installDate in installDates {
            guard let start = bucketStart(installDate) else { continue }
            newInstalls[start, default: 0] += 1
        }

        let starts = Set(eventCounts.keys).union(installsByBucket.keys).union(newInstalls.keys)
        guard let first = starts.min(), let today = bucketStart(now) else { return [] }
        let last = max(starts.max() ?? today, today)

        var points: [TrendPoint] = []
        var cursor = first
        while cursor <= last && points.count < 400 {
            points.append(TrendPoint(date: cursor,
                                     events: eventCounts[cursor] ?? 0,
                                     activeInstalls: installsByBucket[cursor]?.count ?? 0,
                                     newInstalls: newInstalls[cursor] ?? 0))
            guard let next = calendar.date(byAdding: unit.calendarComponent, value: 1, to: cursor) else { break }
            cursor = next
        }
        return points
    }
}
