//
//  DevicePresence.swift
//  Rereminder
//
//  "내 맥에서도 이 앱이 켜져 있나"를 iCloud로 확인하는 곳.
//
//  워치는 WatchConnectivity가 지금 통신되는지를 바로 알려주지만(`WatchConnectivityManager.linkStatus`),
//  맥은 아이폰에서 볼 방법이 없다. 그래서 각 기기가 앱을 쓰는 동안 iCloud 키-값 저장소에
//  **살아 있다는 표시**(기기 ID·종류·이름·시각)를 남기고, 다른 기기가 그걸 읽는다.
//
//  ⚠️ 여기서 말하는 "연결됨"은 **최근에 그 기기에서 앱이 켜져 있었다**는 뜻이다. 실시간 연결이
//     아니다(KVS는 앱을 깨우지 못한다). 그래서 창(`freshWindow`)은 심장박동 간격의 두 배로 둔다 —
//     한 번 놓쳤다고 "연결 안 됨"으로 깜빡이면 안 되기 때문이다.
//  ⚠️ 타이머 동기화(`CloudTimerSyncManager`)와 **같은 기기 ID**를 쓴다. 따로 만들면 같은 기기가
//     두 개로 보인다.
//

import Foundation

enum DevicePresence {

    // MARK: - 값

    /// 존재 표시를 남기는 기기 종류. (워치는 WatchConnectivity가 담당하므로 여기 없다.)
    enum Platform: String {
        case phone, mac, other
    }

    /// 한 기기가 남긴 표시.
    struct Entry: Equatable {
        let deviceID: String
        let platform: Platform
        let name: String
        let seenAt: Date
    }

    /// 화면에 보여줄 상태.
    enum Status: Equatable {
        /// 최근에 그 기기에서 앱이 켜져 있었다.
        case connected(name: String)
        /// 표시가 오래됐거나 아예 없다.
        case away(lastSeen: Date?)
    }

    /// 이 시간 안에 남긴 표시만 "연결됨"으로 본다.
    static let freshWindow: TimeInterval = 10 * 60
    /// 앱이 떠 있는 동안 표시를 새로 남기는 간격 — 창의 절반이라 한 번 놓쳐도 끊기지 않는다.
    static let heartbeatInterval: TimeInterval = 5 * 60

    // MARK: - 판정 (순수 함수)

    /// 그 종류의 기기 중 가장 최근 표시를 골라 상태를 만든다.
    /// - Parameter excluding: 이 기기 자신의 ID(자기 표시를 보고 "연결됨"이라 하지 않으려면 넘긴다).
    static func status(from entries: [Entry],
                       platform: Platform,
                       now: Date = Date(),
                       window: TimeInterval = freshWindow,
                       excluding deviceID: String? = nil) -> Status {
        let candidates = entries
            .filter { $0.platform == platform && $0.deviceID != deviceID }
            .sorted { $0.seenAt > $1.seenAt }

        guard let latest = candidates.first else { return .away(lastSeen: nil) }
        return now.timeIntervalSince(latest.seenAt) <= window
            ? .connected(name: latest.name)
            : .away(lastSeen: latest.seenAt)
    }

    // MARK: - iCloud 저장소

    private static let presenceKey = "devicePresence"
    /// ⚠️ `CloudTimerSyncManager` 가 쓰는 키와 같아야 한다 — 타이머 동기화 스냅샷을 증거로 읽는다.
    private static let syncSnapshotKey = "cloudTimerSnapshot"
    /// 이보다 오래된 표시는 지운다 — 예전에 쓰던 기기가 목록에 영원히 남지 않게.
    private static let pruneAfter: TimeInterval = 30 * 24 * 3600

    private static var store: NSUbiquitousKeyValueStore { .default }

    static var currentPlatform: Platform {
        Platform(rawValue: CloudTimerSyncManager.currentPlatform) ?? .other
    }

    /// iCloud에 남은 **두 가지 흔적**을 합쳐 기기 목록을 만든다.
    ///  ① `devicePresence` — 앱이 떠 있는 동안 5분마다 남기는 표시
    ///  ② `cloudTimerSnapshot` — 타이머 동기화가 남긴 마지막 스냅샷.
    ///     그 기기가 그 시각에 살아 있었다는 **증거**다.
    ///
    /// ②를 함께 보는 이유: 동기화는 멀쩡히 되는데 "연결 안 됨"이라고 말하면 거짓말이다.
    /// (①은 2.1.1부터 남는다 — 그 전 버전이 돌고 있는 기기는 ②로만 잡힌다.)
    /// ⚠️ 스냅샷에 `sourcePlatform`이 없으면 어느 종류의 기기인지 알 수 없어 세지 않는다.
    ///    (2.1.0 이하가 남긴 스냅샷 — 양쪽 다 올라오면 자연히 해결된다.)
    static func entries(presence: [String: Any]?, syncSnapshot: [String: Any]?) -> [Entry] {
        var result: [Entry] = []

        for (deviceID, value) in presence ?? [:] {
            guard let dict = value as? [String: Any],
                  let platform = Platform(rawValue: dict["platform"] as? String ?? ""),
                  let seenAt = dict["seenAt"] as? Double else { continue }
            result.append(Entry(deviceID: deviceID,
                                platform: platform,
                                name: dict["name"] as? String ?? "",
                                seenAt: Date(timeIntervalSince1970: seenAt)))
        }

        if let snapshot = syncSnapshot,
           let deviceID = snapshot["sourceDeviceID"] as? String,
           let platform = Platform(rawValue: snapshot["sourcePlatform"] as? String ?? ""),
           let updatedAt = snapshot["updatedAt"] as? Double {
            result.append(Entry(deviceID: deviceID,
                                platform: platform,
                                name: snapshot["sourceDeviceName"] as? String ?? "",
                                seenAt: Date(timeIntervalSince1970: updatedAt)))
        }
        return result
    }

    /// 지금 iCloud에 있는 흔적 전부.
    static func entries() -> [Entry] {
        entries(presence: store.dictionary(forKey: presenceKey),
                syncSnapshot: store.dictionary(forKey: syncSnapshotKey))
    }

    /// 다른 기기에서 본 이 기기 종류의 상태.
    static func status(of platform: Platform, now: Date = Date()) -> Status {
        // 자기 자신은 뺀다 — 아이폰에서 "맥 연결됨"을 물었을 때 답해야 할 것은 남의 기기다.
        status(from: entries(), platform: platform, now: now,
               excluding: CloudTimerSyncManager.deviceIdentifier)
    }

    // MARK: - 표시 남기기

    /// 앱이 앞에 있는 동안 주기적으로 표시를 남긴다. 여러 번 불러도 타이머는 하나만 돈다.
    @MainActor
    static func beginHeartbeat() {
        write()
        guard timer == nil else { return }
        // ⚠️ 이 앱에는 자체 `Timer` 모델(Shared/Models/Timer.swift)이 있다 — 반드시 Foundation.Timer.
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { _ in
            Task { @MainActor in write() }
        }
    }

    /// 앱이 뒤로 갔을 때 — 더는 "켜져 있다"고 말하지 않는다.
    ///
    /// ⚠️ 맥은 예외다. 메뉴 막대로 쓰는 앱이라 창이 뒤에 있어도 **쓰고 있는 중**이고,
    ///    여기서 멈추면 아이폰에서 "맥 연결 안 됨"으로 보인다.
    @MainActor
    static func endHeartbeat() {
        #if targetEnvironment(macCatalyst)
        return   // 맥에서는 앱이 살아 있는 동안 계속 표시를 남긴다
        #else
        timer?.invalidate()
        timer = nil
        #endif
    }

    @MainActor private static var timer: Foundation.Timer?

    private static func write(now: Date = Date()) {
        var all = store.dictionary(forKey: presenceKey) ?? [:]

        // 오래된 표시 정리 — 팔아버린 기기가 목록에 남아 있을 이유가 없다.
        all = all.filter { _, value in
            guard let dict = value as? [String: Any],
                  let seenAt = dict["seenAt"] as? Double else { return false }
            return now.timeIntervalSince(Date(timeIntervalSince1970: seenAt)) < pruneAfter
        }

        all[CloudTimerSyncManager.deviceIdentifier] = [
            "platform": currentPlatform.rawValue,
            "name": CloudTimerSyncManager.deviceDisplayName,
            "seenAt": now.timeIntervalSince1970,
        ]
        store.set(all, forKey: presenceKey)
        store.synchronize()
    }
}
