//
//  ProGate.swift
//  Rereminder
//
//  무료/Pro 기능 제한 게이트 (5+5 trial 모델)
//
//  잠금 원칙:
//  - 무료: 타이머, 예비알림 1개, Live Activity, 소리/진동, Watch, 위젯, 커스텀 메시지, 테마/라벨 색상
//  - Pro: 예비알림 무제한, 발표 모드, 오버타임 추적, 템플릿 무제한, 통계
//
//  5+5 trial:
//  - presentationMode, unlimitedPrealerts, overtimeTracking, timerHistory 에 적용
//  - unlimitedTemplates 는 슬롯 개념이라 hard gate 유지 (3개 free)
//

import Foundation

enum ProGate {

    // MARK: - Pro 기능 정의

    enum Feature: String, CaseIterable {
        case unlimitedPrealerts       // 예비 알림 2개 이상
        case presentationMode         // 발표 모드
        case overtimeTracking         // 오버타임 카운트
        case unlimitedTemplates       // 템플릿 4개 이상 저장
        case timerHistory             // 타이머 사용 통계

        var displayName: String {
            switch self {
            case .unlimitedPrealerts:     return "Unlimited Pre-alerts"
            case .presentationMode:       return "Presentation Mode"
            case .overtimeTracking:       return "Overtime Tracking"
            case .unlimitedTemplates:     return "Unlimited Templates"
            case .timerHistory:           return "Timer History & Stats"
            }
        }

        var icon: String {
            switch self {
            case .unlimitedPrealerts:     return "bell.badge.fill"
            case .presentationMode:       return "person.and.background.dotted"
            case .overtimeTracking:       return "timer.circle.fill"
            case .unlimitedTemplates:     return "square.stack.3d.up.fill"
            case .timerHistory:           return "chart.bar.fill"
            }
        }

        /// 5+5 trial 적용 대상인지 (slot 기반 templates 는 제외)
        var supportsTrial: Bool {
            switch self {
            case .unlimitedTemplates: return false
            default: return true
            }
        }
    }

    // MARK: - Free Limits

    /// 무료로 켤 수 있는 예비 알림 수.
    ///
    /// ⚠️ **1 → 2 로 올렸다.** 이 앱이 파는 문장은 "끝나기 전에 **여러 번** 알려 준다"인데,
    ///    무료 1개는 그 문장이 성립하지 않는 상태다(그냥 'N분 전 알림 하나' = 기본 타이머로도 되는 것).
    ///    가치를 경험하기 전에 벽을 만나면 결제가 아니라 이탈이 된다. 2개면 "한 번 더"가 성립하고,
    ///    3개째부터 받으면 그건 실제로 **구간을 설계하는 사람**(발표자·트레이너)이다.
    ///    ⚠️ 올리기 전에 통계 > "주로 쓰는 알림 개수"에서 **결제** 표본만 켜고 확인할 것 —
    ///       결제한 사람이 주로 쓰는 개수가 이 값보다 넉넉히 커야 팔 것이 남는다.
    static let freePrealertLimit = 2
    static let freeTemplateLimit = 3

    // MARK: - Gate Result

    enum PaywallStage: String {
        case first   // 5회 후 1차 페이월
        case second  // 10회 후 2차 페이월
    }

    enum GateResult {
        case allowed                                                    // Pro 사용자
        case allowedWithTrial(remaining: Int, stage: PaywallStage)      // 무료, 체험 가능
        case blocked(stage: PaywallStage)                               // 페이월 표시 필요

        var isAllowed: Bool {
            switch self {
            case .allowed, .allowedWithTrial: return true
            case .blocked: return false
            }
        }

        var trialRemaining: Int? {
            if case .allowedWithTrial(let r, _) = self { return r }
            return nil
        }
    }

    // MARK: - Evaluate (5+5 logic)

    static func evaluate(_ feature: Feature) -> GateResult {
        if StoreManager.isProUser { return .allowed }

        // Trial 미지원 기능은 무조건 blocked
        guard feature.supportsTrial else {
            return .blocked(stage: .first)
        }

        let used = TrialCounter.count(for: feature)
        let firstLimit = TrialCounter.firstStageLimit
        let secondLimit = TrialCounter.secondStageLimit
        let extended = TrialCounter.extensionAccepted(for: feature)

        if used < firstLimit {
            return .allowedWithTrial(remaining: firstLimit - used, stage: .first)
        }
        if used < secondLimit && extended {
            return .allowedWithTrial(remaining: secondLimit - used, stage: .second)
        }
        if used < secondLimit && !extended {
            return .blocked(stage: .first)
        }
        return .blocked(stage: .second)
    }

    // MARK: - 알림 추가 게이트
    //
    // "1번째 알림은 free, 2번째부터 체험 평가" 정책이 알림을 켤 수 있는 화면마다 복사돼 있었다.
    // 한쪽만 고치면 같은 앱 안에서 규칙이 갈라지므로 여기 한 곳에 둔다.

    enum PrealertAdmission: Equatable {
        case allowed
        /// 체험은 소진됐지만 **오늘치 유예가 남아 있다** — 페이월 대신 이번 한 번을 내준다.
        ///
        /// 왜: 한도에 막힌 순간은 사용자가 이 앱의 가치를 **가장 강하게 원하는 순간**이다.
        /// 그 자리에서 문을 닫으면 결제가 아니라 이탈이 된다("이 앱은 안 되는 앱"). 한 번 내주면
        /// 원하던 것을 손에 넣은 채로 "다음부터는 Pro"라는 문장을 듣게 되고, 그게 훨씬 잘 팔린다.
        /// 하루 한 번으로 묶어 두어 게이트 자체가 무의미해지지는 않는다.
        case grace(stage: PaywallStage)
        case blocked(stage: PaywallStage)
    }

    /// 지금 알림을 하나 더 켤 수 있는지 — **부작용 없는 판정**.
    /// 자물쇠 아이콘처럼 그릴 때마다 물어보는 곳에서도 안전하게 쓸 수 있다.
    static func prealertAdmission(currentCount: Int) -> PrealertAdmission {
        guard currentCount >= freePrealertLimit else { return .allowed }
        switch evaluate(.unlimitedPrealerts) {
        case .allowed, .allowedWithTrial:
            return .allowed
        case .blocked(let stage):
            return PrealertGrace.isAvailable ? .grace(stage: stage) : .blocked(stage: stage)
        }
    }

    /// 사용자가 실제로 알림을 켜려 할 때 — 판정은 같고 막혔을 때 이벤트를 남긴다.
    /// ⚠️ 화면을 그리는 경로에서 부르지 말 것(그릴 때마다 이벤트가 쌓인다). 그 용도는 위 함수다.
    static func requestPrealert(currentCount: Int) -> PrealertAdmission {
        let admission = prealertAdmission(currentCount: currentCount)
        switch admission {
        case .allowed:
            break
        case .grace(let stage):
            // 유예도 "한도를 몸으로 겪은" 순간이다 — 소진 이벤트는 그대로 남긴다.
            AnalyticsManager.log(.premiumTrialExhausted(feature: .unlimitedPrealerts, stage: stage))
            PrealertGrace.consume()
            AnalyticsManager.log(.prealertGraceGranted(stage: stage))
        case .blocked(let stage):
            AnalyticsManager.log(.premiumTrialExhausted(feature: .unlimitedPrealerts, stage: stage))
        }
        return admission
    }

    /// 사용자가 기능을 실제로 사용했을 때 호출 (Pro면 no-op)
    static func recordUsage(_ feature: Feature) {
        guard !StoreManager.isProUser else { return }
        guard feature.supportsTrial else { return }
        TrialCounter.increment(feature)
        AnalyticsManager.log(.premiumFeatureUsed(
            feature: feature,
            trialCount: TrialCounter.count(for: feature)
        ))
    }

    /// 1차 페이월에서 "5번 더 체험" 수락
    static func acceptExtendedTrial(_ feature: Feature) {
        guard feature.supportsTrial else { return }
        TrialCounter.acceptExtension(for: feature)
    }

    // MARK: - Legacy Bool API (호환성 유지)

    static func isAvailable(_ feature: Feature) -> Bool {
        evaluate(feature).isAllowed
    }

    /// 예비 알림 추가 가능 여부 (무료 한도까지는 항상 free, 그 위는 trial)
    static func canAddPrealert(currentCount: Int) -> Bool {
        if currentCount < freePrealertLimit { return true }
        return evaluate(.unlimitedPrealerts).isAllowed
    }

    /// 템플릿 저장 가능 여부 (slot 기반 — trial 적용 안 됨)
    static func canSaveTemplate(currentCount: Int) -> Bool {
        StoreManager.isProUser || currentCount < freeTemplateLimit
    }

    /// 발표 모드 사용 가능 여부
    static var canUsePresentationMode: Bool {
        evaluate(.presentationMode).isAllowed
    }

    /// 오버타임 추적 사용 가능 여부
    static var canUseOvertime: Bool {
        evaluate(.overtimeTracking).isAllowed
    }

    /// 타이머 통계 사용 가능 여부
    static var canUseHistory: Bool {
        evaluate(.timerHistory).isAllowed
    }
}
