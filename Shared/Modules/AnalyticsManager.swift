//
//  AnalyticsManager.swift
//  Rereminder
//
//  이벤트 추상화 계층 + TelemetryDeck 전송.
//  Firebase Analytics 는 프라이버시/의존성 경량화를 위해 제거되었고(2026-07),
//  대신 익명·비추적 방식의 TelemetryDeck 으로 전송한다.
//  - telemetryDeckAppID 가 비어 있으면 어떤 데이터도 외부로 전송되지 않는다 (로컬 로깅만).
//  - 개인 식별 정보는 수집하지 않는다 (이벤트 이름 + 숫자/열거형 파라미터만).
//  - TelemetryDeck 은 메인 iOS 앱 타겟에만 링크된다 (Watch/위젯은 canImport 가드로 no-op).
//

import Foundation
#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

enum AnalyticsManager {

    /// TelemetryDeck 대시보드(dashboard.telemetrydeck.com)에서 발급한 App ID.
    /// 비어 있으면 외부 전송 없이 로컬(DEBUG 콘솔) 로깅만 수행한다.
    private static let telemetryDeckAppID = ""

    private static var isConfigured = false

    /// 익명 사용 허브(CloudKit) 전송 훅 — 메인 앱이 런치 시 꽂는다.
    /// Watch/위젯 타겟에서는 nil이라 콘솔 로깅만 수행된다.
    /// ⚠️ 이 파일은 Watch/위젯 타겟에도 포함된다 — 여기서 LeeoKit/CloudKit을 직접 참조하지 말 것.
    ///    전송 구현은 메인 앱의 ActivityReporter가 담당한다.
    static var eventSink: ((String) -> Void)?

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

        // 온보딩 퍼널
        case onboardingShown
        case onboardingCompleted
        case onboardingSkipped(page: Int)

        // 의견 요청(피드백 넛지) — 개발자가 "무엇이 문제인지"를 듣는 유일한 능동 경로
        case feedbackNudgeShown
        case feedbackNudgeAccepted
        case feedbackNudgeSnoozed

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
            case .reviewRequested:         return "review_requested"
            case .reviewCompleted:         return "review_completed"
            case .presentationModeStarted: return "presentation_mode_started"
            case .watchSyncUsed:           return "watch_sync_used"
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
            case .paywallShown(let trigger):               return "paywall_shown:\(trigger?.rawValue ?? "general")"
            case .paywallDismissed(let trigger, let didPurchase):
                return didPurchase ? "paywall_converted:\(trigger?.rawValue ?? "general")"
                                   : "paywall_dismissed:\(trigger?.rawValue ?? "general")"
            default:                       return name
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
            case .onboardingSkipped(let page):
                return ["page": page]
            case .purchaseRestored,
                 .onboardingShown, .onboardingCompleted,
                 .feedbackNudgeShown, .feedbackNudgeAccepted, .feedbackNudgeSnoozed,
                 .reviewRequested, .reviewCompleted,
                 .presentationModeStarted, .watchSyncUsed:
                return [:]
            }
        }

        /// TelemetryDeck 전송용 — 값을 문자열로 정규화
        var stringParameters: [String: String] {
            parameters.mapValues { String(describing: $0) }
        }
    }

    // MARK: - Public API

    /// 앱 시작 시 1회 호출. App ID 가 비어 있으면 외부 전송 없이 no-op.
    static func configure() {
        #if canImport(TelemetryDeck)
        guard !telemetryDeckAppID.isEmpty, !isConfigured else { return }
        TelemetryDeck.initialize(config: .init(appID: telemetryDeckAppID))
        isConfigured = true
        #endif
    }

    /// 이벤트 추적 — 익명 사용 허브(sink)와 TelemetryDeck(구성 시)으로 전송, DEBUG 에선 콘솔에도 출력
    static func log(_ event: Event) {
        // 허브 이벤트는 이름당 쓰로틀이 걸려 "몇 번 했는지"를 셀 수 없다 — 횟수는 기기에서 센다.
        UsageMetrics.apply(event)

        if let hubEvent = event.usageEventName {
            eventSink?(hubEvent)
        }
        #if canImport(TelemetryDeck)
        if isConfigured {
            TelemetryDeck.signal(event.name, parameters: event.stringParameters)
        }
        #endif
        #if DEBUG
        print("📊 [Analytics] \(event.name) \(event.parameters)")
        #endif
    }

    /// 사용자 속성 설정 — 별도 시그널로 전송 (TelemetryDeck 은 user property 개념이 없음)
    static func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(TelemetryDeck)
        if isConfigured {
            TelemetryDeck.signal("user_property_set", parameters: [name: value ?? ""])
        }
        #endif
        #if DEBUG
        print("📊 [Analytics] userProperty \(name)=\(value ?? "nil")")
        #endif
    }

    /// 화면 이름 추적
    static func logScreen(_ name: String, screenClass: String? = nil) {
        #if canImport(TelemetryDeck)
        if isConfigured {
            TelemetryDeck.signal("screen_view", parameters: ["screen_name": name])
        }
        #endif
        #if DEBUG
        print("📊 [Analytics] screen_view \(name)")
        #endif
    }
}
