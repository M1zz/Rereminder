//
//  ContentView.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import SwiftData
import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

    var body: some View {
        TimerUnifiedView()
            .onAppear {
                // Sound/Vibration 알림 Request Permission
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]) { granted, error in
                        if let error = error {
                            print("알림 Request Permission 오류: \(error)")
                        }
                    }
                configureMacWindowIfNeeded()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            #if targetEnvironment(macCatalyst)
            // macOS: 큰 화면에 맞춰 글자를 한 단계 키운다
            .environment(\.dynamicTypeSize, .xLarge)
            #endif
    }

    /// Mac(Catalyst)에서 타이머 앱에 어울리는 창 크기로 제약한다.
    private func configureMacWindowIfNeeded() {
        #if targetEnvironment(macCatalyst)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            // 타이머만 남는 컴팩트 창
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 300, height: 380)
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 460, height: 620)
            // 타이틀바를 콘텐츠와 통합해 군더더기 줄이기
            windowScene.titlebar?.titleVisibility = .hidden
            windowScene.titlebar?.toolbar = nil
        }
        #endif
    }
}
