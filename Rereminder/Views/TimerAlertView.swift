//
//  TimerAlertView.swift
//  Rereminder
//
//  Timer Finished 시 전체 화면 알림
//

import SwiftUI

struct TimerAlertView: View {
    let onDismiss: () -> Void

    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // 배경
            Color.black.opacity(DSOpacity.strong)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Timer 아이콘
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0 : 1)

                    Image(systemName: "timer")
                        .dsScaledFont(100, relativeTo: .largeTitle, maxSize: 130)
                        .foregroundColor(.red)
                }
                .scaleEffect(scale)
                .accessibilityHidden(true)

                // 메시지
                VStack(spacing: DSSpacing.lg) {
                    Text("Timer Finished", comment: "Timer alert title")
                        .dsScaledFont(40, weight: .bold, design: .rounded, relativeTo: .largeTitle, maxSize: 60)
                        .foregroundColor(.white)

                    Text("Time is up", comment: "Timer alert subtitle")
                        .dsScaledFont(20, weight: .medium, relativeTo: .title3, maxSize: 32)
                        .foregroundColor(.white.opacity(0.8))
                }
                .scaleEffect(scale)
                .accessibilityElement(children: .combine)

                // OK 버튼
                Button(action: onDismiss) {
                    Text("OK", comment: "Timer alert dismiss button")
                        .dsScaledFont(24, weight: .semibold, design: .rounded, relativeTo: .title2, maxSize: 36)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                        .background(Color.red)
                        .cornerRadius(DSRadius.lg)
                        .padding(.horizontal, 50)
                }
                .scaleEffect(scale)
                .accessibilityLabel(String(localized: "Dismiss timer alert"))
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            // 애니메이션 (동작 줄이기 시 즉시 표시)
            if reduceMotion {
                scale = 1.0
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    scale = 1.0
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }

            // VoiceOver 안내
            AccessibilityNotification.Announcement(
                String(localized: "Timer finished. Time is up.")
            ).post()

            // Vibration
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

            // 연속 Vibration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                generator.notificationOccurred(.warning)
            }
        }
    }
}

#Preview {
    TimerAlertView(onDismiss: {})
}
