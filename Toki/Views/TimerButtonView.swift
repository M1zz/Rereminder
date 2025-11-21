//
//  TimerButton.swift
//  Toki
//
//  Created by POS on 8/26/25.
//

import Foundation
import SwiftUI

struct TimerButton: View {
    let state: TimerState
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    var buttonSize: CGFloat = 70

    @ScaledMetric private var spacing: CGFloat = 40

    var body: some View {
        switch state {
        case .idle:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .disabled(true)
                .accessibilityLabel("취소")

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive, size: buttonSize))
                .accessibilityLabel("타이머 시작")
            }

        case .finished:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("취소")

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive, size: buttonSize))
                .accessibilityLabel("타이머 시작")
            }

        case .running:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("타이머 취소")

                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.bitNegative, size: buttonSize))
                .accessibilityLabel("타이머 일시정지")
            }

        case .paused:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("타이머 취소")

                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive, size: buttonSize))
                .accessibilityLabel("타이머 재개")
            }
        case .overtime:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("타이머 취소")

                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.bitNegative, size: buttonSize))
                .accessibilityLabel("타이머 일시정지")
            }
        }

    }
}

struct TimerButtonStyle: ButtonStyle {
    var tint: Color
    var size: CGFloat = 70
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .frame(minWidth: size, minHeight: size)
            .foregroundStyle(.white)
            .background(
                Circle()
                    .fill(
                        (isEnabled ? tint : .gray)
                            .opacity(pressed ? 0.7 : 1.0)
                    )
            )
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .opacity(isEnabled ? 1 : 0.6)
    }
}
