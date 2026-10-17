//
//  NotificationOffNotice.swift
//  Rereminder
//
//  알림 권한이 꺼져 있다는 사실을 **메인 화면에서 주기적으로** 알린다(`NotificationOffBanner`).
//
//  왜: 이 앱의 전부가 "끝나기 전에 여러 번 알려 준다"인데, 권한이 꺼져 있으면 앱을 보는 동안에만
//  토스트·소리가 나고 **화면을 끄는 순간 아무것도 울리지 않는다.** 사용자는 앱이 잘 되는 줄 알다가
//  정작 필요한 순간에 놓치고, "잠금 화면이 울리지 않는다"는 제보로 돌아온다(2026-10-05).
//  설정 화면에만 경고가 있으면 아무도 보지 않는다.
//
//  ⚠️ **Pro 권유가 아니다** — 핵심 기능이 고장 난 상태를 알리는 것이라 `ProMention` 예산을 쓰지 않는다.
//     대신 이 한 줄이 서 있는 동안은 Pro 권유 한 줄(`RememberRecallLine`)이 물러난다
//     — 핵심 기능이 안 되는 사람에게 결제를 권하는 건 순서가 틀렸다.
//  ⚠️ 닫으면 `snoozeDays` 동안 쉬고 **다시 나온다.** 영영 닫게 두면 한 번 무심코 닫은 사람이
//     고장 난 채로 계속 쓴다. 반대로 매번 열 때마다 서 있으면 일부러 끈 사람에게 잔소리다.
//  ⚠️ 권한을 켜면 쉬는 기록도 지운다 — 나중에 다시 끄면 그날 바로 알려야 한다.
//  날짜는 `LocalDay` 로 센다(UTC 로 세면 한국에서는 오전 9시에 하루가 바뀐다).
//

import Foundation
import UserNotifications

enum NotificationOffNotice {

    /// 닫은 뒤 다시 나오기까지 쉬는 날수.
    static let snoozeDays = 3

    static let snoozedUntilKey = "notificationOffNotice.snoozedUntilDay"

    // MARK: - 판정 (순수 함수)

    static func shouldShow(authStatus: UNAuthorizationStatus, today: Int, snoozedUntilDay: Int?) -> Bool {
        guard authStatus == .denied else { return false }
        guard let until = snoozedUntilDay else { return true }
        return today >= until
    }

    // MARK: - 저장소를 쓰는 쪽

    static func shouldShow(authStatus: UNAuthorizationStatus,
                           now: Date = Date(),
                           defaults: UserDefaults = .standard) -> Bool {
        shouldShow(authStatus: authStatus,
                   today: LocalDay.stamp(now),
                   snoozedUntilDay: defaults.object(forKey: snoozedUntilKey) as? Int)
    }

    /// 사용자가 닫았다 — `snoozeDays` 뒤에 다시 나온다.
    static func dismiss(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(LocalDay.stamp(now) + snoozeDays, forKey: snoozedUntilKey)
    }

    /// 권한이 다시 켜졌으면 쉬는 기록을 지운다.
    static func resetIfAllowed(authStatus: UNAuthorizationStatus, defaults: UserDefaults = .standard) {
        switch authStatus {
        case .authorized, .provisional, .ephemeral:
            defaults.removeObject(forKey: snoozedUntilKey)
        default:
            break
        }
    }
}
