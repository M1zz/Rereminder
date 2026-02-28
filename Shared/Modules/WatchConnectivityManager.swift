//
//  WatchConnectivityManager.swift
//  Rereminder
//
//  iOS와 Apple Watch 간 Timer 상태 동기화
//

import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false

    // Timer 상태 수신 콜백
    var onTimerStart: ((TimerSyncData) -> Void)?
    var onTimerPause: (() -> Void)?
    var onTimerResume: (() -> Void)?
    var onTimerStop: (() -> Void)?

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self

            // 페어링 여부와 관계없이 activate는 항상 호출해야 함
            session.activate()
        }
    }

    // MARK: - Send Messages

    /// 공통 메시지 전송 (가드 + 에러 핸들링)
    private func send(_ message: [String: Any]) {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else { return }
        #endif

        guard WCSession.default.isReachable else { return }

        let action = message["action"] as? String ?? "unknown"
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ \(action) 전송 실패: \(error.localizedDescription)")
        }
    }

    func sendTimerStart(duration: TimeInterval, prealertOffsets: [Int]) {
        send([
            "action": "start",
            "duration": duration,
            "prealertOffsets": prealertOffsets,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendTimerPause() {
        send(["action": "pause"])
    }

    func sendTimerResume(remainingDuration: TimeInterval) {
        send([
            "action": "resume",
            "remainingDuration": remainingDuration,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendTimerStop() {
        send(["action": "stop"])
    }

    // MARK: - Application Context (백그라운드 동기화)

    /// Timer 상태를 Application Context로 전송 (백그라운드에서도 동작)
    func updateTimerContext(duration: TimeInterval?, remaining: TimeInterval?, state: String) {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else { return }
        #endif

        guard WCSession.default.activationState == .activated else { return }

        var context: [String: Any] = [
            "state": state,
            "timestamp": Date().timeIntervalSince1970
        ]

        if let duration = duration {
            context["duration"] = duration
        }

        if let remaining = remaining {
            context["remaining"] = remaining
        }

        do {
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("❌ Context 업데이트 실패: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("❌ WCSession 활성화 실패: \(error.localizedDescription)")
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    // MARK: - Receive Messages

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            guard let action = message["action"] as? String else { return }

            switch action {
            case "start":
                guard let duration = message["duration"] as? TimeInterval else { return }
                let prealertOffsets = message["prealertOffsets"] as? [Int] ?? []
                let timestamp = message["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970

                let syncData = TimerSyncData(
                    duration: duration,
                    prealertOffsets: prealertOffsets,
                    timestamp: timestamp
                )
                onTimerStart?(syncData)

            case "pause":
                onTimerPause?()

            case "resume":
                onTimerResume?()

            case "stop":
                onTimerStop?()

            default:
                break
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // 필요시 처리
    }
}

// MARK: - Data Models

struct TimerSyncData {
    let duration: TimeInterval
    let prealertOffsets: [Int]
    let timestamp: TimeInterval
}
