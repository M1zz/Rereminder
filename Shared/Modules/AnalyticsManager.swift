//
//  AnalyticsManager.swift
//  Rereminder
//
//  로컬 이벤트 로깅 래퍼 (외부 분석 SDK 미사용).
//  Firebase Analytics 연동은 제거되었으며, 이벤트는 DEBUG 빌드에서만
//  콘솔에 출력되고 어떤 데이터도 외부로 전송되지 않는다.
//

import Foundation

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

    /// 앱 시작 시 1회 호출 (외부 분석 SDK 미사용 — no-op)
    static func configure() {}

    /// 이벤트 추적 (DEBUG 빌드에서만 콘솔 출력, 외부 전송 없음)
    static func log(_ event: Event) {
        #if DEBUG
        print("📊 [Analytics] \(event.name) \(event.parameters)")
        #endif
    }

    /// 사용자 속성 설정 (DEBUG 빌드에서만 콘솔 출력)
    static func setUserProperty(_ value: String?, forName name: String) {
        #if DEBUG
        print("📊 [Analytics] userProperty \(name)=\(value ?? "nil")")
        #endif
    }

    /// 화면 이름 추적 (DEBUG 빌드에서만 콘솔 출력)
    static func logScreen(_ name: String, screenClass: String? = nil) {
        #if DEBUG
        print("📊 [Analytics] screen_view \(name)")
        #endif
    }
}
