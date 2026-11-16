//
//  TimerButtonStyle.swift
//  Rereminder
//
//  원 **안**에 서는 동그란 동작 버튼(정지·시작·일시정지)의 모양.
//
//  ⚠️ 2.2.0 에서 버튼을 원 밖 캡슐 한 줄로 뺐다가 되돌렸다 — 원 안이 더 낫다는
//     판단이다. 가운데 시간 바로 아래에 있어야 "이 타이머를 멈춘다"가 한 덩어리로 읽힌다.
//

import SwiftUI

struct TimerButtonStyle: ButtonStyle {
    var tint: Color
    var size: CGFloat = 70
    /// 원보다 넓게 그릴 때의 폭. 없으면 원이다.
    var width: CGFloat?
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .frame(minWidth: max(width ?? size, 44), minHeight: max(size, 44))
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(
                        (isEnabled ? tint : .gray)
                            .opacity(pressed ? DSOpacity.track + 0.2 : 1.0)
                    )
            )
            // 보이는 모양 전체가 눌리는 자리다(포인터·키보드 초점 테두리도 이 모양을 따른다).
            .contentShape(Capsule())
            .contentShape(.hoverEffect, Capsule())
            // 길게 눌러 메뉴가 뜰 때 들리는 모양(안 주면 네모로 들린다).
            .contentShape(.contextMenuPreview, Capsule())
            .hoverEffect(.highlight)
            // 넓은 알약을 0.9 로 줄이면 원보다 훨씬 크게 움찔한다. 폭이 넓을수록 덜 줄인다.
            .scaleEffect(reduceMotion ? 1 : (pressed ? (width == nil ? 0.9 : 0.96) : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .opacity(isEnabled ? 1 : 0.6)
    }
}
