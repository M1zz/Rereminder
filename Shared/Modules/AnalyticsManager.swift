//
//  AnalyticsManager.swift
//  Rereminder
//
//  Firebase Analytics 래퍼
//  iOS 타겟에서만 동작 (Watch/Widget 에서는 no-op)
//

import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsManager {

    // MARK: - Events

    enum Event {
        // 타이머 행동
        case timerStarted(durationSeconds: Int, presetName: String?)
        case timerCompleted(durationSeconds: Int)
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
            case .reviewRequested:         return "review_requested"
            case .reviewCompleted:         return "review_completed"
            case .presentationModeStarted: return "presentation_mode_started"
            case .watchSyncUsed:           return "watch_sync_used"
            }
        }

        var parameters: [String: Any] {
            switch self {
            case .timerStarted(let duration, let preset):
                var p: [String: Any] = ["duration_seconds": duration]
                if let preset = preset { p["preset_name"] = preset }
                return p
            case .timerCompleted(let duration):
                return ["duration_seconds": duration]
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
            case .purchaseRestored,
                 .reviewRequested, .reviewCompleted,
                 .presentationModeStarted, .watchSyncUsed:
                return [:]
            }
        }
    }

    // MARK: - Public API

    /// 앱 시작 시 1회 호출
    static func configure() {
        #if canImport(FirebaseAnalytics)
        // FirebaseApp.configure() 는 RereminderApp init 에서 호출됨
        #endif
    }

    /// 이벤트 추적
    static func log(_ event: Event) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.name, parameters: event.parameters)
        #endif

        #if DEBUG
        print("📊 [Analytics] \(event.name) \(event.parameters)")
        #endif
    }

    /// 사용자 속성 설정 (예: pro_user, trial_user)
    static func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }

    /// 화면 이름 추적 (자동 화면 추적 보완)
    static func logScreen(_ name: String, screenClass: String? = nil) {
        #if canImport(FirebaseAnalytics)
        var params: [String: Any] = [AnalyticsParameterScreenName: name]
        if let screenClass = screenClass {
            params[AnalyticsParameterScreenClass] = screenClass
        }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
        #endif
    }
}
