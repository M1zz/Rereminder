//
//  NotificationService.swift
//  Rereminder
//
//  Created by 내꺼다 on 8/10/25.
//

import UserNotifications
#if canImport(WatchKit)
import WatchKit
#endif

struct NotificationService {
    func scheduleNotification(timeInterval: TimeInterval, title: String, body: String, identifier: String) {
        guard timeInterval > 0 else {
            print("알림 예약 실패: \(identifier) - 유효하지 않은 시간 간격 (\(timeInterval))")
            return
        }

        // 기존 알림 제거
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("알림 Request Permission 실패: \(error.localizedDescription)")
                return
            }

            if granted {
                let content = self.makeContent(title: title, body: body, identifier: identifier)

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                self.addRequest(request, identifier: identifier, timeDescription: "\(Int(timeInterval))sec later")
            } else {
                print("Notification permission denied.")
            }
        }
    }

    /// 새로 추가된 Date 기반 예약 함수
    func scheduleNotification(at date: Date, title: String, body: String, identifier: String) {
        // 기존 알림 제거
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("알림 Request Permission 실패: \(error.localizedDescription)")
                return
            }

            if granted {
                let content = self.makeContent(title: title, body: body, identifier: identifier)

                let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let dateString = formatter.string(from: date)
                self.addRequest(request, identifier: identifier, timeDescription: dateString)
            } else {
                print("Notification permission denied.")
            }
        }
    }

    // 공통 Content 생성
    private func makeContent(title: String, body: String, identifier: String) -> UNMutableNotificationContent {
        let isFinish = identifier == "main_timer_notification"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = RingMode.notificationSound
        content.badge = 1
        content.relevanceScore = 1.0
        if isFinish {
            // ⚠️ **종료 알림에도 카테고리를 붙여야** 정지·다시 알림 버튼이 달린다. 붙이지 않으면
            //    되풀이 알림(`EscalatingAlert`)에만 버튼이 있어서, 첫 알림에서 멈추려는 사람은
            //    끄는 법을 찾지 못하고 15초 뒤 두 번째 알림을 기다려야 했다.
            content.categoryIdentifier = EscalatingAlert.categoryIdentifier
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["haptic": "success"]
        } else {
            content.interruptionLevel = .active
            content.userInfo = ["haptic": "warning"]
        }
        return content
    }

    // 공통 Request 추가 처리
    private func addRequest(_ request: UNNotificationRequest, identifier: String, timeDescription: String) {
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 예약 실패: \(identifier) - \(error.localizedDescription)")
            } else {
                #if canImport(WatchKit)
                DispatchQueue.main.async {
                    WKInterfaceDevice.current().play(.click)
                }
                #endif
            }
        }
    }

    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

class NotificationDelegate: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    /// 알림의 정지·다시 알림 버튼, 그리고 알림 자체를 탭한 경우.
    /// ⚠️ 이게 없으면 되풀이 알림을 **멈출 방법이 앱을 열어 정지를 누르는 것뿐**이 된다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        EscalatingAlert.handle(response: response)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // ⚠️ **배너를 함께 줘야 한다.** 예전에는 `[.sound]` 뿐이라(진동 모드에서는 `[]`) 앱을 보고
        //    있는 동안 알림이 통째로 사라졌고, 그러면 정지·다시 알림 버튼에 닿을 길이 없어진다.
        var options: UNNotificationPresentationOptions = [.banner, .list]
        if RingMode.presentsNotificationSound { options.insert(.sound) }
        completionHandler(options)

        #if canImport(WatchKit)
        DispatchQueue.main.async {
            let hapticType = notification.request.content.userInfo["haptic"] as? String ?? "click"
            switch hapticType {
            case "success":
                WKInterfaceDevice.current().play(.success)
            case "warning":
                WKInterfaceDevice.current().play(.failure)
            default:
                WKInterfaceDevice.current().play(.click)
            }
        }
        #endif
    }
}
