//
//  ProGate.swift
//  Toki
//
//  무료/Pro 기능 제한 게이트
//
//  잠금 원칙:
//  - 무료: 타이머, 예비알림 2개, Live Activity, 오버타임, 소리/진동, Watch, 위젯
//  - Pro: 예비알림 무제한, 커스텀 메시지, 템플릿 무제한, 라벨 색상, 즐겨찾기 무제한, 통계
//

import Foundation

enum ProGate {

    // MARK: - Pro 기능 정의

    enum Feature: String, CaseIterable {
        case unlimitedPrealerts       // 예비 알림 3개 이상
        case customPrealertMessage    // 커스텀 Pre-alert 메시지
        case customFinishMessage      // 커스텀 종료 메시지
        case unlimitedTemplates       // 템플릿 4개 이상 저장
        case labelColors              // 라벨 색상 커스텀 (기본 1색 외)
        case timerHistory             // 타이머 사용 통계

        var displayName: String {
            switch self {
            case .unlimitedPrealerts:     return "Unlimited Pre-alerts"
            case .customPrealertMessage:  return "Custom Pre-alert Messages"
            case .customFinishMessage:    return "Custom Finish Message"
            case .unlimitedTemplates:     return "Unlimited Templates"
            case .labelColors:            return "Custom Label Colors"
            case .timerHistory:           return "Timer History & Stats"
            }
        }

        var icon: String {
            switch self {
            case .unlimitedPrealerts:     return "bell.badge.fill"
            case .customPrealertMessage:  return "text.bubble.fill"
            case .customFinishMessage:    return "bell.and.waves.left.and.right.fill"
            case .unlimitedTemplates:     return "square.stack.3d.up.fill"
            case .labelColors:            return "paintpalette.fill"
            case .timerHistory:           return "chart.bar.fill"
            }
        }
    }

    // MARK: - Free Limits

    static let freePrealertLimit = 2
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

    /// 라벨 색상 사용 가능 여부 (무료는 기본 파란색만)
    static func canUseColor(_ colorHex: String) -> Bool {
        StoreManager.isProUser || colorHex == "#007AFF"
    }
}
