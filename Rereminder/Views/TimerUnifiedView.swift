//
//  TimerUnifiedView.swift
//  Rereminder
//
//  Created by xa on 8/28/25.
//

import Foundation
import SwiftUI

struct TimerUnifiedView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var screenVM = TimerScreenViewModel()
    @StateObject private var toast = ToastManager()
    @StateObject private var appStateManager = AppStateManager()

    @State private var showHistory = false
    @State private var showMessageEditor = false
    @State private var showPrealerts = false
    @State private var showProPaywall = false
    @State private var paywallStage: ProGate.PaywallStage = .second

    /// 타이머가 실행 중이 아닐 때만 모드 전환 허용
    private var isIdle: Bool {
        screenVM.state == .idle || screenVM.state == .finished
    }

    /// Free 사용자가 Presentation 선택 시 5+5 trial 평가
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { screenVM.currentMode },
            set: { newMode in
                // 실행 중에는 모드 전환(스와이프) 무시 → 자동으로 원래 페이지로 복귀
                guard isIdle else { return }
                guard newMode == .presentation else {
                    screenVM.currentMode = newMode
                    return
                }
                switch ProGate.evaluate(.presentationMode) {
                case .allowed, .allowedWithTrial:
                    screenVM.currentMode = newMode
                    ProGate.recordUsage(.presentationMode)
                    AnalyticsManager.log(.presentationModeStarted)
                case .blocked(let stage):
                    paywallStage = stage
                    showProPaywall = true
                    AnalyticsManager.log(.premiumTrialExhausted(
                        feature: .presentationMode,
                        stage: stage
                    ))
                }
            }
        )
    }

    private func enterPresentationAfterExtension() {
        screenVM.currentMode = .presentation
        ProGate.recordUsage(.presentationMode)
        AnalyticsManager.log(.presentationModeStarted)
    }

    var body: some View {
        mainContent
            .modifier(SheetsModifier(
                showHistory: $showHistory,
                showMessageEditor: $showMessageEditor,
                showPrealerts: $showPrealerts,
                showProPaywall: $showProPaywall,
                paywallStage: paywallStage,
                onAcceptExtension: enterPresentationAfterExtension,
                screenVM: screenVM
            ))
            .toast(toast)
            .onAppear(perform: setupOnAppear)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhase(oldPhase, newPhase)
            }
            .onChange(of: screenVM.state) { oldState, newState in
                handleStateChange(oldState, newState)
            }
    }

    // MARK: - Sub Views

    private var mainContent: some View {
        NavigationStack {
            modePager
                .toolbar { bottomToolbar }
        }
    }

    /// 타이머 ↔ 프레젠테이션을 좌우 스와이프로 전환하는 페이지네이션
    private var modePager: some View {
        TabView(selection: modeBinding) {
            TimerMainView()
                .padding()
                .padding(.bottom, pageIndicatorInset)
                .tag(AppMode.timer)

            PresentationContainerView()
                .padding(.bottom, pageIndicatorInset)
                .tag(AppMode.presentation)
        }
        .environmentObject(screenVM)
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    /// 페이지 인디케이터(점)가 하단 콘텐츠와 겹치지 않도록 확보하는 여백
    private let pageIndicatorInset: CGFloat = 28

    // MARK: - Bottom Toolbar

    @ToolbarContentBuilder
    private var bottomToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            if screenVM.currentMode == .timer {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel(String(localized: "Saved timers"))

                Spacer()

                Button {
                    showPrealerts = true
                } label: {
                    Image(systemName: "bell.badge")
                }
                .accessibilityLabel(String(localized: "Pre-alerts"))

                Spacer()

                Button {
                    showMessageEditor = true
                } label: {
                    Image(systemName: "text.bubble")
                }
                .accessibilityLabel(String(localized: "Edit notification message"))

                Spacer()
            }

            NavigationLink {
                NoticeSettingView()
                    .environmentObject(appStateManager)
                    .environmentObject(screenVM)
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel(String(localized: "Settings"))
        }
    }

    // MARK: - Actions

    private func setupOnAppear() {
        screenVM.attachContext(context)
        screenVM.seedTemplatesIfNeeded()
        screenVM.timerVM.showToast = { toast.show(Toast($0)) }
        screenVM.showToast = { toast.show(Toast($0)) }
        screenVM.timerVM.appStateManager = appStateManager
        screenVM.timerVM.modelContext = context
        screenVM.initialConfiguration()
        screenVM.restoreTimerIfNeeded()
    }

    private func handleScenePhase(_: ScenePhase, _ newPhase: ScenePhase) {
        appStateManager.updateState(newPhase)
        if newPhase == .active {
            screenVM.timerVM.engine.recalculateOnForeground()
            handleControlWidgetAction()
        }
    }

    private func handleStateChange(_: TimerState, _ newState: TimerState) {
        UIApplication.shared.isIdleTimerDisabled =
            (newState == .running || newState == .paused || newState == .overtime)
    }

    private func handleControlWidgetAction() {
        let shared = UserDefaults(suiteName: "group.leeo.toki")
        guard let action = shared?.string(forKey: "controlWidgetAction") else { return }
        shared?.removeObject(forKey: "controlWidgetAction")

        switch action {
        case "start":
            if screenVM.state == .idle || screenVM.state == .finished {
                if let siriDuration = shared?.object(forKey: "siriTimerDuration") as? Int, siriDuration > 0 {
                    shared?.removeObject(forKey: "siriTimerDuration")
                    screenVM.mainMinutes = siriDuration / 60
                    screenVM.mainSeconds = siriDuration % 60
                    screenVM.initialConfiguration()
                }
                screenVM.start()
            }
        case "stop":
            if screenVM.state == .running || screenVM.state == .paused || screenVM.state == .overtime {
                screenVM.cancel()
            }
        case "pause":
            if screenVM.state == .running {
                screenVM.pause()
            }
        case "resume":
            if screenVM.state == .paused {
                screenVM.resume()
            }
        default:
            break
        }
    }
}

// MARK: - Sheets Modifier (body 타입체커 부담 분산)

private struct SheetsModifier: ViewModifier {
    @Binding var showHistory: Bool
    @Binding var showMessageEditor: Bool
    @Binding var showPrealerts: Bool
    @Binding var showProPaywall: Bool
    let paywallStage: ProGate.PaywallStage
    let onAcceptExtension: () -> Void
    let screenVM: TimerScreenViewModel

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showHistory) {
                TimerTemplateView { selected in
                    screenVM.apply(template: selected)
                }
                .presentationDetents(Set<PresentationDetent>([.medium, .large]))
                .presentationDragIndicator(Visibility.visible)
            }
            .sheet(isPresented: $showMessageEditor) {
                NotificationMessageSettingView()
                    .environmentObject(screenVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPrealerts) {
                PrealertSettingsView()
                    .environmentObject(screenVM)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .paywallGate(
                isPresented: $showProPaywall,
                feature: .presentationMode,
                stage: paywallStage,
                onAcceptExtension: onAcceptExtension
            )
    }
}
