//
//  TimerAlertView.swift
//  Rereminder
//
//  타이머가 끝나면 **아래에서 버튼 하나가 올라온다** — "시간이 다 됐어요 · 확인".
//
//  ⚠️ 예전에는 화면 전체를 검게 덮는 알림이었다. 발표·수업 중에 화면이 통째로 바뀌면 지금 보던 것
//     (대본·구간·시간)이 사라지고 청중에게도 크게 보인다. 끝났다는 사실과 끄는 버튼만 있으면 된다.
//

import SwiftUI

struct TimerAlertView: View {
    let onDismiss: () -> Void

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "timer")
                    .font(.title2.weight(.semibold))
                    .scaleEffect(pulse ? 1.12 : 1.0)
                    .accessibilityHidden(true)
                Text("Time is up", comment: "Timer alert subtitle")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: DSSpacing.sm)
                Text("OK", comment: "Timer alert dismiss button")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.vertical, DSSpacing.sm)
                    .background(Capsule().fill(.white.opacity(0.25)))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DSSpacing.xl)
            .frame(maxWidth: 520, minHeight: 64)
            .background(Capsule().fill(Color.red))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DSSpacing.lg)
        .accessibilityLabel(String(localized: "Dismiss timer alert"))
        // 음성 제어: 화면에 보이는 "OK" 로도 부른다.
        .accessibilityInputLabels([Text("OK"), Text("Stop")])
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
            }
            AccessibilityNotification.Announcement(
                String(localized: "Timer finished. Time is up.")
            ).post()
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                generator.notificationOccurred(.warning)
            }
            #endif
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color(.systemBackground)
        TimerAlertView(onDismiss: {})
    }
}
