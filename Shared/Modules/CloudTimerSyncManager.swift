//
//  CloudTimerSyncManager.swift
//  Rereminder
//
//  iCloud Key-Value Store 기반 기기 간(iPhone ↔ Mac) 타이머 상태 동기화
//
//  설계:
//  - 타이머 상태 전체를 스냅샷 1개(cloudTimerSnapshot 키)로 저장, 최신 updatedAt 승리
//  - endDate를 절대 시각으로 전송 → 동기화 지연이 있어도 남은 시간 계산은 정확
//  - sourceDeviceID로 자기 기기가 보낸 스냅샷(에코)은 무시
//  - 수신 콜백은 TimerScreenViewModel에서만 등록 (WatchConnectivityManager와 동일 패턴)
//  - KVS는 앱을 깨우지 못하므로 cold launch 시 applyStoredSnapshotIfNeeded()로 보완
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct CloudTimerSnapshot {
    enum State: String {
        case running, paused, idle
    }

    let state: State
    let mainSeconds: Int
    let prealertOffsets: [Int]
    let name: String
    /// running일 때 타이머 종료 절대 시각
    let endDate: Date?
    /// paused일 때 남은 시간(초)
    let remaining: TimeInterval
    let updatedAt: Date
    let sourceDeviceName: String
}

@MainActor
final class CloudTimerSyncManager: ObservableObject {
    static let shared = CloudTimerSyncManager()

    /// 다른 기기에서 변경된 타이머 상태 수신 콜백
    var onRemoteSnapshot: ((CloudTimerSnapshot) -> Void)?

    private let store = NSUbiquitousKeyValueStore.default
    private static let snapshotKey = "cloudTimerSnapshot"
    private static let deviceIDKey = "cloudSyncDeviceID"

    private let deviceID: String

    /// 마지막으로 적용한 스냅샷 시각 — 같은 스냅샷의 중복 적용 방지
    private var lastAppliedAt: Date = .distantPast

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.deviceIDKey) {
            deviceID = saved
        } else {
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: Self.deviceIDKey)
            deviceID = id
        }

        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] note in
            let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            Task { @MainActor [weak self] in
                self?.handleExternalChange(changedKeys: changedKeys)
            }
        }
        store.synchronize()
    }

    // MARK: - Send

    func pushRunning(mainSeconds: Int, prealertOffsets: [Int], name: String, endDate: Date) {
        push(state: .running, mainSeconds: mainSeconds, prealertOffsets: prealertOffsets,
             name: name, endDate: endDate, remaining: 0)
    }

    func pushPaused(mainSeconds: Int, prealertOffsets: [Int], name: String, remaining: TimeInterval) {
        push(state: .paused, mainSeconds: mainSeconds, prealertOffsets: prealertOffsets,
             name: name, endDate: nil, remaining: remaining)
    }

    func pushIdle() {
        push(state: .idle, mainSeconds: 0, prealertOffsets: [], name: "", endDate: nil, remaining: 0)
    }

    private func push(state: CloudTimerSnapshot.State, mainSeconds: Int, prealertOffsets: [Int],
                      name: String, endDate: Date?, remaining: TimeInterval) {
        var dict: [String: Any] = [
            "state": state.rawValue,
            "mainSeconds": mainSeconds,
            "prealertOffsets": prealertOffsets,
            "name": name,
            "remaining": remaining,
            "updatedAt": Date().timeIntervalSince1970,
            "sourceDeviceID": deviceID,
            "sourceDeviceName": Self.currentDeviceName,
        ]
        if let endDate {
            dict["endDate"] = endDate.timeIntervalSince1970
        }
        store.set(dict, forKey: Self.snapshotKey)
        store.synchronize()
    }

    // MARK: - Receive

    private func handleExternalChange(changedKeys: [String]?) {
        if let changedKeys, !changedKeys.contains(Self.snapshotKey) { return }
        applyStoredSnapshotIfNeeded()
    }

    /// 현재 KVS에 저장된 최신 스냅샷을 읽어 콜백으로 전달
    /// cold launch 시(로컬 복원 이후)에도 호출해서 다른 기기의 마지막 상태를 반영한다
    func applyStoredSnapshotIfNeeded() {
        guard let dict = store.dictionary(forKey: Self.snapshotKey),
              let stateRaw = dict["state"] as? String,
              let state = CloudTimerSnapshot.State(rawValue: stateRaw),
              let updatedAtEpoch = dict["updatedAt"] as? Double else { return }

        guard (dict["sourceDeviceID"] as? String) != deviceID else { return }

        let updatedAt = Date(timeIntervalSince1970: updatedAtEpoch)
        guard updatedAt > lastAppliedAt else { return }
        lastAppliedAt = updatedAt

        let snapshot = CloudTimerSnapshot(
            state: state,
            mainSeconds: dict["mainSeconds"] as? Int ?? 0,
            prealertOffsets: dict["prealertOffsets"] as? [Int] ?? [],
            name: dict["name"] as? String ?? "",
            endDate: (dict["endDate"] as? Double).map(Date.init(timeIntervalSince1970:)),
            remaining: dict["remaining"] as? Double ?? 0,
            updatedAt: updatedAt,
            sourceDeviceName: dict["sourceDeviceName"] as? String ?? ""
        )
        onRemoteSnapshot?(snapshot)
    }

    private static var currentDeviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }
}
