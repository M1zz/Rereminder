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

    static let freePrealertLimit = 1
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

    /// 예비 알림 추가 가능 여부 (1번째는 항상 free, 2번째 이상은 trial)
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
