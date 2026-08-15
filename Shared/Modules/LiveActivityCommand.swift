//
//  LiveActivityCommand.swift
//  Rereminder
//
//  다이나믹 아일랜드 버튼(일시정지·재개·정지)이 앱에 닿는 길.
//
//  왜 필요한가 — 버튼의 인텐트는 **위젯 확장 프로세스**에서 돈다(인텐트 타입이 확장 타겟에만 있다).
//  예전에는 거기서 `NotificationCenter.post` 를 했는데, 알림은 프로세스 경계를 넘지 못한다.
//  즉 앱이 떠 있든 아니든 그 버튼들은 **아무 일도 하지 않았다.**
//
//  그래서 명령을 앱 그룹에 적어 둔다. 앱이 이미 떠 있으면 NotificationCenter 로 즉시 반영되고,
//  꺼져 있었다면 다음에 앱이 앞으로 나올 때 이 기록을 읽어 그대로 적용한다.
//
//  ⚠️ 앱과 위젯 확장 양쪽에서 컴파일된다 — UIKit/SwiftUI 를 끌어들이지 말 것.
//

import Foundation

enum LiveActivityCommand: String, Codable {
    case pause
    case resume
    case stop

    /// 앱이 이미 실행 중일 때 즉시 전달되는 알림 이름 (같은 프로세스 안에서만 유효)
    var notificationName: Notification.Name {
        switch self {
        case .pause:  return Notification.Name("PauseTimerIntent")
        case .resume: return Notification.Name("ResumeTimerIntent")
        case .stop:   return Notification.Name("StopTimerIntent")
        }
    }

    /// 남기고(앱이 꺼져 있어도) 알리고(떠 있으면 즉시) — 버튼이 해야 할 일의 절반이다.
    /// 나머지 절반(화면에 보이는 변화)은 호출부가 LiveActivityController 로 처리한다.
    func dispatch() {
        LiveActivityCommandStore.post(self)
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
}

enum LiveActivityCommandStore {
    private static let suiteName = "group.leeo.toki"
    private static let commandKey = "liveActivity.pendingCommand"
    private static let issuedAtKey = "liveActivity.pendingCommandAt"

    /// 너무 오래된 명령은 버린다 — 어제 눌러 둔 "정지"가 오늘 시작한 타이머를 끄면 안 된다.
    static let expiry: TimeInterval = 10 * 60

    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    /// 확장(버튼)에서 명령을 남긴다.
    static func post(_ command: LiveActivityCommand, at date: Date = Date()) {
        defaults?.set(command.rawValue, forKey: commandKey)
        defaults?.set(date.timeIntervalSince1970, forKey: issuedAtKey)
    }

    /// 앱에서 꺼내 쓴다 — **한 번 읽으면 지운다**(같은 명령이 두 번 적용되지 않게).
    static func take(now: Date = Date()) -> LiveActivityCommand? {
        guard let raw = defaults?.string(forKey: commandKey),
              let command = LiveActivityCommand(rawValue: raw) else { return nil }

        let issuedAt = defaults?.double(forKey: issuedAtKey) ?? 0
        clear()

        guard issuedAt > 0, now.timeIntervalSince1970 - issuedAt <= expiry else { return nil }
        return command
    }

    static func clear() {
        defaults?.removeObject(forKey: commandKey)
        defaults?.removeObject(forKey: issuedAtKey)
    }
}
