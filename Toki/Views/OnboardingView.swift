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
            title: "발표자와 멘토를 위한\n타이머",
            description: "강연, 멘토링, 회의 시간을 정확하게 지키는 것은 전문성의 기본입니다",
            color: .blue,
            scenario: "40분 멘토링 세션, 5분 전 알림으로 마무리 준비"
        ),
        OnboardingPage(
            icon: "clock.badge.checkmark.fill",
            title: "데드라인을 절대\n놓치지 마세요",
            description: "시간 초과로 인한 당황스러운 상황, 청중의 불편함을 방지하세요",
            color: .orange,
            scenario: "30분 발표, 10분·5분·1분 전 3번의 예비 알림"
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "여러 번 알림받고\n여유있게 마무리",
            description: "종료 10분 전, 5분 전, 1분 전 등 원하는 만큼 예비 알림을 설정하세요",
            color: .green,
            scenario: "끝나기 전 충분한 시간을 갖고 Q&A 안내"
        ),
        OnboardingPage(
            icon: "timer",
            title: "시간이 지나도\n계속 카운트",
            description: "00:00 이후에도 +01:23처럼 표시되어 정확히 얼마나 초과했는지 확인하세요",
            color: .red,
            scenario: "예상치 못한 질문으로 5분 초과, 정확한 시간 파악"
        ),
        OnboardingPage(
            icon: "hand.tap.fill",
            title: "3가지 방법으로\n빠르게 설정",
            description: "• 원형 드래그로 직관적 설정\n• 숫자 입력으로 정확한 시간\n• 빠른 프리셋으로 즉시 시작",
            color: .purple,
            scenario: nil
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
                // 건너뛰기 버튼
                HStack {
                    Spacer()
                    Button(action: skipOnboarding) {
                        Text("건너뛰기")
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
                            Text("시작하기")
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
                                Text("다음")
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
    let title: String
    let description: String
    let color: Color
    let scenario: String?
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
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)

                    // 설명
                    Text(page.description)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .fixedSize(horizontal: false, vertical: true)

                    // 시나리오 예시 (있는 경우)
                    if let scenario = page.scenario {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                Text("사용 예시")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(page.color)

                            Text(scenario)
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
