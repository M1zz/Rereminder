//
//  OnboardingView.swift
//  Rereminder
//
//  Created for usability improvements
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            icon: "rectangle.split.3x1.fill",
            titleKey: "onboarding_title_5",
            descriptionKey: "onboarding_desc_5",
            color: .cyan,
            scenarioKey: "onboarding_scenario_5"
        ),
        OnboardingPage(
            icon: "hand.tap.fill",
            titleKey: "onboarding_title_6",
            descriptionKey: "onboarding_desc_6",
            color: .purple,
            scenarioKey: nil
        ),
        // 마지막 장은 "이 앱을 더 잘 쓰는 법" — 아이폰 하나로만 쓰면 절반만 쓰는 앱이다.
        // 자세한 기기별 활용은 설정 > Help > 모든 기기에서 사용하기 에서 다시 볼 수 있다.
        OnboardingPage(
            icon: "square.stack.3d.up.fill",
            titleKey: "onboarding_title_7",
            descriptionKey: "onboarding_desc_7",
            color: .teal,
            scenarioKey: "onboarding_scenario_7"
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
            .onAppear { AnalyticsManager.log(.onboardingShown) }

            VStack(spacing: 0) {
                // Skip 버튼
                HStack {
                    Spacer()
                    Button(action: {
                        AnalyticsManager.log(.onboardingSkipped(page: currentPage))
                        skipOnboarding()
                    }) {
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
                        Button(action: {
                            AnalyticsManager.log(.onboardingCompleted)
                            skipOnboarding()
                        }) {
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
                            if reduceMotion {
                                currentPage += 1
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    currentPage += 1
                                }
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
        if reduceMotion {
            isPresented = false
        } else {
            withAnimation {
                isPresented = false
            }
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
                        .dsScaledFont(60, relativeTo: .largeTitle, maxSize: 90)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [page.color, page.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .accessibilityHidden(true)

                VStack(spacing: DSSpacing.lg) {
                    // 타이틀
                    Text(page.titleKey)
                        .dsScaledFont(28, weight: .bold, design: .rounded, relativeTo: .title, maxSize: 44)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)

                    // 설명
                    Text(page.descriptionKey)
                        .font(DSFont.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, DSSpacing.xxxl)
                        .fixedSize(horizontal: false, vertical: true)

                    // 시나리오 예시 (있는 경우)
                    if let scenarioKey = page.scenarioKey {
                        VStack(spacing: DSSpacing.sm) {
                            HStack(spacing: DSSpacing.xs) {
                                Image(systemName: "lightbulb.fill")
                                    .font(DSFont.caption)
                                Text("Usage Example")
                                    .font(DSFont.caption.weight(.semibold))
                            }
                            .foregroundStyle(page.color)

                            Text(scenarioKey)
                                .font(DSFont.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DSSpacing.xl)
                                .padding(.vertical, DSSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DSRadius.md)
                                        .fill(page.color.opacity(DSOpacity.faint))
                                )
                        }
                        .padding(.horizontal, DSSpacing.xxl)
                        .padding(.top, DSSpacing.sm)
                    }
                }
                .accessibilityElement(children: .combine)

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
