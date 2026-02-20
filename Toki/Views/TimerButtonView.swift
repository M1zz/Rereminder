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
                .accessibilityLabel("Cancel")

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive, size: buttonSize))
                .accessibilityLabel("Start Timer")
            }

        case .finished:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("Cancel")

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive, size: buttonSize))
                .accessibilityLabel("Start Timer")
            }

        case .running:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("Cancel Timer")

                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.bitNegative, size: buttonSize))
                .accessibilityLabel("Pause Timer")
            }

        case .paused:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("Cancel Timer")

                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive, size: buttonSize))
                .accessibilityLabel("Resume Timer")
            }
        case .overtime:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.plain, size: buttonSize))
                .accessibilityLabel("Cancel Timer")

                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.bitNegative, size: buttonSize))
                .accessibilityLabel("Pause Timer")
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
