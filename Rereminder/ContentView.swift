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
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
    }
}
