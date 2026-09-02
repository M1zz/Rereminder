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
                    // ⚠️ 되풀이 알림 설정은 **아이폰이 주인**이다. 컨텍스트는 마지막 한 벌만
                    //    남으므로(타이머 상태가 덮어쓴다) 워치가 열릴 때 직접 물어봐야 한다 —
                    //    그러지 않으면 아이폰에서 켠 되풀이가 손목에서는 영영 꺼진 채로 돈다.
                    watchConnectivity.requestSettingsFromPhone()
                }
        }
    }

    private func setupNotifications() {
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // 알림에 정지·다시 알림 버튼을 붙인다 — 되풀이 알림을 손목에서 바로 끌 수 있어야 한다.
        EscalatingAlert.registerCategory()

        // Notification Permission 미리 요청
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
