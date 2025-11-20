//
//  OnboardingView.swift
//  Toki
//
//  Created for usability improvements
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "clock.fill",
            title: "정확한 시간 관리",
            description: "발표나 멘토링 시간을 정확하게 맞춰 데드라인을 절대 놓치지 마세요"
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "미리 알림으로 여유있게",
            description: "종료 전 여러 번 알림을 받아 마무리 시간을 충분히 확보하세요"
        ),
        OnboardingPage(
            icon: "hand.tap.fill",
            title: "간편한 시간 설정",
            description: "원형 드래그, 숫자 입력, 빠른 프리셋 중 편한 방법을 선택하세요"
        )
    ]

    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Spacer()
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    isPresented = false
                }) {
                    Text("건너뛰기")
                        .foregroundStyle(.secondary)
                }
                .padding()
            }

            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            if currentPage == pages.count - 1 {
                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    isPresented = false
                }) {
                    Text("시작하기")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            } else {
                Button(action: {
                    withAnimation {
                        currentPage += 1
                    }
                }) {
                    Text("다음")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}
