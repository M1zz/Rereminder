//
//  ActivityReporter.swift
//  Rereminder
//
//  앱 활동을 익명으로 iCloud(공용 FeedbackHub 컨테이너)에 모아 개발자가 볼 수 있게 한다.
//  실제 전송/조회 구현은 LeeoKit의 LeeoUsageReporter가 담당하고, 여기는 앱 전용 얇은 진입점.
//
//  수집 내용
//   • 설치 스냅샷(UsageSnapshot): 앱 버전·플랫폼·실행 횟수 등 (설치당 1건, 12시간에 1회 갱신)
//   • 이벤트 스트림(UsageEvent): timer_start / timer_complete / presentation_start
//
//  ⚠️ 개인 식별 정보(PII)는 보내지 않는다. 설치 식별은 기기/계정과 무관한 무작위 UUID.
//  조회는 설정 > Help > "Usage Stats (Developer)" (마스터 모드에서만 노출)에서 한다.
//

import Foundation
import LeeoKit

enum ActivityReporter {
    private static let reporter = LeeoUsageReporter(spec: RereminderSpec.self)

    /// 앱 시작 시 1회 — 실행 횟수 기록 + 설치 스냅샷 갱신(내부적으로 12시간에 1회만 실제 쓰기).
    @MainActor
    static func registerLaunch() {
        LeeoEngagement.shared.registerLaunch()
        reporter.reportInBackground(metrics: currentMetrics())
    }

    /// 의미 있는 행동 1건을 이벤트 스트림으로 남긴다(예: "timer_start", "timer_complete").
    static func log(_ event: String) {
        reporter.logEventInBackground(event)
    }

    /// 긍정 행동 누적 카운트(리뷰 게이트·스냅샷 지표에 반영) + 스냅샷 최신화.
    @MainActor
    static func recordSignificantEvent() {
        LeeoEngagement.shared.registerSignificantEvent()
        reporter.reportInBackground(metrics: currentMetrics())
    }

    /// 스냅샷에 함께 실어 보내는 앱별 대략 지표(스키마 필드를 늘리지 않는 JSON 한 필드).
    @MainActor
    private static func currentMetrics() -> [String: Double] {
        [
            "timerCompletions": Double(ReviewRequestManager.shared.getCurrentCompletionCount())
        ]
    }
}
