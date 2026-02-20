//
//  AppStateManager.swift
//  Toki
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

    func sendNotificationIfNeeded(_ message: String) {
        // 백그라운드에서 알림 전송
        print("📱 [알림] sendNotificationIfNeeded 호출됨")
        print("   - 메시지: \(message)")
        print("   - 백그라운드 상태: \(isInBackground)")
        print("   - Notification Permission: \(notificationAuthStatus)")

        if isInBackground {
            print("   ✅ 백그라운드 상태 → 알림 전송 시도")
            pushPrealertNotice(message: message)
        } else {
            print("   ⚠️ 포그라운드 상태 → 알림 전송 안함")
        }
    }

    // 테스트용: 즉시 알림 전송
    func sendTestNotification() {
        print("🧪 [테스트] 테스트 알림 전송 Start")
        let content = UNMutableNotificationContent()
        content.title = AppName.notification
        content.body = "Notifications are working correctly! 🎉"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("   ❌ 테스트 알림 전송 실패: \(error)")
            } else {
                print("   ✅ 테스트 알림 전송 성공")
            }
        }
    }
}

private func pushPrealertNotice(message: String) {
    let pushEnabled = UserDefaults.standard.bool(forKey: "pushEnabled")
    print("📤 [알림 전송] pushPrealertNotice Start")
    print("   - pushEnabled: \(pushEnabled)")

    guard pushEnabled else {
        print("   ⚠️ pushEnabled가 꺼져있음 → 알림 전송 Cancel")
        return
    }

    let center = UNUserNotificationCenter.current()

    let content = UNMutableNotificationContent()
    content.title = AppName.notification
    content.body = message
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

    center.add(request) { error in
        if let error = error {
            print("   ❌ 알림 추가 실패: \(error)")
        } else {
            print("   ✅ 알림 추가 성공 (1sec later 전송)")
        }
    }
}
