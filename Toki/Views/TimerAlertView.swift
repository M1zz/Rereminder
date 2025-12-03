//
//  TimerAlertView.swift
//  Toki
//
//  타이머 종료 시 전체 화면 알림
//

import SwiftUI

struct TimerAlertView: View {
    let onDismiss: () -> Void

    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.5

    var body: some View {
        ZStack {
            // 배경
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onAppear {
                    print("🎯 TimerAlertView가 화면에 표시되었습니다!")
                }

            VStack(spacing: 40) {
                // 타이머 아이콘
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .opacity(isAnimating ? 0 : 1)

                    Image(systemName: "timer")
                        .font(.system(size: 100))
                        .foregroundColor(.red)
                }
                .scaleEffect(scale)

                // 메시지
                VStack(spacing: 16) {
                    Text("타이머 종료")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("시간이 다 되었습니다")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .scaleEffect(scale)

                // 확인 버튼
                Button(action: onDismiss) {
                    Text("확인")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.red)
                        .cornerRadius(16)
                        .padding(.horizontal, 50)
                }
                .scaleEffect(scale)
            }
        }
        .onAppear {
            // 애니메이션
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
            }

            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }

            // 진동
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

            // 연속 진동
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                generator.notificationOccurred(.warning)
            }
        }
    }
}

#Preview {
    TimerAlertView(onDismiss: {})
}
