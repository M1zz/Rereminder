//
//  WatchConnectivityManager.swift
//  Rereminder
//
//  iOS와 Apple Watch 간 Timer 상태 동기화
//

import Foundation

/// 워치와 이야기가 되는지 — 설정 화면의 "내 기기"와 타이머 화면의 칩이 심볼로 보여준다.
/// ⚠️ 플랫폼 가드 **밖**에 둔다. 워치가 없는 빌드(맥)에서도 화면 코드가 이 타입을 참조한다.
enum WatchLinkStatus: Equatable {
    /// 이 기기에서는 알 방법이 없다 (맥 등 WatchConnectivity 미지원).
    case unavailable
    /// 세션이 아직 활성화되지 않았다.
    case notReachable
    /// 페어링된 워치가 없다.
    case notPaired
    /// 워치는 있는데 이 앱이 워치에 없다 — 설치를 권할 자리.
    case appNotInstalled
    /// 워치가 있고 앱도 깔려 있다 — 타이머가 워치로 넘어간다.
    case connected

    /// 상태 판정 규칙 한 곳. (WCSession 없이도 검증할 수 있게 값만 받는다 — 테스트 대상)
    ///
    /// ⚠️ **`isReachable`을 여기에 넣지 말 것.** iOS에서 그 값은 "워치 앱이 지금 화면에 떠 있다"에
    ///    가깝다. 타이머 동기화는 `updateApplicationContext`로 워치 앱이 꺼져 있어도 넘어가는데,
    ///    도달성으로 판정하면 **동기화가 멀쩡히 되는 중에도 "연결 안 됨"** 이 뜬다(실제로 그랬다).
    ///    사용자가 알고 싶은 건 "지금 통신 중인가"가 아니라 "내 워치에서 볼 수 있나"다.
    static func resolve(isSupported: Bool,
                        isActivated: Bool,
                        isPaired: Bool,
                        isWatchAppInstalled: Bool) -> WatchLinkStatus {
        guard isSupported else { return .unavailable }
        guard isActivated else { return .notReachable }
        guard isPaired else { return .notPaired }
        guard isWatchAppInstalled else { return .appNotInstalled }
        return .connected
    }
}

// WatchConnectivity는 iOS(기기)·watchOS에만 존재. Mac Catalyst/macOS에는 없음.
// canImport는 Catalyst에서 모듈맵 때문에 true로 잘못 평가되므로 플랫폼을 명시적으로 가드한다.
#if os(watchOS) || (os(iOS) && !targetEnvironment(macCatalyst))
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false

    /// 워치와의 연결 상태 — 화면이 심볼로 읽는다. 활성화·도달성·페어링이 바뀔 때마다 갱신된다.
    @Published var linkStatus: WatchLinkStatus = .unavailable

    // Timer 상태 수신 콜백
    var onTimerStart: ((TimerSyncData) -> Void)?
    var onTimerPause: (() -> Void)?
    var onTimerResume: (() -> Void)?
    var onTimerStop: (() -> Void)?
    /// 다른 기기에서 종료 알림을 확인했다 — 이 기기의 되풀이도 멈춰야 한다.
    var onAlertAcknowledged: (() -> Void)?

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self

            // 페어링 여부와 관계없이 activate는 항상 호출해야 함
            session.activate()
        }
        refreshLinkStatus()
    }

    /// 지금 상태를 다시 읽는다 — 설정 화면을 열 때처럼 "지금 어떤지"가 필요한 순간에 부른다.
    func refreshLinkStatus() {
        guard WCSession.isSupported() else {
            linkStatus = .unavailable
            return
        }
        let session = WCSession.default
        isReachable = session.isReachable

        #if os(iOS)
        linkStatus = WatchLinkStatus.resolve(isSupported: true,
                                             isActivated: session.activationState == .activated,
                                             isPaired: session.isPaired,
                                             isWatchAppInstalled: session.isWatchAppInstalled)
        #else
        // 워치 쪽에서는 상대(아이폰)의 설치 여부를 물어볼 수 없다 — 활성화됐으면 이어진 것으로 본다.
        linkStatus = WatchLinkStatus.resolve(isSupported: true,
                                             isActivated: session.activationState == .activated,
                                             isPaired: true,
                                             isWatchAppInstalled: true)
        #endif
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

    /// **종료 알림을 확인했다**를 다른 기기에 알린다 — 거기서도 되풀이를 멈추라는 뜻.
    ///
    /// ⚠️ 두 경로로 보낸다. `sendMessage` 는 상대 앱이 지금 떠 있을 때만 닿고,
    ///    `transferUserInfo` 는 꺼져 있어도 **큐에 쌓였다가** 다음에 깨어날 때 전달된다.
    ///    후자만 쓰면 즉시성이 없고, 전자만 쓰면 주머니 속 폰에는 영영 닿지 않는다.
    ///    양쪽 다 받는 쪽에서 여러 번 와도 문제없다(멈추는 일은 여러 번 해도 같다).
    func sendAlertAcknowledged() {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else { return }
        #endif
        guard WCSession.default.activationState == .activated else { return }

        let payload: [String: Any] = ["action": "acknowledgeAlert",
                                      "timestamp": Date().timeIntervalSince1970]
        WCSession.default.transferUserInfo(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { error in
                print("❌ acknowledgeAlert 전송 실패: \(error.localizedDescription)")
            }
        }
    }

    /// 되풀이 알림 설정을 Watch로 동기화 (iPhone 에서 고르고 워치가 따라간다)
    func sendEscalationPolicy(_ policy: EscalationPolicy) {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired,
              WCSession.default.activationState == .activated else { return }
        #endif

        do {
            var context = WCSession.default.applicationContext
            for (key, value) in policy.syncPayload { context[key] = value }
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("❌ 되풀이 알림 설정 동기화 실패: \(error.localizedDescription)")
        }
    }

    /// iOS ringMode 설정을 Watch로 동기화
    func sendRingMode(_ mode: String) {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired,
              WCSession.default.activationState == .activated else { return }
        #endif

        do {
            var context = WCSession.default.applicationContext
            context["ringMode"] = mode
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("❌ ringMode 동기화 실패: \(error.localizedDescription)")
        }
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
        // WCSession 은 Sendable 이 아니라 Task 안으로 들고 들어갈 수 없다 — 필요한 값만 먼저 꺼낸다.
        #if os(iOS)
        let isPaired = session.isPaired
        #endif
        Task { @MainActor in
            if let error = error {
                print("❌ WCSession 활성화 실패: \(error.localizedDescription)")
            }
            refreshLinkStatus()
            #if os(iOS)
            // 워치가 페어링돼 있으면 "워치 있으세요?"를 물어볼 이유가 없다 — 아는 건 묻지 않는다.
            // (소유만 확정할 뿐 사용은 아니므로, 워치 앱을 권하는 안내는 그대로 나간다.)
            if isPaired { DeviceOwnership.confirmOwned(.watch) }
            #endif
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
            refreshLinkStatus()
        }
    }

    #if os(iOS)
    /// 페어링·워치 앱 설치가 바뀐 순간 — 이걸 안 받으면 "앱 없음"이 영원히 남는다.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshLinkStatus()
        }
    }
    #endif

    // MARK: - Receive Messages

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            guard let action = message["action"] as? String else { return }

            #if os(iOS)
            // 워치에서 온 조작 = 워치 앱을 실제로 쓰고 있다는 유일한 확실한 신호다.
            // (지금까지 아무도 남기지 않아 통계의 워치 사용 지표가 늘 0이었다.)
            DeviceOwnership.markUsed(.watch)
            AnalyticsManager.log(.watchSyncUsed)
            #endif

            switch action {
            case "acknowledgeAlert":
                EscalatingAlert.cancel()
                onAlertAcknowledged?()
                return

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

    /// 앱이 꺼져 있는 동안 쌓인 것도 여기로 온다 — "확인했다"가 반드시 닿아야 하는 경로.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            guard userInfo["action"] as? String == "acknowledgeAlert" else { return }
            EscalatingAlert.cancel()
            onAlertAcknowledged?()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            // 되풀이 알림 설정 동기화
            EscalationPolicy.applySyncPayload(applicationContext)

            // ringMode 동기화 (Watch에서 수신)
            if let ringMode = applicationContext["ringMode"] as? String {
                UserDefaults.standard.set(ringMode, forKey: "ringMode")
            }

            guard let state = applicationContext["state"] as? String else { return }

            switch state {
            case "running":
                if let duration = applicationContext["duration"] as? TimeInterval {
                    let prealertOffsets = applicationContext["prealertOffsets"] as? [Int] ?? []
                    let timestamp = applicationContext["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970
                    let syncData = TimerSyncData(duration: duration, prealertOffsets: prealertOffsets, timestamp: timestamp)
                    onTimerStart?(syncData)
                }
            case "paused":
                onTimerPause?()
            case "stopped", "idle":
                onTimerStop?()
            default:
                break
            }
        }
    }
}

#else

/// WatchConnectivity 미지원 플랫폼(Mac Catalyst/macOS)용 no-op 스텁.
/// 호출부가 그대로 컴파일되도록 동일한 공개 API를 제공한다.
@MainActor
final class WatchConnectivityManager: ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    /// 맥에는 WatchConnectivity가 없다 — 알 방법이 없으므로 화면에서도 상태를 감춘다.
    @Published var linkStatus: WatchLinkStatus = .unavailable

    func refreshLinkStatus() {}

    var onTimerStart: ((TimerSyncData) -> Void)?
    var onTimerPause: (() -> Void)?
    var onTimerResume: (() -> Void)?
    var onTimerStop: (() -> Void)?
    var onAlertAcknowledged: (() -> Void)?

    private init() {}

    func sendTimerStart(duration: TimeInterval, prealertOffsets: [Int]) {}
    func sendTimerPause() {}
    func sendTimerResume(remainingDuration: TimeInterval) {}
    func sendTimerStop() {}
    func sendRingMode(_ mode: String) {}
    func sendAlertAcknowledged() {}
    func sendEscalationPolicy(_ policy: EscalationPolicy) {}
    func updateTimerContext(duration: TimeInterval?, remaining: TimeInterval?, state: String) {}
}

#endif

// MARK: - Data Models

struct TimerSyncData {
    let duration: TimeInterval
    let prealertOffsets: [Int]
    let timestamp: TimeInterval
}
