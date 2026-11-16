//
//  PhoneSetups.swift
//  Rereminder
//
//  **아이폰에서 맞춘 설정을 손목에서 그대로 쓰고 고친다.**
//  제보(2026-11-16, 포르투갈어): "아이폰에서 프로그래밍한 것을 시계에서 문제없이 쓰거나 고칠 수 있으면 좋겠다."
//  그 전까지 워치는 시간·알림을 처음부터 다시 골라야 했다 — 아이폰에 저장한 설정이 손목에 하나도 없었다.
//
//  흐름: 아이폰이 저장한 설정(🔖)과 지금 다이얼을 가볍게 적어 설정 payload 에 얹는다
//  (`WatchConnectivityManager.settingsPayload`). 워치는 받아서 제 기기에 적고, 목록에서 고르면
//  알림 화면이 그 값으로 채워진 채 열린다 — 거기서 종을 더하거나 빼고 시작한다.
//
//  ⚠️ 방향은 아이폰 → 워치 하나다. 워치에서 고친 것은 그 실행에만 쓰이고 아이폰 템플릿을 덮지 않는다
//     (설정 payload 와 같은 규칙: 주인은 아이폰).
//  ⚠️ `updateApplicationContext` 는 마지막 한 벌만 남는다. 그래서 따로 보내지 않고 설정 payload 에 얹는다.
//  아이폰 앱·워치 앱 양쪽에서 컴파일된다(pbxproj 의 워치 예외 목록에 이 파일이 있다).
//

import Foundation

struct PhoneSetup: Codable, Hashable, Identifiable {
    /// 템플릿 id. 지금 다이얼은 `currentDialID`.
    let id: String
    /// 아이폰 언어로 만든 이름. 지금 다이얼은 비어 있고 워치가 제 언어로 이름을 붙인다.
    let name: String
    let mainSeconds: Int
    /// 끝나기 몇 초 전
    let offsets: [Int]
    /// 반복 횟수(`RoundSchedule`). 옛 아이폰이 보낸 것에는 없다(nil = 한 번).
    var rounds: Int? = nil

    static let currentDialID = "iphone.currentDial"
    var isCurrentDial: Bool { id == Self.currentDialID }
}

enum PhoneSetups {
    static let payloadKey = "phoneSetups.v1"
    /// 워치가 받은 목록을 적어 두는 자리(워치의 `UserDefaults.standard`).
    private static let storageKey = "phoneSetups.received.v1"

    /// 아이폰 앱이 채운다. 설정 payload 가 이것을 싣는다.
    /// 아직 채우지 않았으면(앱이 막 떴을 때) payload 에 키를 넣지 않는다 — 넣으면 워치의 목록을 빈 값으로 덮는다.
    nonisolated(unsafe) static var outgoing: [PhoneSetup]?

    static func encode(_ setups: [PhoneSetup]) -> Data? {
        try? JSONEncoder().encode(setups)
    }

    static func decode(_ data: Data) -> [PhoneSetup]? {
        guard let setups = try? JSONDecoder().decode([PhoneSetup].self, from: data) else { return nil }
        // 다른 버전의 기기가 보낸 값은 문에서 거른다
        return setups.compactMap { setup in
            guard setup.mainSeconds > 0, setup.mainSeconds <= 86_400 else { return nil }
            let offsets = setup.offsets.filter { $0 > 0 && $0 < setup.mainSeconds }
            return PhoneSetup(id: setup.id, name: setup.name, mainSeconds: setup.mainSeconds,
                              offsets: Array(Set(offsets)).sorted(by: >),
                              rounds: setup.rounds.map { min(99, max(1, $0)) })
        }
    }

    // MARK: - 워치 쪽 저장

    static var received: [PhoneSetup] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return decode(data) ?? []
    }

    /// 받은 payload 를 적는다. 목록이 들어 있었으면 참.
    @discardableResult
    static func store(from payload: [String: Any]) -> Bool {
        guard let data = payload[payloadKey] as? Data, decode(data) != nil else { return false }
        UserDefaults.standard.set(data, forKey: storageKey)
        NotificationCenter.default.post(name: .phoneSetupsChanged, object: nil)
        return true
    }
}

extension Notification.Name {
    static let phoneSetupsChanged = Notification.Name("rereminder.phoneSetupsChanged")
}
