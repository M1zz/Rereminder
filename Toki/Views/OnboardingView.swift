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
            icon: "person.3.fill",
            titleKey: "onboarding_title_1",
            descriptionKey: "onboarding_desc_1",
            color: .blue,
            scenarioKey: "onboarding_scenario_1"
        ),
        OnboardingPage(
            icon: "clock.badge.checkmark.fill",
            titleKey: "onboarding_title_2",
            descriptionKey: "onboarding_desc_2",
            color: .orange,
            scenarioKey: "onboarding_scenario_2"
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            titleKey: "onboarding_title_3",
            descriptionKey: "onboarding_desc_3",
            color: .green,
            scenarioKey: "onboarding_scenario_3"
        ),
        OnboardingPage(
            icon: "timer",
            titleKey: "onboarding_title_4",
            descriptionKey: "onboarding_desc_4",
            color: .red,
            scenarioKey: "onboarding_scenario_4"
        ),
        OnboardingPage(
            icon: "hand.tap.fill",
            titleKey: "onboarding_title_5",
            descriptionKey: "onboarding_desc_5",
            color: .purple,
            scenarioKey: nil
        )
    ]

    var body: some View {
        ZStack {
            // 배경 그라데이션
            LinearGradient(
                colors: [
                    pages[currentPage].color.opacity(0.1),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip 버튼
                HStack {
                    Spacer()
                    Button(action: skipOnboarding) {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }

                // 페이지 콘텐츠
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // 하단 버튼
                VStack(spacing: 12) {
                    if currentPage == pages.count - 1 {
                        Button(action: skipOnboarding) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(14)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                        }
                    } else {
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .cornerRadius(14)
                        }
                    }

                    // 페이지 인디케이터 (숫자)
                    Text("\(currentPage + 1) / \(pages.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func skipOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation {
            isPresented = false
        }
    }
}

struct OnboardingPage {
    let icon: String
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
    let color: Color
    let scenarioKey: LocalizedStringKey?
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 20)

                // 아이콘
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    page.color.opacity(0.2),
                                    page.color.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)

                    Image(systemName: page.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [page.color, page.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 16) {
                    // 타이틀
                    Text(page.titleKey)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)

                    // 설명
                    Text(page.descriptionKey)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)

                    // 시나리오 예시 (있는 경우)
                    if let scenarioKey = page.scenarioKey {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                Text("Usage Example")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(page.color)

                            Text(scenarioKey)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(page.color.opacity(0.08))
                                )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                }

                Spacer()
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
