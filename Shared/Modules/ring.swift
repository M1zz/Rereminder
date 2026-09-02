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

    /// 지금 고른 방식. 저장 키(`ringMode`)는 iPhone·워치가 같은 것을 읽는다
    /// (`WatchConnectivityManager.sendRingMode` 로 넘어간다).
    static var current: RingMode {
        RingMode(rawValue: UserDefaults.standard.string(forKey: "ringMode") ?? "") ?? .sound
    }

    /// 진동 모드에서 알림에 싣는 **소리 없는** 사운드 파일 (`Shared/Silence.wav`).
    static let silentSoundResource = "Silence"
    static let silentSoundExtension = "wav"

    /// 현재 사용자 설정에 따른 알림 사운드.
    ///
    /// ⚠️ **진동 모드에서 `nil` 을 돌려주면 안 된다.** `UNNotificationContent.sound` 가 nil 이면
    ///    시스템은 그 알림을 **완전히 조용히** 전달한다 — 소리뿐 아니라 **진동·햅틱도 없다**
    ///    (알림 센터에 조용히 쌓이기만 한다). "진동"을 고른 사람이 손목에서도 주머니에서도
    ///    아무 반응을 못 받던 이유가 이것이다.
    ///
    /// 그래서 플랫폼마다 다르게 답한다:
    /// - **iOS**: 길이만 있고 소리는 없는 파일(`Silence.wav`). 시스템은 정상적으로 "울리는"
    ///   알림으로 취급해 진동을 주고, 귀에는 아무것도 들리지 않는다.
    /// - **watchOS**: 커스텀 알림음이 아예 없다(`UNNotificationSound(named:)` 이 unavailable).
    ///   그래서 `.default` 를 준다 — 애플워치는 **자기 무음 모드**가 소리/햅틱을 가르므로
    ///   이쪽이 "진동"에 맞는 동작이고, 무엇보다 **울리기는 한다.**
    static var notificationSound: UNNotificationSound? {
        guard current == .vibration else { return .default }
        #if os(watchOS)
        return .default
        #else
        // ⚠️ 번들에 파일이 없으면 시스템이 **기본 소리로 대체**한다 — 진동을 고른 사람에게
        //    소리가 나는 건 더 나쁘므로, 그때는 예전처럼 조용히 둔다.
        //    (App Clip 처럼 이 리소스가 없는 타겟이 있다.)
        guard hasSilentSound else { return nil }
        return UNNotificationSound(named: UNNotificationSoundName("\(silentSoundResource).\(silentSoundExtension)"))
        #endif
    }

    /// 무음 사운드가 이 번들에 실제로 들어 있나.
    static var hasSilentSound: Bool {
        Bundle.main.url(forResource: silentSoundResource, withExtension: silentSoundExtension) != nil
    }

    /// 앱이 **앞에 있을 때** 배너와 함께 소리까지 낼지.
    /// ⚠️ iOS 의 진동 모드에서 `.sound` 를 함께 주면 무음 파일이 재생될 뿐이라 아무 느낌이 없다 —
    ///    그 자리는 `ring()` 이 직접 진동을 울린다. 워치는 커스텀 음이 없어 `.default` 를 쓰므로
    ///    그대로 시스템에 맡긴다(무음 모드면 햅틱으로 나온다).
    static var presentsNotificationSound: Bool {
        #if os(watchOS)
        return true
        #else
        return current == .sound
        #endif
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
