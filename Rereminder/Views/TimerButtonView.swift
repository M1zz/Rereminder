//
//  TimerButton.swift
//  Rereminder
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
                .buttonStyle(TimerButtonStyle(tint: DSColor.plain, size: buttonSize))
                .disabled(true)
                .accessibilityLabel(String(localized: "Cancel"))

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.positive, size: buttonSize))
                .accessibilityLabel(String(localized: "Start Timer"))
            }

        case .finished:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.plain, size: buttonSize))
                .accessibilityLabel(String(localized: "Cancel"))

                Button(action: onStart) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.positive, size: buttonSize))
                .accessibilityLabel(String(localized: "Start Timer"))
            }

        case .running:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.plain, size: buttonSize))
                .accessibilityLabel(String(localized: "Cancel Timer"))

                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.negativeSoft, size: buttonSize))
                .accessibilityLabel(String(localized: "Pause Timer"))
            }

        case .paused:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.plain, size: buttonSize))
                .accessibilityLabel(String(localized: "Cancel Timer"))

                Button(action: onResume) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.positive, size: buttonSize))
                .accessibilityLabel(String(localized: "Resume Timer"))
            }
        case .overtime:
            HStack(spacing: spacing) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.plain, size: buttonSize))
                .accessibilityLabel(String(localized: "Cancel Timer"))

                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.negativeSoft, size: buttonSize))
                .accessibilityLabel(String(localized: "Pause Timer"))
            }
        }

    }
}

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
