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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // idle 상태일 때 모드 전환 Picker
                if isIdle {
                    Picker("Mode", selection: Binding(
                        get: { screenVM.currentMode },
                        set: { newMode in
                            if newMode == .presentation && !ProGate.canUsePresentationMode {
                                showProPaywall = true
                            } else {
                                screenVM.currentMode = newMode
                            }
                        }
                    )) {
                        Text("Timer").tag(AppMode.timer)
                        Text("Presentation").tag(AppMode.presentation)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // 모드에 따른 뷰 분기
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
            .toolbar {
                // timer template (타이머 모드에서만)
                ToolbarItem(placement: .topBarLeading) {
                    if screenVM.currentMode == .timer {
                        Button {
                            showHistory = true
                        } label: {
                            Image(systemName: "list.bullet")
                        }
                    }
                }
                // notification message editor (타이머 모드에서만)
                ToolbarItem(placement: .topBarTrailing) {
                    if screenVM.currentMode == .timer {
                        Button {
                            showMessageEditor = true
                        } label: {
                            Image(systemName: "text.bubble")
                        }
                    }
                }
                // notice setting
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
        }
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
        .toast(toast)
        .onAppear {
            screenVM.attachContext(context)
            screenVM.seedTemplatesIfNeeded()
            screenVM.timerVM.showToast = { toast.show(Toast($0)) }
            screenVM.showToast = { toast.show(Toast($0)) }
            screenVM.timerVM.appStateManager = appStateManager
            screenVM.timerVM.modelContext = context
            screenVM.initialConfiguration()
            screenVM.restoreTimerIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            appStateManager.updateState(newPhase)
            // 포그라운드 복귀 시 endDate 기반 재계산
            if newPhase == .active {
                screenVM.timerVM.engine.recalculateOnForeground()
                handleControlWidgetAction()
            }
        }
        .onChange(of: screenVM.state) { _, newState in
            UIApplication.shared.isIdleTimerDisabled =
                (newState == .running || newState == .paused || newState == .overtime)
        }
        .paywallGate(isPresented: $showProPaywall, feature: .presentationMode)
    }

    private func handleControlWidgetAction() {
        let shared = UserDefaults(suiteName: "group.leeo.toki")
        guard let action = shared?.string(forKey: "controlWidgetAction") else { return }
        shared?.removeObject(forKey: "controlWidgetAction")

        switch action {
        case "start":
            if screenVM.state == .idle || screenVM.state == .finished {
                // Siri에서 duration을 지정한 경우 적용
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
