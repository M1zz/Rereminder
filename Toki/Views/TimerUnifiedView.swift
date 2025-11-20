//
//  TimerUnifiedView.swift
//  Toki
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
                // notice setting
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        NoticeSettingView()
                            .environmentObject(appStateManager)
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
        .toast(toast)
        .onAppear {
            screenVM.attachContext(context)
            screenVM.timerVM.showToast = { toast.show(Toast($0)) }
            screenVM.showToast = { toast.show(Toast($0)) }
            screenVM.timerVM.appStateManager = appStateManager
            screenVM.initialConfiguration()
        }
        .onChange(of: scenePhase) { phase in
            appStateManager.updateState(phase)
        }
    }
}
