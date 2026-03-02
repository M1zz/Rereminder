//
//  ProGate.swift
//  Rereminder
//
//  무료/Pro 기능 제한 게이트
//
//  잠금 원칙:
//  - 무료: 타이머, 예비알림 1개, Live Activity, 소리/진동, Watch, 위젯, 커스텀 메시지, 테마/라벨 색상
//  - Pro: 예비알림 무제한, 발표 모드, 오버타임 추적, 템플릿 무제한, 통계
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
    }

    // MARK: - Free Limits

    static let freePrealertLimit = 1
    static let freeTemplateLimit = 3

    // MARK: - Gate Checks

    static func isAvailable(_ feature: Feature) -> Bool {
        StoreManager.isProUser
    }

    /// 예비 알림 추가 가능 여부
    static func canAddPrealert(currentCount: Int) -> Bool {
        StoreManager.isProUser || currentCount < freePrealertLimit
    }

    /// 템플릿 저장 가능 여부
    static func canSaveTemplate(currentCount: Int) -> Bool {
        StoreManager.isProUser || currentCount < freeTemplateLimit
    }

    /// 발표 모드 사용 가능 여부
    static var canUsePresentationMode: Bool {
        StoreManager.isProUser
    }

    /// 오버타임 추적 사용 가능 여부
    static var canUseOvertime: Bool {
        StoreManager.isProUser
    }
}
