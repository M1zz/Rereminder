//
//  EscalatingAlert.swift
//  Rereminder
//
//  "확인할 때까지 알린다" — 종료 알림을 한 번만 울리고 마는 대신, 사용자가 정지/다시 알림을
//  누를 때까지 되풀이한다.
//
//  왜 필요한가: 이 앱을 쓰는 이유는 **놓치면 안 되는 시간**이기 때문인데, 진동 한 번은
//  (특히 손목에서) 놓치기 쉽다. 놓친 알림은 알림이 아니라 없는 것과 같다.
//
//  ⚠️ **반복은 하나의 알림을 되풀이하는 게 아니라 여러 개를 미리 예약하는 것이다.**
//     `UNTimeIntervalNotificationTrigger(repeats:)` 는 60초 미만 간격을 허용하지 않고,
//     무엇보다 앱이 꺼져 있으면 반복을 멈출 방법이 없다. 그래서 종료 시각 기준으로 필요한 만큼
//     미리 깔아 두고, 확인하는 순간 남은 것을 전부 걷어낸다.
//
//  ⚠️ **예약은 앱당 64개가 상한이다.** 예비 알림도 같은 주머니를 쓰므로 반복 개수에 뚜껑
//     (`EscalationSchedule.maxAlerts`)을 씌운다. 넘치면 iOS 가 조용히 앞의 것을 버려서
//     **정작 중요한 종료 알림이 사라진다.**
//

import Foundation
import UserNotifications

// MARK: - 설정

/// 종료 알림을 몇 초 간격으로 다시 울릴지.
enum AlertRepeatInterval: Int, CaseIterable, Identifiable, Sendable {
    /// 한 번만 울린다(지금까지의 동작).
    case off = 0
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case oneMinute = 60

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .off:            return String(localized: "Alert once")
        case .fifteenSeconds: return String(localized: "Every 15 seconds")
        case .thirtySeconds:  return String(localized: "Every 30 seconds")
        case .oneMinute:      return String(localized: "Every minute")
        }
    }
}

/// 언제까지 되풀이할지. ⚠️ 상한을 두지 않으면 확인하지 못한 알림이 하루 종일 울린다.
enum AlertRepeatDuration: Int, CaseIterable, Identifiable, Sendable {
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneMinute:   return String(localized: "For 1 minute")
        case .twoMinutes:  return String(localized: "For 2 minutes")
        case .fiveMinutes: return String(localized: "For 5 minutes")
        }
    }
}

/// "확인할 때까지 알린다" 설정 한 벌.
struct EscalationPolicy: Equatable, Sendable {
    var interval: AlertRepeatInterval
    var duration: AlertRepeatDuration
    /// 확인이 없으면 **다른 기기**도 뒤늦게 합류시킬지.
    var escalatesAcrossDevices: Bool

    /// ⚠️ 기본값은 **꺼짐**이다. 이 앱은 잔소리가 되는 순간 지워지는 앱이라, 되풀이 알림은
    ///    스스로 켠 사람에게만 간다.
    static let off = EscalationPolicy(interval: .off,
                                      duration: .twoMinutes,
                                      escalatesAcrossDevices: false)

    /// 이 기기가 실제로 뭔가 되풀이하긴 하나.
    var isActive: Bool { interval != .off || escalatesAcrossDevices }
}

/// 이 기기가 알림 사슬에서 몇 번째인가.
enum EscalationRole: Sendable {
    /// 타이머를 직접 돌리는 기기 — 종료 순간 바로 울린다(그 첫 알림은 타이머가 이미 예약한다).
    case primary
    /// 다른 기기가 돌리고 있고, 확인이 없으면 뒤늦게 합류하는 기기.
    case secondary
}

// MARK: - 언제 울릴지 (순수 계산)

enum EscalationSchedule {

    /// 다른 기기가 합류하기까지 기다리는 시간. 손목이 먼저 울리고, 그래도 반응이 없으면 주머니가 운다.
    static let crossDeviceDelay: TimeInterval = 30

    /// 한 타이머가 깔 수 있는 되풀이 알림 수 상한 — 위 파일 주석의 64개 예산 때문이다.
    static let maxAlerts = 24

    /// **종료 시각으로부터 몇 초 뒤**에 다시 울릴지.
    ///
    /// - `primary`: 종료 순간의 알림은 타이머가 이미 예약했으므로 여기엔 없다. 간격만큼 뒤부터.
    /// - `secondary`: 합류 시각(`crossDeviceDelay`) 자체가 이 기기의 **첫** 알림이다.
    ///   되풀이가 꺼져 있어도 합류 한 번은 울린다 — 그게 "다른 기기로 번지기"의 전부다.
    static func offsets(policy: EscalationPolicy, role: EscalationRole) -> [TimeInterval] {
        let cap = TimeInterval(policy.duration.rawValue)
        let step = TimeInterval(policy.interval.rawValue)

        var next: TimeInterval
        switch role {
        case .primary:
            guard policy.interval != .off else { return [] }
            next = step
        case .secondary:
            guard policy.escalatesAcrossDevices else { return [] }
            next = crossDeviceDelay
        }

        var result: [TimeInterval] = []
        while next <= cap && result.count < maxAlerts {
            result.append(next)
            guard step > 0 else { break }   // 되풀이가 꺼진 secondary 는 합류 한 번으로 끝
            next += step
        }
        return result
    }
}

// MARK: - 알림 예약·취소

/// 되풀이 알림에 실을 내용.
///
/// ⚠️ **첫 종료 알림과 같은 말이어야 한다.** 예전에는 워치의 첫 알림만 영어 리터럴이라,
///    되풀이를 켜면 첫 알림은 영어로 뜨고 두 번째부터 한국어로 바뀌었다. 그래서 한 곳에 둔다.
struct AlertContent {
    let title: String
    let body: String
    let sound: UNNotificationSound?

    /// 이 앱의 종료 알림 문구 — iPhone·워치가 같은 것을 쓴다.
    static var timerFinished: AlertContent {
        AlertContent(title: AppName.notification,
                     body: String(localized: "Timer finished"),
                     sound: RingMode.notificationSound)
    }
}

enum EscalatingAlert {

    /// 종료 알림에 붙는 카테고리 — **버튼이 붙는 이유**다.
    /// ⚠️ 등록하지 않으면 확인할 방법이 "알림을 탭해 앱 열기"뿐이 된다.
    static let categoryIdentifier = "rereminder.timerFinished"
    static let stopActionIdentifier = "rereminder.alert.stop"
    static let snoozeActionIdentifier = "rereminder.alert.snooze"

    /// 되풀이 알림 식별자 앞머리 — 걷어낼 때 이 앞머리로 골라낸다.
    static let escalationPrefix = "rereminder.escalate."

    /// 종료 알림 자체의 식별자. iPhone(`TimerEngine`)과 워치(`NotificationService`)가 서로 다른
    /// 이름을 쓰고 있어 둘 다 적어 둔다 — 확인하면 **이미 떠 있는 것도** 치워야 하기 때문이다.
    static let finishIdentifiers = ["rereminder.timer.finish", "main_timer_notification"]

    /// "다시 알림"을 누르면 몇 분 뒤에 다시 부를지.
    static let snoozeMinutes = 5

    /// 알림 버튼(정지 / 다시 알림)을 등록한다. 앱이 뜰 때 한 번 부른다.
    static func registerCategory(center: UNUserNotificationCenter = .current()) {
        let stop = UNNotificationAction(identifier: stopActionIdentifier,
                                        title: String(localized: "Stop"),
                                        options: [.destructive])
        let snooze = UNNotificationAction(identifier: snoozeActionIdentifier,
                                          title: String(localized: "Snooze"),
                                          options: [])
        let category = UNNotificationCategory(identifier: categoryIdentifier,
                                              actions: [stop, snooze],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    /// 되풀이 알림을 깐다.
    /// - Parameter finishFireAfter: 지금부터 **종료까지** 남은 초. 되풀이는 그 뒤에 붙는다.
    static func schedule(policy: EscalationPolicy,
                         role: EscalationRole,
                         finishFireAfter: TimeInterval,
                         content alert: AlertContent = .timerFinished,
                         center: UNUserNotificationCenter = .current()) {
        for (index, offset) in EscalationSchedule.offsets(policy: policy, role: role).enumerated() {
            let fireAfter = finishFireAfter + offset
            guard fireAfter > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = alert.sound
            content.categoryIdentifier = categoryIdentifier
            // 놓치면 안 되는 알림이라 집중 모드를 뚫는다. 엔타이틀먼트가 없으면 조용히
            // `.active` 로 내려앉을 뿐 예약이 실패하지는 않는다.
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
            content.userInfo = ["haptic": "success"]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireAfter, repeats: false)
            let request = UNNotificationRequest(identifier: "\(escalationPrefix)\(index)",
                                                content: content,
                                                trigger: trigger)
            // ⚠️ 조용히 실패하면 안 되는 자리다 — 예약 예산(64개)을 넘겼거나 권한이 없으면
            //    사용자는 "켰는데 안 울린다"만 겪고 이유를 알 수 없다.
            center.add(request) { error in
                if let error { print("❌ 되풀이 알림 예약 실패(\(index)): \(error.localizedDescription)") }
            }
        }
    }

    /// 이 기기의 되풀이를 멈춘다 — **아직 오지 않은 것과 이미 떠 있는 것 둘 다.**
    /// ⚠️ 떠 있는 것을 안 치우면 정지를 눌러도 알림 목록에 그대로 남아 "안 먹혔다"로 읽힌다.
    static func cancel(center: UNUserNotificationCenter = .current()) {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(escalationPrefix) }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
        center.getDeliveredNotifications { delivered in
            let ids = delivered.map(\.request.identifier)
                .filter { $0.hasPrefix(escalationPrefix) || finishIdentifiers.contains($0) }
            if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
        }
    }

    /// **확인했다** — 이 기기의 되풀이를 멈추고 다른 기기에도 알린다.
    ///
    /// 알림 버튼(정지)·알림 탭·앱 안의 정지 버튼이 전부 여기로 들어온다.
    /// ⚠️ "어느 기기에서 눌러도 전부 멈춘다"가 이 기능의 약속이므로, 로컬만 끄는 경로를
    ///    따로 만들지 말 것 — 한쪽만 조용해지면 나머지 기기가 계속 울린다.
    static func acknowledgeEverywhere(center: UNUserNotificationCenter = .current()) {
        cancel(center: center)
        Task { @MainActor in
            WatchConnectivityManager.shared.sendAlertAcknowledged()
        }
    }

    /// 알림에서 온 반응을 처리한다.
    ///
    /// ⚠️ **정지든, 다시 알림이든, 그냥 탭이든 전부 "확인"으로 본다.** 알림을 탭해 앱을 열었는데
    ///    계속 울리면 그건 기능이 아니라 고장으로 읽힌다.
    /// ⚠️ 다시 알림은 **이 기기에서만** 다시 부른다 — 다른 기기에는 그냥 "멈춰"가 간다.
    ///    5분 뒤에 모든 기기가 한꺼번에 다시 우는 것보다, 미룬 사람의 기기 하나가 부르는 편이 낫다.
    static func handle(response: UNNotificationResponse,
                       content alert: AlertContent = .timerFinished,
                       center: UNUserNotificationCenter = .current()) {
        switch response.actionIdentifier {
        case snoozeActionIdentifier:
            snooze(policy: EscalationPolicy.current(), content: alert, center: center)
            Task { @MainActor in
                WatchConnectivityManager.shared.sendAlertAcknowledged()
            }
        default:
            acknowledgeEverywhere(center: center)
        }
    }

    /// "다시 알림" — 지금 것을 걷고 `snoozeMinutes` 뒤에 종료 알림부터 다시 깐다.
    static func snooze(policy: EscalationPolicy,
                       content alert: AlertContent = .timerFinished,
                       center: UNUserNotificationCenter = .current()) {
        cancel(center: center)

        let delay = TimeInterval(snoozeMinutes * 60)
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = alert.sound
        content.categoryIdentifier = categoryIdentifier
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["haptic": "success"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        center.add(UNNotificationRequest(identifier: "\(escalationPrefix)snooze",
                                         content: content,
                                         trigger: trigger))

        // 다시 부른 알림도 놓칠 수 있다 — 되풀이를 그 뒤에 다시 깐다.
        schedule(policy: policy,
                 role: .primary,
                 finishFireAfter: delay,
                 content: alert,
                 center: center)
    }
}

// MARK: - 저장

extension EscalationPolicy {

    private enum Key {
        static let interval = "alertRepeatInterval"
        static let duration = "alertRepeatDuration"
        static let escalate = "alertEscalateAcrossDevices"
    }

    /// 지금 설정. iPhone 에서 고르고 워치로 넘어간다(`WatchConnectivityManager.sendEscalationPolicy`).
    ///
    /// ⚠️ 저장된 값이 없거나 모르는 값이면 **꺼진 상태**로 본다 — 켠 적 없는 사용자에게
    ///    되풀이 알림이 가면 그건 기능이 아니라 사고다.
    static func current(_ defaults: UserDefaults = .standard) -> EscalationPolicy {
        EscalationPolicy(
            interval: AlertRepeatInterval(rawValue: defaults.integer(forKey: Key.interval)) ?? .off,
            duration: AlertRepeatDuration(rawValue: defaults.integer(forKey: Key.duration)) ?? .twoMinutes,
            escalatesAcrossDevices: defaults.bool(forKey: Key.escalate)
        )
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(interval.rawValue, forKey: Key.interval)
        defaults.set(duration.rawValue, forKey: Key.duration)
        defaults.set(escalatesAcrossDevices, forKey: Key.escalate)
    }

    /// 기기 사이로 넘길 때 쓰는 표현. 키 이름은 저장 키와 같게 두어 받는 쪽이 그대로 적는다.
    var syncPayload: [String: Any] {
        [Key.interval: interval.rawValue,
         Key.duration: duration.rawValue,
         Key.escalate: escalatesAcrossDevices]
    }

    /// 넘어온 표현을 저장한다. 아는 키가 하나도 없으면 아무것도 하지 않는다.
    @discardableResult
    static func applySyncPayload(_ payload: [String: Any],
                                 to defaults: UserDefaults = .standard) -> Bool {
        guard let interval = payload[Key.interval] as? Int,
              let duration = payload[Key.duration] as? Int,
              let escalate = payload[Key.escalate] as? Bool else { return false }
        defaults.set(interval, forKey: Key.interval)
        defaults.set(duration, forKey: Key.duration)
        defaults.set(escalate, forKey: Key.escalate)
        return true
    }
}
