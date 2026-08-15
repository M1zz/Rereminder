//
//  LiveActivityController.swift
//  Rereminder
//
//  다이나믹 아일랜드/잠금화면 Live Activity 의 수명을 한 곳에서 관리한다.
//
//  왜 따로 두나 — 예전에는 뷰모델이 `Activity` 참조를 **메모리에만** 들고 있었다. 그래서:
//   • 앱이 종료되면 그 참조가 사라져 **활동을 영영 끝낼 수 없었다**(사용자가 없애고 싶어도 남아 있음)
//   • 복원할 때 살아 있는 활동을 채택하지 않고 새로 요청해 **활동이 하나 더 생겼다**(중복)
//   • 새 타이머를 시작해도 이전 활동을 끝내지 않았다
//
//  해법은 하나다: 참조를 들고 다니지 말고 **시스템 목록(`Activity.activities`)을 진실로 삼는다.**
//  그 목록은 프로세스가 새로 떠도 그대로 있으므로, 앱이 죽었다 살아나도 같은 활동을 찾아 끝낼 수 있다.
//
//  ⚠️ 위젯 확장에서도 쓴다(다이나믹 아일랜드 버튼이 앱 프로세스에서 도는 인텐트라 같은 코드를 탄다).
//

import Foundation

#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit

enum LiveActivityController {

    /// 이 앱이 띄운 타이머 활동들 — 프로세스가 바뀌어도 시스템이 갖고 있다.
    static var running: [Activity<TimerActivityAttributes>] {
        Activity<TimerActivityAttributes>.activities
    }

    /// 지금 살아 있는 활동 (여러 개면 가장 최근 것).
    static var current: Activity<TimerActivityAttributes>? {
        running.last
    }

    // MARK: - 시작

    /// 타이머 활동을 새로 띄운다. **먼저 남아 있는 활동을 전부 정리한다** — 그러지 않으면
    /// 다이나믹 아일랜드에 이전 타이머가 함께 남아 어느 것이 지금 것인지 알 수 없다.
    @discardableResult
    static func start(name: String, duration: TimeInterval, endDate: Date) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        endAll()

        let attributes = TimerActivityAttributes(
            timerName: name,
            totalDuration: duration,
            startTime: endDate.addingTimeInterval(-duration)
        )
        let state = TimerActivityAttributes.ContentState(
            remainingTime: max(0, endDate.timeIntervalSinceNow),
            isPaused: false,
            timestamp: Date(),
            endDate: endDate
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate)
            )
            return true
        } catch {
            print("❌ [LiveActivity] 시작 실패: \(error)")
            return false
        }
    }

    /// 이미 살아 있는 활동이 있으면 그것을 쓰고(true), 없으면 새로 띄운다.
    /// 앱을 껐다 켠 뒤 복원할 때 쓴다 — 여기서 무조건 start 하면 활동이 두 개가 된다.
    @discardableResult
    static func adoptOrStart(name: String, duration: TimeInterval, endDate: Date) -> Bool {
        if current != nil {
            update(remaining: max(0, endDate.timeIntervalSinceNow), isPaused: false, endDate: endDate)
            return true
        }
        return start(name: name, duration: duration, endDate: endDate)
    }

    // MARK: - 갱신 / 종료

    static func update(remaining: TimeInterval, isPaused: Bool, endDate: Date?) {
        let state = TimerActivityAttributes.ContentState(
            remainingTime: remaining,
            isPaused: isPaused,
            timestamp: Date(),
            endDate: endDate
        )
        // 멈춰 있으면 낡을 일이 없고, 흐르는 중이면 끝나는 시각이 곧 신선도 마감이다
        let staleDate = isPaused ? nil : endDate
        for activity in running {
            Task { await activity.update(.init(state: state, staleDate: staleDate)) }
        }
    }

    /// 앱이 실제로 멈추기 전에 표시부터 "일시정지"로 바꾼다.
    /// 버튼을 눌렀는데 아무 변화가 없으면 사용자는 고장으로 읽는다 — 앱이 깨어나면 진짜 상태로 덮인다.
    static func markPaused() {
        guard let activity = current else { return }
        let state = TimerActivityAttributes.ContentState(
            remainingTime: activity.content.state.remainingTime,
            isPaused: true,
            timestamp: Date(),
            endDate: nil
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    /// 남아 있는 활동을 **전부** 즉시 없앤다. 앱이 죽었다 살아난 뒤에도 동작한다.
    static func endAll() {
        for activity in running {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// 앱이 뜰 때 호출 — 타이머가 돌고 있지 않은데 활동만 남아 있는 경우를 치운다.
    /// (앱이 강제 종료되면 활동은 시스템에 그대로 남아 최대 몇 시간을 버틴다)
    static func endOrphans(isTimerActive: Bool) {
        guard !isTimerActive, !running.isEmpty else { return }
        print("🧹 [LiveActivity] 타이머가 없는데 남아 있던 활동 \(running.count)개 정리")
        endAll()
    }
}
#endif
