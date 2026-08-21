//
//  OnboardingView.swift
//  Rereminder
//
//  온보딩 **한 장의 틀**(아이콘 + 제목 + 설명 + 예시). 지금은 새 흐름
//  (`OnboardingFlowView`)의 마지막 장 — 기기 안내 — 하나가 이걸 쓴다.
//
//  예전에는 이 틀로 만든 일곱 장을 넘기는 게 온보딩 전부였다. 아무도 읽지 않아서
//  "고르고 해 보는" 흐름으로 갈아엎었고(2.1.2), 그때 쓰이지 않게 된 문구
//  (`onboarding_title_1`~`6` 등)는 카탈로그에서 지웠다.
//

import SwiftUI

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
    OnboardingPageView(page: OnboardingPage(
        icon: "square.stack.3d.up.fill",
        titleKey: "onboarding_title_7",
        descriptionKey: "onboarding_desc_7",
        color: .teal,
        scenarioKey: "onboarding_scenario_7"
    ))
}
