//
//  StatusIndicator.swift
//  Rereminder
//
//  타이머 상태 표시 인디케이터
//  색약 사용자를 위해 상태마다 색 + 고유한 형태(SF Symbol)를 함께 사용한다.
//

import SwiftUI

struct StatusIndicator: View {
    let state: TimerState
    @State private var isAnimating = false
    @ScaledMetric private var size: CGFloat = 14
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(stateColor)
            .symbolRenderingMode(.hierarchical)
            .opacity(shouldBlink && !reduceMotion ? (isAnimating ? 1.0 : DSOpacity.dim) : 1.0)
            .onAppear {
                guard shouldBlink, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .accessibilityLabel(stateLabel)
    }

    private var shouldBlink: Bool {
        state == .idle
    }

    /// 상태별 고유 형태 — 색 없이도(흑백) 구분 가능하도록 한다.
    private var symbolName: String {
        switch state {
        case .idle:
            return "circle"
        case .running:
            return "play.circle.fill"
        case .paused:
            return "pause.circle.fill"
        case .finished:
            return "checkmark.circle.fill"
        case .overtime:
            return "exclamationmark.triangle.fill"
        }
    }

    private var stateColor: Color {
        switch state {
        case .idle:
            return DSColor.stateIdle
        case .running:
            return DSColor.stateRunning
        case .paused:
            return DSColor.statePaused
        case .finished:
            return DSColor.stateFinished
        case .overtime:
            return DSColor.stateOvertime
        }
    }

    private var stateLabel: String {
        switch state {
        case .idle:
            return String(localized: "Ready")
        case .running:
            return String(localized: "Running")
        case .paused:
            return String(localized: "Paused")
        case .finished:
            return String(localized: "Finished")
        case .overtime:
            return String(localized: "Overtime")
        }
    }
}
