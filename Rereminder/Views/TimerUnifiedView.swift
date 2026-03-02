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
    @State private var showProPaywall = false

    /// 타이머가 실행 중이 아닐 때만 모드 전환 허용
    private var isIdle: Bool {
        screenVM.state == .idle || screenVM.state == .finished
    }

    /// Free 사용자가 Presentation 선택 시 페이월 표시, 모드 변경 차단
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { screenVM.currentMode },
            set: { newMode in
                if newMode == .presentation && !ProGate.canUsePresentationMode {
                    showProPaywall = true
                } else {
                    screenVM.currentMode = newMode
                }
            }
        )
    }

    var body: some View {
        mainContent
            .modifier(SheetsModifier(
                showHistory: $showHistory,
                showMessageEditor: $showMessageEditor,
                showProPaywall: $showProPaywall,
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
            VStack(spacing: 0) {
                modePicker
                modeContent
            }
            .toolbar {
                toolbarLeading
                toolbarMessageEditor
                toolbarSettings
            }
        }
    }

    @ViewBuilder
    private var modePicker: some View {
        if isIdle {
            Picker("Mode", selection: modeBinding) {
                Text("Timer").tag(AppMode.timer)
                Text("Presentation").tag(AppMode.presentation)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var modeContent: some View {
        Group {
            switch screenVM.currentMode {
            case .timer:
                TimerMainView()
                    .padding()
            case .presentation:
                PresentationContainerView()
            }
        }
        .environmentObject(screenVM)
    }

    // MARK: - Toolbar

    private var toolbarLeading: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if screenVM.currentMode == .timer {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
        }
    }

    private var toolbarMessageEditor: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if screenVM.currentMode == .timer {
                Button {
                    showMessageEditor = true
                } label: {
                    Image(systemName: "text.bubble")
                }
            }
        }
    }

    private var toolbarSettings: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                NoticeSettingView()
                    .environmentObject(appStateManager)
                    .environmentObject(screenVM)
            } label: {
                Image(systemName: "gearshape")
            }
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
    @Binding var showProPaywall: Bool
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
            .paywallGate(isPresented: $showProPaywall, feature: .presentationMode)
    }
}
