//
//  LiveActivityCommand.swift
//  Rereminder
//
//  다이나믹 아일랜드 버튼(일시정지·재개·정지)이 앱에 닿는 길.
//
//  왜 필요한가 — 버튼의 인텐트(`LiveActivityIntent`)는 **앱 프로세스**에서 돈다. 다만 앱은
//  그 인텐트 때문에 백그라운드로 막 깨어난 참일 수 있고, 그러면 화면(=`TimerViewModel`)이
//  아직 없어서 `NotificationCenter` 로는 아무도 받지 못한다.
//
//  그래서 명령을 앱 그룹에 적어 둔다. 받을 사람이 있으면 NotificationCenter 로 즉시 반영되고
//  (받은 쪽이 이 기록을 지운다 — 그게 "처리했다"는 신호다), 없으면 다음에 앱이 앞으로 나올 때
//  이 기록을 읽어 그대로 적용한다.
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

    /// 남기고(앱이 화면을 아직 안 만들었어도) 알리고(살아 있으면 즉시) — 버튼이 해야 할 일의 절반이다.
    ///
    /// - Returns: **앱이 그 자리에서 진짜로 처리했으면 `true`.**
    ///   판정은 "받은 쪽이 기록을 지웠는가"로 한다(`TimerViewModel`의 옵저버가 지운다).
    ///   `NotificationCenter.post` 는 같은 스레드에서 동기로 돌기 때문에, 이 함수가 돌아온 시점이면
    ///   옵저버는 이미 다 돈 뒤다. `false` 면 나머지 절반(눈에 보이는 변화)은 호출부가
    ///   `LiveActivityController` 로 직접 만들어야 한다.
    @discardableResult
    func dispatch() -> Bool {
        LiveActivityCommandStore.post(self)
        NotificationCenter.default.post(name: notificationName, object: nil)
        return !LiveActivityCommandStore.isPending
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

    /// 아직 아무도 가져가지 않은 명령이 남아 있는가.
    static var isPending: Bool {
        defaults?.string(forKey: commandKey) != nil
    }

    static func clear() {
        defaults?.removeObject(forKey: commandKey)
        defaults?.removeObject(forKey: issuedAtKey)
    }
}
