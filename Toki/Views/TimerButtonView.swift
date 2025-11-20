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

    var body: some View {
        switch state {
        case .idle:
            HStack(spacing: 40) {
                Button(action: onCancel) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                        Text("취소")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain))
                .disabled(true)
                .accessibilityLabel("취소")

                Button(action: onStart) {
                    VStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                        Text("시작")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive))
                .accessibilityLabel("타이머 시작")
            }

        case .finished:
            HStack(spacing: 40) {
                Button(action: onCancel) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                        Text("취소")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain))
                .accessibilityLabel("취소")

                Button(action: onStart) {
                    VStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                        Text("시작")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive))
                .accessibilityLabel("타이머 시작")
            }

        case .running:
            HStack(spacing: 40) {
                Button(action: onCancel) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                        Text("취소")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain))
                .accessibilityLabel("타이머 취소")

                Button(action: onPause) {
                    VStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 20))
                        Text("일시정지")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.bitNegative))
                .accessibilityLabel("타이머 일시정지")
            }

        case .paused:
            HStack(spacing: 40) {
                Button(action: onCancel) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                        Text("취소")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain))
                .accessibilityLabel("타이머 취소")

                Button(action: onResume) {
                    VStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                        Text("재개")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive))
                .accessibilityLabel("타이머 재개")
            }
        }

    }
}

struct TimerButtonStyle: ButtonStyle {
    var tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .frame(minWidth: 70, minHeight: 70)
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
