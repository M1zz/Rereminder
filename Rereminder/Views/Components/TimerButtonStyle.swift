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
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .frame(minWidth: size, minHeight: size)
            .foregroundStyle(.white)
            .background(
                Circle()
                    .fill(
                        (isEnabled ? tint : .gray)
                            .opacity(pressed ? DSOpacity.track + 0.2 : 1.0)
                    )
            )
            .scaleEffect(reduceMotion ? 1 : (pressed ? 0.9 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
            .opacity(isEnabled ? 1 : 0.6)
    }
}
