//
//  DSAnimation.swift
//  Rereminder
//
//  디자인 시스템 - 모션 축소(Reduce Motion) 대응 애니메이션 헬퍼
//  접근성 "동작 줄이기"가 켜져 있으면 애니메이션을 끄고 즉시 전환한다.
//

import SwiftUI

private struct DSReduceMotionAnimation<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// `.animation(_:value:)` 의 접근성 대응 버전.
    /// "동작 줄이기"가 켜져 있으면 애니메이션 없이 값만 즉시 반영한다.
    func dsAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(DSReduceMotionAnimation(animation: animation, value: value))
    }
}

/// 반복(repeatForever) 애니메이션처럼 `withAnimation` 으로 직접 제어해야 하는 경우,
/// 뷰에서 `@Environment(\.accessibilityReduceMotion)` 을 직접 읽어 분기한다.
/// 이 헬퍼는 그 분기를 한 줄로 표현하기 위한 보조용이다.
enum DSMotion {
    /// reduceMotion 이면 nil, 아니면 주어진 애니메이션을 반환한다.
    static func gated(_ animation: Animation?, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
