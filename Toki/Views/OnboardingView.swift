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
        GeometryReader { geometry in
            VStack(spacing: geometry.size.height * 0.02) {
                HStack {
                    Spacer()
                    Button(action: {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        isPresented = false
                    }) {
                        Text("건너뛰기")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, geometry.size.width * 0.04)
                    .padding(.vertical, geometry.size.height * 0.015)
                }

                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index], geometry: geometry)
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
                            .padding(.vertical, 16)
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
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
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
    let geometry: GeometryProxy

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.15))
                .foregroundStyle(Color.accentColor)

            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, geometry.size.width * 0.1)
                .minimumScaleFactor(0.7)
                .lineLimit(3)

            Spacer()
        }
    }
}
