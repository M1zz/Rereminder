//
//  DevicePresenceTests.swift
//  RereminderTests
//
//  "연결됨/연결 안 됨"을 무엇으로 판단하는지의 검증.
//
//  여기가 틀리면 앱이 사용자에게 거짓말을 한다 — 실제로 워치·맥으로 타이머가 잘 넘어가고 있는데도
//  "연결 안 됨"이라고 우기던 문제가 그래서 났다.
//

import XCTest
@testable import Rereminder

final class DevicePresenceTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - 워치

    /// **도달성(isReachable)으로 판단하지 않는다.** 그 값은 "워치 앱이 지금 화면에 떠 있다"에
    /// 가까운데, 타이머는 워치 앱이 꺼져 있어도 넘어간다(applicationContext).
    func test_watchStatus_isConnectedWhenPairedAndInstalled() {
        XCTAssertEqual(WatchLinkStatus.resolve(isSupported: true, isActivated: true,
                                               isPaired: true, isWatchAppInstalled: true),
                       .connected,
                       "페어링 + 앱 설치면 연결됨이다 — 워치 앱이 지금 떠 있는지는 묻지 않는다")
    }

    func test_watchStatus_tellsWhichPieceIsMissing() {
        XCTAssertEqual(WatchLinkStatus.resolve(isSupported: true, isActivated: true,
                                               isPaired: true, isWatchAppInstalled: false),
                       .appNotInstalled)
        XCTAssertEqual(WatchLinkStatus.resolve(isSupported: true, isActivated: true,
                                               isPaired: false, isWatchAppInstalled: false),
                       .notPaired)
        XCTAssertEqual(WatchLinkStatus.resolve(isSupported: true, isActivated: false,
                                               isPaired: true, isWatchAppInstalled: true),
                       .notReachable)
        XCTAssertEqual(WatchLinkStatus.resolve(isSupported: false, isActivated: false,
                                               isPaired: false, isWatchAppInstalled: false),
                       .unavailable,
                       "맥처럼 물어볼 수 없는 기기는 '연결 안 됨'이 아니라 '알 수 없음'이다")
    }

    // MARK: - 맥 (iCloud에 남은 흔적)

    private func presenceDict(id: String, platform: String, name: String, at: Date) -> [String: Any] {
        [id: ["platform": platform, "name": name, "seenAt": at.timeIntervalSince1970]]
    }

    func test_entries_readsHeartbeatMarks() {
        let entries = DevicePresence.entries(
            presence: presenceDict(id: "mac-1", platform: "mac", name: "MacBook", at: now),
            syncSnapshot: nil
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.platform, .mac)
        XCTAssertEqual(entries.first?.name, "MacBook")
    }

    /// 심장박동 표시가 없어도(구버전) **타이머 동기화 스냅샷**이 그 기기가 살아 있었다는 증거다.
    /// 이게 없으면 "동기화는 되는데 연결 안 됨"이 된다.
    func test_entries_countsTimerSyncSnapshotAsEvidence() {
        let entries = DevicePresence.entries(
            presence: nil,
            syncSnapshot: [
                "sourceDeviceID": "mac-1",
                "sourceDeviceName": "MacBook",
                "sourcePlatform": "mac",
                "updatedAt": now.timeIntervalSince1970,
            ]
        )
        XCTAssertEqual(entries.map(\.platform), [.mac])

        let status = DevicePresence.status(from: entries, platform: .mac, now: now)
        XCTAssertEqual(status, .connected(name: "MacBook"))
    }

    func test_entries_ignoresSnapshotWithoutPlatform() {
        // 2.1.0 이하가 남긴 스냅샷 — 어느 종류의 기기인지 알 수 없으니 세지 않는다
        let entries = DevicePresence.entries(
            presence: nil,
            syncSnapshot: [
                "sourceDeviceID": "unknown-1",
                "sourceDeviceName": "누군가의 기기",
                "updatedAt": now.timeIntervalSince1970,
            ]
        )
        XCTAssertTrue(entries.isEmpty)
    }

    func test_status_ignoresThisDeviceItself() {
        let entries = DevicePresence.entries(
            presence: presenceDict(id: "me", platform: "mac", name: "이 맥", at: now),
            syncSnapshot: nil
        )
        XCTAssertEqual(DevicePresence.status(from: entries, platform: .mac, now: now, excluding: "me"),
                       .away(lastSeen: nil),
                       "아이폰에서 '맥 연결됨'을 물었을 때 답해야 할 것은 남의 기기다")
    }

    func test_status_goesAwayAfterTheWindowButRemembersWhen() {
        let lastSeen = now.addingTimeInterval(-DevicePresence.freshWindow - 60)
        let entries = DevicePresence.entries(
            presence: presenceDict(id: "mac-1", platform: "mac", name: "MacBook", at: lastSeen),
            syncSnapshot: nil
        )
        XCTAssertEqual(DevicePresence.status(from: entries, platform: .mac, now: now),
                       .away(lastSeen: lastSeen))
    }

    func test_status_picksTheMostRecentEvidence() {
        var presence = presenceDict(id: "mac-1", platform: "mac", name: "옛날 표시",
                                    at: now.addingTimeInterval(-DevicePresence.freshWindow - 600))
        presence["mac-2"] = ["platform": "mac", "name": "방금 쓴 맥",
                             "seenAt": now.timeIntervalSince1970]
        let entries = DevicePresence.entries(presence: presence, syncSnapshot: nil)

        XCTAssertEqual(DevicePresence.status(from: entries, platform: .mac, now: now),
                       .connected(name: "방금 쓴 맥"))
    }
}
