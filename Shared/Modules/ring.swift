//
//  ring.swift
//  Rereminder
//
//  Created by xa on 8/28/25.
//

import Foundation
import UserNotifications

enum RingMode: String, CaseIterable, Identifiable {
    case sound = "sound"
    case vibration = "vibration"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sound:
            return String(localized: "Sound")
        case .vibration:
            return String(localized: "Vibration")
        }
    }

    /// 현재 사용자 설정에 따른 알림 사운드 반환 (진동 모드면 nil)
    static var notificationSound: UNNotificationSound? {
        let mode = UserDefaults.standard.string(forKey: "ringMode") ?? RingMode.sound.rawValue
        return mode == RingMode.vibration.rawValue ? nil : .default
    }

    /// 기존 한국어 rawValue("소리"/"진동")를 영어로 마이그레이션
    static func migrateIfNeeded() {
        let key = "ringMode"
        guard let stored = UserDefaults.standard.string(forKey: key) else { return }
        switch stored {
        case "소리":
            UserDefaults.standard.set(RingMode.sound.rawValue, forKey: key)
        case "진동":
            UserDefaults.standard.set(RingMode.vibration.rawValue, forKey: key)
        default:
            break
        }
    }
}
