//
//  WatchTokiApp.swift
//  WatchToki Watch App
//
//  Created by 내꺼다 on 8/6/25.
//

import SwiftUI
import UserNotifications

@main
struct WatchToki_Watch_AppApp: App {
    @StateObject private var notificationDelegate = NotificationDelegate()
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    private let notificationService = NotificationService()

    init() {
        // WatchConnectivity 초기화
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
        
        // 알림 권한 미리 요청
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("워치 알림 권한 승인됨")
                } else {
                    print("워치 알림 권한 거부됨: \(error?.localizedDescription ?? "알 수 없는 오류")")
                }
            }
        }
    }
}
