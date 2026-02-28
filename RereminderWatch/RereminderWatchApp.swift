//
//  RereminderWatchApp.swift
//  Rereminder Watch App
//
//  Created by 내꺼다 on 8/6/25.
//

import SwiftUI
import UserNotifications

@main
struct RereminderWatchApp: App {
    @StateObject private var notificationDelegate = NotificationDelegate()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    private let notificationService = NotificationService()

    init() {
        // WatchConnectivity sec기화
        _ = WatchConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            SettingView()
                .environmentObject(watchConnectivity)
                .onAppear {
                    setupNotifications()
                }
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        
        // Notification Permission 미리 요청
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
