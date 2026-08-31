//
//  AlertNotificationDelegate.swift
//  Rereminder
//
//  종료 알림의 버튼(정지·다시 알림)과 알림 탭을 받는 곳.
//
//  ⚠️ 이 델리게이트가 **없으면 iOS 는 알림 버튼을 눌러도 앱에 아무것도 전달하지 않는다.**
//     되풀이 알림이 확인되지 않아 상한(`AlertRepeatDuration`)까지 계속 울리고, 사용자는
//     알림을 끄는 법을 찾지 못한다. 2.2.2 까지 이 앱에는 알림 델리게이트가 아예 없었다.
//

import Foundation
import UserNotifications

final class AlertNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// ⚠️ `UNUserNotificationCenter.delegate` 는 **약한 참조**다. 지역 객체를 꽂으면 곧바로
    ///    사라져 아무것도 받지 못한다 — 그래서 싱글턴으로 붙들어 둔다.
    static let shared = AlertNotificationDelegate()

    /// 앱이 뜰 때 한 번 부른다.
    static func install(center: UNUserNotificationCenter = .current()) {
        center.delegate = shared
        EscalatingAlert.registerCategory(center: center)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        EscalatingAlert.handle(response: response, center: center)
        completionHandler()
    }

    /// 앱이 앞에 있을 때 무엇을 보여줄지.
    ///
    /// ⚠️ **종료·되풀이 알림만** 배너로 띄운다. 예비 알림까지 띄우면 타이머 화면을 보고 있는
    ///    내내 배너가 쏟아지는데, 그 숫자는 이미 화면에 있다(델리게이트가 없던 시절의 동작 =
    ///    앞에 있을 때 아무것도 안 띄움 — 예비 알림은 그대로 둔다).
    ///    반대로 종료 알림을 안 띄우면 앱을 보고 있다는 이유로 **정지 버튼에 닿을 길이 없어진다.**
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let identifier = notification.request.identifier
        let isFinishOrRepeat = identifier.hasPrefix(EscalatingAlert.escalationPrefix)
            || EscalatingAlert.finishIdentifiers.contains(identifier)

        guard isFinishOrRepeat else {
            completionHandler([])
            return
        }
        completionHandler(RingMode.notificationSound != nil ? [.banner, .sound] : [.banner])
    }
}
