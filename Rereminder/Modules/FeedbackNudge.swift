//
//  FeedbackNudge.swift
//  Rereminder
//
//  가끔 "불편한 점 없으세요?"를 먼저 물어보는 의견 요청.
//
//  왜 필요한가: 통계는 **어디서 떨어지는지**까지만 말해 준다("완주율이 낮다"). 왜 그런지는
//  사람이 써 줘야 알 수 있는데, 설정 안에 숨은 피드백 버튼까지 스스로 찾아오는 사용자는 드물다.
//  그래서 앱이 먼저 묻는다 — 통계와 피드백이 한 쌍으로 굴러가는 지점이다.
//
//  정책 (클립키보드와 같은 모양)
//   • 10회째 실행에서 처음, 이후 40회 실행 간격
//   • "다시 보지 않기"는 **영구 중단이 아니라 6개월 유예** — 그 사이 앱이 달라졌을 수 있다
//   • 만족도 게이트(👍 리뷰 / 👎 피드백)가 뜰 차례면 양보한다 — 같은 실행에서 두 번 묻지 않는다
//
//  판정은 순수 함수(`shouldShow`)로 떼어 두고 저장소 접근과 분리한다 — 유닛 테스트 대상.
//

import Foundation
import LeeoKit

enum FeedbackNudge {

    /// 처음 물어보는 실행 횟수.
    static let firstLaunchThreshold = 10
    /// 그 다음부터의 실행 간격.
    static let launchInterval = 40
    /// "다시 보지 않기" 유예 기간.
    static let snoozeDuration: TimeInterval = 60 * 60 * 24 * 182   // 약 6개월

    private static let lastShownLaunchKey = "feedbackNudge.lastShownLaunch"
    private static let snoozedAtKey = "feedbackNudge.snoozedAt"

    // MARK: - 판정 (순수 함수)

    /// - Parameters:
    ///   - launchCount: 지금까지의 실행 횟수(LeeoEngagement 기준).
    ///   - lastShownLaunch: 마지막으로 물어봤던 실행 횟수. 한 번도 안 물었으면 0.
    ///   - snoozedAt: "다시 보지 않기"를 누른 시각. 없으면 nil.
    static func shouldShow(launchCount: Int,
                           lastShownLaunch: Int,
                           snoozedAt: Date?,
                           now: Date = Date()) -> Bool {
        if let snoozedAt, now.timeIntervalSince(snoozedAt) < snoozeDuration { return false }
        if lastShownLaunch == 0 { return launchCount >= firstLaunchThreshold }
        return launchCount - lastShownLaunch >= launchInterval
    }

    // MARK: - 저장소 연결

    /// 지금 물어볼 때인가. 만족도 게이트가 뜰 차례면 false(같은 실행에서 두 번 묻지 않는다).
    static func isDue(policy: LeeoReviewPolicy, now: Date = Date()) -> Bool {
        guard !isRunningTests else { return false }
        guard !LeeoReviewRequest.shouldRequest(policy: policy) else { return false }
        return shouldShow(launchCount: LeeoEngagement.shared.launchCount,
                          lastShownLaunch: UserDefaults.standard.integer(forKey: lastShownLaunchKey),
                          snoozedAt: UserDefaults.standard.object(forKey: snoozedAtKey) as? Date,
                          now: now)
    }

    /// 노출 시점에 기록한다 — 사용자가 무엇을 고르든 다음 간격까지는 다시 묻지 않는다.
    static func markShown() {
        UserDefaults.standard.set(LeeoEngagement.shared.launchCount, forKey: lastShownLaunchKey)
        AnalyticsManager.log(.feedbackNudgeShown)
    }

    /// "다시 보지 않기" — 영구 중단이 아니라 6개월 유예.
    static func snooze(now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: snoozedAtKey)
        AnalyticsManager.log(.feedbackNudgeSnoozed)
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    #if DEBUG
    /// 테스트·디버그 전용 — 다음 실행에서 바로 다시 뜨게 되돌린다.
    static func reset() {
        UserDefaults.standard.removeObject(forKey: lastShownLaunchKey)
        UserDefaults.standard.removeObject(forKey: snoozedAtKey)
    }
    #endif
}
