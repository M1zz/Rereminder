//
//  AppStateManager.swift
//  Rereminder
//
//  Created by 광로 on 9/13/25.
//

import SwiftUI
import UserNotifications

final class AppStateManager: ObservableObject {
    @Published private(set) var isInBackground: Bool = false
    @Published var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    func updateState(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isInBackground = false
            checkNotificationPermission()
        case .background, .inactive:
            isInBackground = true
        @unknown default:
            isInBackground = false
        }
    }

    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationAuthStatus = settings.authorizationStatus
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]) { granted, error in
                DispatchQueue.main.async {
                    self.checkNotificationPermission()
                }
            }
    }

    /// 백그라운드에서만 즉시 알림 전송 (포그라운드에서는 인앱 토스트 사용)
    /// 참고: TimerEngine이 백그라운드 알림을 UNNotificationRequest로 미리 스케줄하므로,
    /// 이 함수는 포그라운드→백그라운드 전환 직후 타이밍 이슈 대응용입니다.
    func sendNotificationIfNeeded(_ message: String) {
        guard isInBackground else { return }

        let pushEnabled = UserDefaults.standard.bool(forKey: "pushEnabled")
        guard pushEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = AppName.notification
        content.body = message
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 알림 추가 실패: \(error)")
            }
        }
    }

    // 테스트용: 즉시 알림 전송
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = AppName.notification
        content.body = "Notifications are working correctly! 🎉"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 테스트 알림 전송 실패: \(error)")
            }
        }
    }
}
