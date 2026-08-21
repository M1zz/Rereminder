//
//  OnboardingFlowView.swift
//  Rereminder
//
//  첫 실행 안내 — **읽는 안내가 아니라 해 보는 안내.**
//
//  흐름: 환영 → 어디에 쓸 건가요 → (그 설정으로) 60배속 체험 → 템플릿 저장 → 기기 안내
//
//  왜 이렇게 짰나
//   • 기능을 나열하는 장면 일곱 개는 아무도 안 읽는다. 대신 **자기 상황을 고르게** 하고,
//     그 상황의 타이머를 눈앞에서 굴린다(10분이 10초에 끝난다).
//   • 온보딩이 끝나면 **고른 설정이 이미 다이얼에 올라가 있다.** 안내를 보고 나서 처음부터
//     다시 맞춰야 하면, 안내를 본 보람이 없다.
//   • 템플릿은 "두 번째부터 빨라지는" 기능이라 첫 화면에서 한 번 만들어 보게 한다.
//
//  ⚠️ 체험은 진짜 타이머가 아니다(`OnboardingDemoTimer`) — 알림도 Live Activity 도 없다.
//

import SwiftUI

struct OnboardingFlowView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step: Int, CaseIterable {
        case welcome, useCase, demo, template, devices
    }

    @State private var step: Step = .welcome
    @State private var useCase: OnboardingUseCase?
    @State private var didSaveTemplate = false

    private var chosen: OnboardingUseCase { useCase ?? .suggested }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.accentColor.opacity(0.12), Color(uiColor: .systemBackground)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                content
                    .frame(maxHeight: .infinity)
                footer
            }
        }
        .onAppear { AnalyticsManager.log(.onboardingShown) }
    }

    // MARK: - 머리 / 발

    private var header: some View {
        HStack {
            if step != .welcome {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "Back"))
            }

            Spacer()

            Button {
                AnalyticsManager.log(.onboardingSkipped(page: step.rawValue))
                finish()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.vertical, DSSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:  welcomeStep
        case .useCase:  useCaseStep
        case .demo:     demoStep
        case .template: templateStep
        case .devices:  devicesStep
        }
    }

    private var footer: some View {
        VStack(spacing: DSSpacing.sm) {
            Button(action: advance) {
                Text(primaryTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.lg)
                    .background(Capsule().fill(Color.accentColor))
            }
            .disabled(step == .useCase && useCase == nil)
            .opacity(step == .useCase && useCase == nil ? 0.5 : 1)

            // 몇 걸음 남았는지 — 끝이 보이면 사람이 덜 나간다
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    Capsule()
                        .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: item == step ? 18 : 6, height: 6)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.bottom, DSSpacing.xxl)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome:  return String(localized: "Next")
        case .useCase:  return String(localized: "Try it")
        case .demo:     return String(localized: "Next")
        case .template: return String(localized: "Next")
        case .devices:  return String(localized: "Get Started")
        }
    }

    // MARK: - 1. 환영

    private var welcomeStep: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: DSSpacing.md) {
                Text("One timer, several heads-ups")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Most timers only ring at the end. This one taps you on the shoulder before that — so you can land on time instead of being cut off.")
                    .font(DSFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }
            Spacer()
        }
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - 2. 어디에 쓸 건가요

    private var useCaseStep: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("What will you use it for?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Pick one and we'll set the timer up for you. You can change everything later.")
                    .font(DSFont.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DSSpacing.xl)

            ScrollView {
                VStack(spacing: DSSpacing.sm) {
                    ForEach(OnboardingUseCase.all) { item in
                        useCaseCard(item)
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
                .padding(.bottom, DSSpacing.md)
            }
        }
    }

    private func useCaseCard(_ item: OnboardingUseCase) -> some View {
        let isSelected = useCase?.id == item.id

        return Button {
            useCase = item
        } label: {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: item.symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(DSFont.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(item.reason)
                        .font(DSFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.setupSummary)
                        .font(DSFont.caption.monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                }

                Spacer(minLength: 0)
            }
            .padding(DSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 3. 체험 (60배속)

    private var demoStep: some View {
        // ⚠️ 장난감 타이머는 **서브뷰의 `@StateObject`** 로 들고 있어야 한다.
        //    `@State` 에 담으면 참조만 갖고 `@Published` 변화를 구독하지 않아 화면이 멈춘 채로
        //    보인다(숫자가 10:00 에서 안 움직였다). 상황을 바꾸면 `.id` 로 새로 만든다.
        OnboardingDemoStep(useCase: chosen)
            .id(chosen.id)
    }

    // MARK: - 4. 템플릿

    private var templateStep: some View {
        VStack(spacing: DSSpacing.xl) {
            Spacer()

            Image(systemName: didSaveTemplate ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(didSaveTemplate ? Color.green : Color.accentColor)
                .accessibilityHidden(true)

            VStack(spacing: DSSpacing.md) {
                Text("Keep this setup?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Saved timers sit one tap away on the main screen, so you never build the same one twice.")
                    .font(DSFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xl)
            }

            // 저장될 내용을 그대로 보여 준다 — 무엇이 저장되는지 모르면 누르기 어렵다
            VStack(spacing: DSSpacing.xs) {
                Text(chosen.title)
                    .font(DSFont.body.weight(.semibold))
                Text(chosen.setupSummary)
                    .font(DSFont.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, DSSpacing.xl)

            Button {
                screenVM.saveCurrentAsTemplate()
                didSaveTemplate = true
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            } label: {
                Label(didSaveTemplate ? String(localized: "Saved") : String(localized: "Save as template"),
                      systemImage: didSaveTemplate ? "checkmark" : "plus")
                    .font(DSFont.body.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Color.accentColor)
            .disabled(didSaveTemplate)

            Spacer()
        }
    }

    // MARK: - 5. 기기 안내 (기존 마지막 장 재사용)

    private var devicesStep: some View {
        OnboardingPageView(page: OnboardingPage(
            icon: "square.stack.3d.up.fill",
            titleKey: "onboarding_title_7",
            descriptionKey: "onboarding_desc_7",
            color: .teal,
            scenarioKey: "onboarding_scenario_7"
        ))
    }

    // MARK: - 이동

    private func advance() {
        switch step {
        case .welcome:
            go(to: .useCase)
        case .useCase:
            // 고른 상황을 **지금** 다이얼에 올린다 — 다음 장(템플릿 저장)이 이 값을 저장한다
            applyUseCase()
            go(to: .demo)
        case .demo:
            go(to: .template)
        case .template:
            go(to: .devices)
        case .devices:
            AnalyticsManager.log(.onboardingCompleted)
            finish()
        }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        go(to: previous)
    }

    private func go(to next: Step) {
        if reduceMotion {
            step = next
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { step = next }
        }
    }

    /// 고른 상황을 다이얼에 반영한다. 발표 상황이면 구간 이름까지 채운다.
    private func applyUseCase() {
        let item = chosen
        screenVM.mainMinutes = item.minutes
        screenVM.mainSeconds = 0
        screenVM.selectedOffsets = Set(item.alerts)
        if !item.sectionNames.isEmpty {
            screenVM.sectionNames = Dictionary(uniqueKeysWithValues:
                item.sectionNames.enumerated().map { ($0.offset, $0.element) })
        }
        screenVM.initialConfiguration()
    }

    private func finish() {
        // 건너뛰어도 고른 것이 있으면 반영한다 — 고르고 나간 사람에게 기본값을 주면 헛수고다
        if useCase != nil { applyUseCase() }
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        if reduceMotion {
            isPresented = false
        } else {
            withAnimation(.easeOut(duration: 0.25)) { isPresented = false }
        }
    }
}

// MARK: - 체험 한 장

/// 고른 상황의 타이머를 60배속으로 굴리는 장면.
/// **장난감 타이머를 `@StateObject` 로 들고 있는 것이 이 뷰가 따로 있는 이유다** —
/// 부모의 `@State` 에 담으면 값이 변해도 화면이 갱신되지 않는다.
private struct OnboardingDemoStep: View {
    let useCase: OnboardingUseCase
    @StateObject private var demo: OnboardingDemoTimer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(useCase: OnboardingUseCase) {
        self.useCase = useCase
        _demo = StateObject(wrappedValue: OnboardingDemoTimer(totalSeconds: useCase.totalSeconds,
                                                              alerts: useCase.alerts))
    }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            VStack(spacing: DSSpacing.xs) {
                // 길이와 상관없이 체험은 늘 10초다 — 배속이 길이를 따라 바뀐다
                Text("\(useCase.minutes) minutes in \(Int(OnboardingDemoTimer.demoSeconds)) seconds")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Sped up \(Int(demo.speed))×. Watch the bells ring before the end.")
                    .font(DSFont.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.xl)

            ZStack(alignment: .top) {
                OnboardingDemoRing(totalSeconds: demo.totalSeconds,
                                   alerts: demo.alerts,
                                   elapsed: demo.elapsed,
                                   size: 230)
                    .padding(.top, 44)

                if let label = demo.ringingLabel {
                    ringBanner(label)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8),
                       value: demo.ringingLabel)

            Button {
                demo.restart()
            } label: {
                Label("Replay", systemImage: "arrow.counterclockwise")
                    .font(DSFont.callout.weight(.medium))
            }
            .buttonStyle(.bordered)
            .tint(Color.accentColor)
            .opacity(demo.isFinished ? 1 : 0.35)
            .disabled(!demo.isFinished)
        }
        .onAppear { demo.start() }
        .onDisappear { demo.stop() }
    }

    private func ringBanner(_ label: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "bell.fill")
            Text(label)
                .font(DSFont.body.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
        .background(Capsule().fill(DSColor.marker))
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        .accessibilityAddTraits(.isStaticText)
    }
}
