//
//  AnalyticsManager.swift
//  Rereminder
//
//  이벤트 추상화 계층 — 앱에서 벌어진 일을 한 가지 어휘로 모으는 곳.
//
//  외부 분석 SDK는 쓰지 않는다. Firebase 는 2026-07, TelemetryDeck 은 2026-08 에 걷어냈다
//  (App ID 가 비어 있어 실제로는 아무것도 보내지 않는 상태였고, 사용 통계는 CloudKit 허브가
//   이미 담당한다 — 외부 SDK 0개 원칙).
//
//  이 함수가 하는 일은 셋이다:
//   ① 로컬 카운터 갱신(UsageMetrics)  ② 익명 사용 허브로 이벤트 전달(eventSink)  ③ DEBUG 로깅
//  - 개인 식별 정보는 수집하지 않는다 (이벤트 이름 + 숫자/열거형 파라미터만).
//

import Foundation

enum AnalyticsManager {

    /// 익명 사용 허브(CloudKit) 전송 훅 — 메인 앱이 런치 시 꽂는다.
    /// Watch/위젯 타겟에서는 nil이라 콘솔 로깅만 수행된다.
    /// ⚠️ 이 파일은 Watch/위젯 타겟에도 포함된다 — 여기서 LeeoKit/CloudKit을 직접 참조하지 말 것.
    ///    전송 구현은 메인 앱의 ActivityReporter가 담당한다.
    static var eventSink: ((String) -> Void)?

    // MARK: - Events

    enum Event {
        // 타이머 행동
        case timerStarted(durationSeconds: Int, alertCount: Int, presetName: String?)
        /// - Parameter firedAlertCount: 그 실행에서 **실제로 울린 예비 알림 수**.
        ///   완주 횟수만으로는 "이 앱이 도움이 됐나"를 알 수 없다 — 알림이 한 번도 울리지 않은
        ///   완주는 평범한 타이머를 쓴 것과 같다. 이 앱의 aha 는 *울린 알림이 있는 완주*다.
        case timerCompleted(durationSeconds: Int, firedAlertCount: Int)
        case timerCancelled(remainingSeconds: Int)
        case presetSaved(name: String, durationSeconds: Int)
        case presetUsed(name: String)

        // 프리미엄 체험 카운터 (5+5 분할)
        case premiumFeatureUsed(feature: ProGate.Feature, trialCount: Int)
        case premiumTrialExhausted(feature: ProGate.Feature, stage: ProGate.PaywallStage)

        // 페이월
        case paywallShown(trigger: ProGate.Feature?)
        case paywallDismissed(trigger: ProGate.Feature?, didPurchase: Bool)
        case paywallOneMoreClicked(trigger: ProGate.Feature)
        case purchaseStarted(productId: String)
        case purchaseCompleted(productId: String)
        case purchaseFailed(productId: String, reason: String)
        case purchaseRestored

        // 온보딩 퍼널
        case onboardingShown
        case onboardingCompleted
        case onboardingSkipped(page: Int)

        // 의견 요청(피드백 넛지) — 개발자가 "무엇이 문제인지"를 듣는 유일한 능동 경로
        case feedbackNudgeShown
        case feedbackNudgeAccepted
        case feedbackNudgeSnoozed

        // 기기 보유 여부 (앱이 직접 물어본 답) — 워치·맥 안내를 누구에게 할지 가르는 값
        case deviceOwnershipAnswered(device: String, owns: Bool)

        /// "다음 자리"를 예약했다 — 주기가 긴 사용자(학회 발표자·분기 워크숍)를 앱이 다시 부르는 경로.
        /// 이 예약이 실제로 복귀로 이어지는지가 그 설계의 판정 기준이다.
        case nextOccasionBooked

        /// 창단 후원자에게 혜택 변경 안내를 보여줬다.
        /// 이 사람들이 그 뒤로도 남아 있는지가 "약속이 통했나"의 유일한 근거다.
        case founderWelcomeShown

        // 기타
        case reviewRequested
        case reviewCompleted
        case presentationModeStarted
        case watchSyncUsed

        var name: String {
            switch self {
            case .timerStarted:            return "timer_started"
            case .timerCompleted:          return "timer_completed"
            case .timerCancelled:          return "timer_cancelled"
            case .presetSaved:             return "preset_saved"
            case .presetUsed:              return "preset_used"
            case .premiumFeatureUsed:      return "premium_feature_used"
            case .premiumTrialExhausted:   return "premium_trial_exhausted"
            case .paywallShown:            return "paywall_shown"
            case .paywallDismissed:        return "paywall_dismissed"
            case .paywallOneMoreClicked:   return "paywall_one_more_clicked"
            case .purchaseStarted:         return "purchase_started"
            case .purchaseCompleted:       return "purchase_completed"
            case .purchaseFailed:          return "purchase_failed"
            case .purchaseRestored:        return "purchase_restored"
            case .onboardingShown:         return "onboarding_shown"
            case .onboardingCompleted:     return "onboarding_completed"
            case .onboardingSkipped:       return "onboarding_skipped"
            case .feedbackNudgeShown:      return "feedback_nudge_shown"
            case .feedbackNudgeAccepted:   return "feedback_nudge_accepted"
            case .feedbackNudgeSnoozed:    return "feedback_nudge_snoozed"
            case .nextOccasionBooked:      return "next_occasion_booked"
            case .founderWelcomeShown:     return "founder_welcome_shown"
            case .reviewRequested:         return "review_requested"
            case .reviewCompleted:         return "review_completed"
            case .presentationModeStarted: return "presentation_mode_started"
            case .watchSyncUsed:           return "watch_sync_used"
            case .deviceOwnershipAnswered: return "device_ownership_answered"
            }
        }

        /// 익명 사용 허브(UsageEvent)로 보낼 이벤트 문자열. nil이면 허브로 보내지 않는다.
        /// 기존 시리즈(timer_start/timer_complete/presentation_start)는 ViewModel이 ActivityReporter로
        /// 직접 보내던 역사가 있어 여기서 다시 보내면 중복·의미 변형이 생긴다 — 그쪽 경로를 유지하고 제외.
        /// 구분값이 유의미한 이벤트는 "이름:슬라이스" 한 조각만 붙인다(값·PII는 보내지 않는다).
        var usageEventName: String? {
            switch self {
            case .timerStarted, .timerCompleted, .presentationModeStarted:
                return nil
            case .premiumFeatureUsed(let feature, _):      return "premium_feature_used:\(feature.rawValue)"
            case .premiumTrialExhausted(let feature, _):   return "premium_trial_exhausted:\(feature.rawValue)"
            case .deviceOwnershipAnswered(let device, let owns):
                return "device_ownership:\(device)_\(owns ? "yes" : "no")"
            case .paywallShown(let trigger):               return "paywall_shown:\(trigger?.rawValue ?? "general")"
            case .paywallDismissed(let trigger, let didPurchase):
                return didPurchase ? "paywall_converted:\(trigger?.rawValue ?? "general")"
                                   : "paywall_dismissed:\(trigger?.rawValue ?? "general")"
            default:                       return name
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .timerStarted(let duration, let alertCount, let preset):
                var p: [String: Any] = ["duration_seconds": duration, "alert_count": alertCount]
                if let preset = preset { p["preset_name"] = preset }
                return p
            case .timerCompleted(let duration, let firedAlerts):
                return ["duration_seconds": duration, "fired_alert_count": firedAlerts]
            case .timerCancelled(let remaining):
                return ["remaining_seconds": remaining]
            case .presetSaved(let name, let duration):
                return ["preset_name": name, "duration_seconds": duration]
            case .presetUsed(let name):
                return ["preset_name": name]
            case .premiumFeatureUsed(let feature, let trialCount):
                return ["feature": feature.rawValue, "trial_count": trialCount]
            case .premiumTrialExhausted(let feature, let stage):
                return ["feature": feature.rawValue, "stage": stage.rawValue]
            case .paywallShown(let trigger):
                return ["trigger": trigger?.rawValue ?? "general"]
            case .paywallDismissed(let trigger, let didPurchase):
                return ["trigger": trigger?.rawValue ?? "general", "did_purchase": didPurchase]
            case .paywallOneMoreClicked(let trigger):
                return ["trigger": trigger.rawValue]
            case .purchaseStarted(let id), .purchaseCompleted(let id):
                return ["product_id": id]
            case .purchaseFailed(let id, let reason):
                return ["product_id": id, "reason": reason]
            case .onboardingSkipped(let page):
                return ["page": page]
            case .deviceOwnershipAnswered(let device, let owns):
                return ["device": device, "owns": owns]
            case .purchaseRestored,
                 .onboardingShown, .onboardingCompleted,
                 .feedbackNudgeShown, .feedbackNudgeAccepted, .feedbackNudgeSnoozed,
                 .reviewRequested, .reviewCompleted,
                 .presentationModeStarted, .watchSyncUsed,
                 .founderWelcomeShown, .nextOccasionBooked:
                return [:]
            }
        }
    }

    // MARK: - Public API

    /// 이벤트 추적 — 로컬 카운터 갱신 + 익명 사용 허브로 전달, DEBUG 에선 콘솔에도 출력
    static func log(_ event: Event) {
        // 허브 이벤트는 이름당 쓰로틀이 걸려 "몇 번 했는지"를 셀 수 없다 — 횟수는 기기에서 센다.
        UsageMetrics.apply(event)

        if let hubEvent = event.usageEventName {
            eventSink?(hubEvent)
        }
        #if DEBUG
        print("📊 [Analytics] \(event.name) \(event.parameters)")
        #endif
    }
}
