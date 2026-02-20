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

            #if os(iOS)
            // iOS에서 페어링 상태만 로깅
            if !session.isPaired {
                print("ℹ️ Watch가 페어링되지 않음 (iOS 단독 실행 모드)")
            }
            #endif
        }
    }

    // MARK: - Send Messages

    /// Start Timer 메시지 전송
    func sendTimerStart(duration: TimeInterval, prealertOffsets: [Int]) {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else {
            return // Watch가 없어도 iOS는 정상 동작
        }
        #endif

        guard WCSession.default.isReachable else {
            return // 연결되지 않아도 조용히 무시
        }

        let message: [String: Any] = [
            "action": "start",
            "duration": duration,
            "prealertOffsets": prealertOffsets,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Start Timer 전송 실패: \(error.localizedDescription)")
        }

        print("✅ Watch로 Start Timer 전송: \(duration)sec")
    }

    /// Pause Timer 메시지 전송
    func sendTimerPause() {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else { return }
        #endif

        guard WCSession.default.isReachable else { return }

        let message = ["action": "pause"]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Pause Timer 전송 실패: \(error.localizedDescription)")
        }

        print("✅ Watch로 Pause Timer 전송")
    }

    /// Resume Timer 메시지 전송
    func sendTimerResume(remainingDuration: TimeInterval) {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else { return }
        #endif

        guard WCSession.default.isReachable else { return }

        let message: [String: Any] = [
            "action": "resume",
            "remainingDuration": remainingDuration,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Resume Timer 전송 실패: \(error.localizedDescription)")
        }

        print("✅ Watch로 Resume Timer 전송: \(remainingDuration)sec")
    }

    /// Timer Stop 메시지 전송
    func sendTimerStop() {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else { return }
        #endif

        guard WCSession.default.isReachable else { return }

        let message = ["action": "stop"]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ Timer Stop 전송 실패: \(error.localizedDescription)")
        }

        print("✅ Watch로 Timer Stop 전송")
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
            print("✅ Timer 상태 Context 업데이트: \(state)")
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
            } else {
                print("✅ WCSession 활성화 Done: \(activationState.rawValue)")
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WCSession 비활성화됨")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ WCSession 비활성화 Done")
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
            print("📡 Watch 연결 상태: \(session.isReachable ? "연결됨" : "연결 안 됨")")
        }
    }

    // MARK: - Receive Messages

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            guard let action = message["action"] as? String else { return }

            print("📩 메시지 수신: \(action)")

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
                print("⚠️ 알 수 없는 액션: \(action)")
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            print("📦 Application Context 수신: \(applicationContext)")
            // 필요시 처리
        }
    }
}

// MARK: - Data Models

struct TimerSyncData {
    let duration: TimeInterval
    let prealertOffsets: [Int]
    let timestamp: TimeInterval
}
