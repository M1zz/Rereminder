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

    var body: some View {
        NavigationStack {
            TimerMainView()
                .environmentObject(screenVM)
            .padding()
            .toolbar {
                // timer template
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                // notification message editor
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMessageEditor = true
                    } label: {
                        Image(systemName: "text.bubble")
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
            screenVM.timerVM.showToast = { toast.show(Toast($0)) }
            screenVM.showToast = { toast.show(Toast($0)) }
            screenVM.timerVM.appStateManager = appStateManager
            screenVM.timerVM.modelContext = context
            screenVM.initialConfiguration()
        }
        .onChange(of: scenePhase) { _, newPhase in
            appStateManager.updateState(newPhase)
            // 포그라운드 복귀 시 endDate 기반 재계산
            if newPhase == .active {
                screenVM.timerVM.engine.recalculateOnForeground()
            }
        }
    }
}
