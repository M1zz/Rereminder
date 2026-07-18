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
    @State private var showProPaywall = false
    @State private var paywallStage: ProGate.PaywallStage = .second

    /// 타이머가 실행 중이 아닐 때만 모드 전환 허용
    private var isIdle: Bool {
        screenVM.state == .idle || screenVM.state == .finished
    }

    /// 모드 세그먼트 바인딩 — 발표는 5+5 trial 평가, 실행 중에는 전환 차단
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { screenVM.currentMode },
            set: { newMode in
                guard newMode != screenVM.currentMode else { return }

                // 실행 중 전환 차단은 의도된 동작 — 이유를 토스트로 안내
                guard isIdle else {
                    toast.show(Toast(String(localized: "Stop the timer to switch modes")))
                    return
                }

                guard newMode == .presentation else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        screenVM.currentMode = .timer
                    }
                    return
                }

                switch ProGate.evaluate(.presentationMode) {
                case .allowed, .allowedWithTrial:
                    withAnimation(.easeInOut(duration: 0.3)) {
                        screenVM.currentMode = .presentation
                    }
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
            .paywallGate(
                isPresented: $showProPaywall,
                feature: .presentationMode,
                stage: paywallStage,
                onAcceptExtension: enterPresentationAfterExtension
            )
            .toast(toast)
            .onAppear(perform: setupOnAppear)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhase(oldPhase, newPhase)
            }
            .onChange(of: screenVM.state) { oldState, newState in
                handleStateChange(oldState, newState)
            }
            .onChange(of: screenVM.remaining) { _, newValue in
                #if targetEnvironment(macCatalyst)
                MenuBarManager.shared.update(remaining: newValue, state: screenVM.state)
                #endif
            }
    }

    // MARK: - Sub Views

    /// 하단 바: 왼쪽 = 모드 세그먼트(타이머·발표), 오른쪽 = 도구(템플릿·설정)
    private var mainContent: some View {
        NavigationStack {
            // 두 모드 모두 다이얼 화면 사용 — 발표 모드는 구간 링·구간 편집 모달이 추가됨
            TimerMainView()
                .padding()
                .toolbar { bottomToolbar }
        }
        .environmentObject(screenVM)
        // 화면 어디를 탭해도 키보드 내림 (버튼·드래그 등 기존 조작은 그대로)
        .simultaneousGesture(TapGesture().onEnded {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
        })
        .sheet(isPresented: $showHistory) {
            TimerTemplateView { selected in
                screenVM.apply(template: selected)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ToolbarContentBuilder
    private var bottomToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Picker("", selection: modeBinding) {
                Image(systemName: "timer")
                    .accessibilityLabel(String(localized: "Timer"))
                    .tag(AppMode.timer)
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .accessibilityLabel(String(localized: "Presentation"))
                    .tag(AppMode.presentation)
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Spacer()

            Button {
                showHistory = true
            } label: {
                Image(systemName: "list.bullet")
            }
            .accessibilityLabel(String(localized: "Saved timers"))

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

        #if targetEnvironment(macCatalyst)
        // 메뉴바 타이머 (RereminderMenuBar 번들이 임베드된 빌드에서만 동작)
        MenuBarManager.shared.setUpIfAvailable()
        MenuBarManager.shared.onPauseToggle = {
            if screenVM.state == .running || screenVM.state == .overtime {
                screenVM.pause()
            } else if screenVM.state == .paused {
                screenVM.resume()
            }
        }
        MenuBarManager.shared.onStop = {
            screenVM.cancel()
        }
        MenuBarManager.shared.update(remaining: screenVM.remaining, state: screenVM.state)
        #endif
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

        #if targetEnvironment(macCatalyst)
        MenuBarManager.shared.update(remaining: screenVM.remaining, state: newState)
        #endif
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
