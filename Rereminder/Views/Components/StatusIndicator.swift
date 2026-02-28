//
//  StatusIndicator.swift
//  Rereminder
//
//  타이머 상태 표시 인디케이터 (깜빡이는 동그라미)
//

import SwiftUI

struct StatusIndicator: View {
    let state: TimerState
    @State private var isAnimating = false
    @ScaledMetric private var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(stateColor)
            .frame(width: size, height: size)
            .opacity(shouldBlink ? (isAnimating ? 1.0 : 0.3) : 1.0)
            .onAppear {
                if shouldBlink {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
    }

    private var shouldBlink: Bool {
        state == .idle
    }

    private var stateColor: Color {
        switch state {
        case .idle:
            return .yellow
        case .running:
            return .green
        case .paused:
            return .orange
        case .finished:
            return .blue
        case .overtime:
            return .red
        }
    }
}
