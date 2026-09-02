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

    // MARK: - 설정 동기화 (되풀이 알림 · 소리/진동)

    /// 워치가 따라 읽어야 하는 설정 한 벌.
    ///
    /// ⚠️ **되풀이 알림과 소리 모드를 따로 보내지 말 것.** 예전에는 각각 따로 보냈는데,
    ///    `updateApplicationContext` 는 **가장 마지막 것 하나만** 워치에 전달한다. 그래서
    ///    설정을 바꾼 뒤 타이머를 한 번만 걸어도(그때 컨텍스트가 타이머 상태로 덮인다)
    ///    워치는 그 설정을 **영영 보지 못했다** — 손목에서 되풀이가 안 울리던 원인이다.
    nonisolated static var settingsPayload: [String: Any] {
        var payload = EscalationPolicy.current().syncPayload
        payload["ringMode"] = RingMode.current.rawValue
        return payload
    }

    /// 넘어온 설정을 이 기기에 적는다.
    ///
    /// ⚠️ **설정의 주인은 아이폰 하나다 — 방향을 뒤집지 말 것.** 워치도 이걸 적용하게 두면,
    ///    워치가 들고 있던 옛 값이 아이폰으로 되돌아가 사용자가 방금 고른 설정을 조용히 덮는다.
    @discardableResult
    nonisolated static func applySettingsPayload(_ payload: [String: Any]) -> Bool {
        #if os(iOS)
        return false
        #else
        var applied = EscalationPolicy.applySyncPayload(payload)
        if let ringMode = payload["ringMode"] as? String,
           RingMode(rawValue: ringMode) != nil {
            UserDefaults.standard.set(ringMode, forKey: "ringMode")
            applied = true
        }
        return applied
        #endif
    }

    /// 설정을 워치로 밀어 넣는다. 설정을 바꿀 때뿐 아니라 **세션이 살아날 때마다** 부른다 —
    /// 한 번만 보내고 마는 구조라 워치 앱을 나중에 깐 사람에게는 아무것도 닿지 않았다.
    func syncSettings() {
        #if !os(iOS)
        // 워치는 설정을 받기만 한다 (위 `applySettingsPayload` 주석 참고).
        return
        #else
        guard WCSession.isSupported() else { return }
        guard WCSession.default.isPaired,
              WCSession.default.activationState == .activated else { return }

        do {
            var context = WCSession.default.applicationContext
            for (key, value) in Self.settingsPayload { context[key] = value }
            try WCSession.default.updateApplicationContext(context)
        } catch {
            print("❌ 설정 동기화 실패: \(error.localizedDescription)")
        }
        #endif
    }

    /// 되풀이 알림 설정을 Watch로 동기화 (iPhone 에서 고르고 워치가 따라간다)
    func sendEscalationPolicy(_ policy: EscalationPolicy) {
        syncSettings()
    }

    /// iOS ringMode 설정을 Watch로 동기화
    func sendRingMode(_ mode: String) {
        syncSettings()
    }

    #if os(watchOS)
    /// **아이폰에 지금 설정을 물어본다.** 컨텍스트는 마지막 한 벌만 남으므로, 워치가 먼저
    /// 묻는 길이 없으면 "설정을 바꾼 뒤 워치 앱을 처음 연" 사람은 옛 설정으로 계속 돈다.
    func requestSettingsFromPhone() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }

        WCSession.default.sendMessage(["action": "requestSettings"]) { reply in
            Self.applySettingsPayload(reply)
        } errorHandler: { error in
            print("❌ 설정 요청 실패: \(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Application Context (백그라운드 동기화)

    /// Timer 상태를 Application Context로 전송 (백그라운드에서도 동작)
    func updateTimerContext(duration: TimeInterval?, remaining: TimeInterval?, state: String) {
        guard WCSession.isSupported() else { return }

        #if os(iOS)
        guard WCSession.default.isPaired else { return }
        #endif

        guard WCSession.default.activationState == .activated else { return }

        // ⚠️ **덮어쓰지 말고 얹는다.** `updateApplicationContext` 는 컨텍스트를 통째로 갈아치우고
        //    워치에는 마지막 한 벌만 전달되므로, 여기서 새 딕셔너리를 만들면 조금 전에 보낸
        //    되풀이 알림·소리 설정이 통째로 사라진다(워치는 그 설정을 영영 못 받는다).
        var context = WCSession.default.applicationContext
        #if os(iOS)
        for (key, value) in Self.settingsPayload { context[key] = value }
        #endif
        context["state"] = state
        context["timestamp"] = Date().timeIntervalSince1970

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
            // 세션이 살아난 지금이 설정을 밀어 넣을 자리다 — 설정 화면을 다시 열지 않는 사람에게도
            // 되풀이 알림 설정이 손목까지 가야 한다.
            syncSettings()
            #else
            // 워치는 반대로 **물어본다** — 마지막 컨텍스트가 타이머 상태였다면 설정은 안 실려 있다.
            requestSettingsFromPhone()
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
            #if os(watchOS)
            // 이제 막 닿았다 — 활성화 순간에는 못 물어봤을 수 있다.
            requestSettingsFromPhone()
            #endif
        }
    }

    #if os(iOS)
    /// 페어링·워치 앱 설치가 바뀐 순간 — 이걸 안 받으면 "앱 없음"이 영원히 남는다.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshLinkStatus()
            // 워치 앱이 방금 깔렸을 수도 있다 — 그 기기는 아직 아무 설정도 받은 적이 없다.
            syncSettings()
        }
    }
    #endif

    // MARK: - Receive Messages

    /// 답장을 기다리는 메시지 — 지금은 워치의 **설정 요청**뿐이다.
    /// ⚠️ 이 변형을 구현하지 않으면 `replyHandler` 를 단 `sendMessage` 는 상대에게 닿지 못하고
    ///    바로 실패한다(워치가 설정을 물어볼 길이 없어진다).
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        #if os(iOS)
        if message["action"] as? String == "requestSettings" {
            replyHandler(Self.settingsPayload)
            return
        }
        #endif
        replyHandler([:])
        self.session(session, didReceiveMessage: message)
    }

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
            case "requestSettings":
                syncSettings()
                return

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
            // 되풀이 알림 · 소리 모드 동기화 (한 벌로 들어온다)
            Self.applySettingsPayload(applicationContext)

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
    func syncSettings() {}
    func updateTimerContext(duration: TimeInterval?, remaining: TimeInterval?, state: String) {}
}

#endif

// MARK: - Data Models

struct TimerSyncData {
    let duration: TimeInterval
    let prealertOffsets: [Int]
    let timestamp: TimeInterval
}
