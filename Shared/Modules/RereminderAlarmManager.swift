//
//  RereminderAlarmManager.swift
//  Rereminder
//
//  **끌 때까지 크게 울리는 종료 알람** — AlarmKit(iOS 26).
//
//  왜 일반 알림으로는 안 되는가: `UNNotificationSound` 는 사용자의 알림 볼륨을 넘을 수 없고
//  무음 스위치·집중 모드에 그대로 막힌다. 소리 파일을 바꿔 봐야 *더 거슬리는* 것이지
//  *더 큰* 것이 아니다. AlarmKit 알람은 **알람 볼륨으로, 무음 모드와 집중 모드를 뚫고,
//  사용자가 정지를 누를 때까지** 전체 화면으로 울린다 — "쉬려면 일어나서 꺼야 한다"는
//  사용자의 요구에 정확히 답하는 유일한 정식 경로다.
//
//  ⚠️ **일반 알림을 대체하는 게 아니라 성공했을 때만 갈아탄다.** 예약은 비동기이고 권한이
//     없을 수도 있는데, 먼저 UN 알림을 지워 놓고 AlarmKit 예약이 실패하면 **종료 시각에
//     아무 데서도 울리지 않는다.** 그래서 순서가 정해져 있다 —
//     ① `TimerEngine` 이 늘 하던 대로 UN 종료·되풀이 알림을 깔고
//     ② AlarmKit 예약이 **성공한 뒤에야** 그것을 걷는다(`TimerEngine.adoptAlarmKitFinish`).
//     실패하면 아무것도 걷지 않으므로 예전 동작이 그대로 남는다.
//
//  ⚠️ 카운트다운은 AlarmKit 에 맡기지 않는다(`schedule: .fixed`). `AlarmConfiguration.timer` 를
//     쓰면 AlarmKit 이 **자기 Live Activity** 를 세우는데, 이 앱은 이미 제 것을 갖고 있어
//     같은 타이머가 잠금화면에 두 개 뜬다. AlarmKit 은 **울리는 순간**만 맡는다.
//

import Foundation

#if canImport(AlarmKit) && !targetEnvironment(macCatalyst) && !APPCLIP
import AlarmKit
import SwiftUI

@MainActor
final class RereminderAlarmManager: ObservableObject {

    static let shared = RereminderAlarmManager()

    /// 사용자가 설정에서 켰는지. ⚠️ 키 이름은 설정 화면(`NoticeSettingView`)과 같아야 한다.
    static let enabledKey = "useAlarmKit"

    @Published private(set) var authorizationState: AlarmManager.AuthorizationState = .notDetermined

    private let alarmManager = AlarmManager.shared

    /// 지금 걸어 둔 알람. AlarmKit 은 앱이 죽어도 살아 있으므로 **앱 그룹이 아니라 표준
    /// UserDefaults 에 남긴다** — 이 앱 프로세스만 걷으면 되고, cold launch 로 정지를 눌렀을 때도
    /// 지울 대상을 알아야 한다.
    private static let scheduledIDKey = "alarmKit.scheduledID"

    private var scheduledID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: Self.scheduledIDKey) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: Self.scheduledIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.scheduledIDKey)
            }
        }
    }

    private init() {
        authorizationState = alarmManager.authorizationState
    }

    // MARK: - 켜져 있나

    /// 설정에서 켰고, 권한도 있고, 이 기기에서 쓸 수 있나.
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledKey) && authorizationState == .authorized
    }

    /// 설정에서 켜기만 한 상태(권한은 아직 모를 수 있다).
    /// ⚠️ `nonisolated` — `TimerEngine` 은 메인 액터가 아니라서, 여기까지 격리하면
    ///    알람으로 갈아탈지 판단하는 자리에서 부를 수가 없다.
    nonisolated static var isPreferred: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    // MARK: - 권한

    func refreshAuthorizationState() {
        authorizationState = alarmManager.authorizationState
    }

    /// 권한을 묻는다. ⚠️ **설정에서 토글을 켜는 순간에 묻는다** — 타이머를 시작하는 순간에
    ///    시스템 권한 창을 띄우면 그 타이머는 이미 놓친 것이다.
    @discardableResult
    func requestAuthorization() async -> Bool {
        switch alarmManager.authorizationState {
        case .authorized:
            authorizationState = .authorized
            return true
        case .denied:
            authorizationState = .denied
            return false
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                authorizationState = state
                return state == .authorized
            } catch {
                print("❌ AlarmKit 권한 요청 실패: \(error.localizedDescription)")
                refreshAuthorizationState()
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - 예약

    /// 종료 시각에 울릴 알람을 건다.
    /// - Returns: 실제로 걸렸으면 `true`. **`false` 면 부르는 쪽은 UN 알림을 그대로 둬야 한다.**
    @discardableResult
    func scheduleFinishAlarm(at fireDate: Date, timerName: String?) async -> Bool {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return false }
        guard fireDate.timeIntervalSinceNow > 0 else { return false }
        guard await requestAuthorization() else { return false }

        // 이전 것을 남겨 두면 지난 타이머의 알람이 뒤늦게 운다.
        cancelFinishAlarm()

        let id = UUID()
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: .init(preAlert: nil, postAlert: TimeInterval(EscalatingAlert.snoozeMinutes * 60)),
            schedule: .fixed(fireDate),
            attributes: attributes(timerName: timerName),
            stopIntent: StopIntent(alarmID: id.uuidString),
            sound: .default
        )

        do {
            _ = try await alarmManager.schedule(id: id, configuration: configuration)
            scheduledID = id
            return true
        } catch {
            print("❌ AlarmKit 알람 예약 실패: \(error.localizedDescription)")
            return false
        }
    }

    /// 걸어 둔 알람을 걷는다 — 아직 울리기 전이면 취소, 울리는 중이면 정지.
    /// ⚠️ 둘 다 해야 한다. `cancel` 은 울리는 알람을 멈추지 못하고, `stop` 은 예약을 지우지 못한다.
    func cancelFinishAlarm() {
        guard let id = scheduledID else { return }
        try? alarmManager.stop(id: id)
        try? alarmManager.cancel(id: id)
        scheduledID = nil
    }

    // MARK: - 생김새

    /// ⚠️ 알람 화면에는 **카운트다운·일시정지 표시를 넣지 않는다**(`countdown`·`paused` 가 nil).
    ///    카운트다운은 앱이 제 Live Activity 로 이미 그리고 있어서, 여기까지 넣으면 같은 타이머가
    ///    잠금화면에 두 개로 뜬다.
    private func attributes(timerName: String?) -> AlarmAttributes<RereminderTimerData> {
        let title: LocalizedStringResource = "Time is up"
        let stop = AlarmButton(text: "Stop",
                               textColor: .white,
                               systemImageName: "stop.fill")
        let snooze = AlarmButton(text: "Snooze",
                                 textColor: .white,
                                 systemImageName: "moon.zzz.fill")

        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: title,
                                            secondaryButton: snooze,
                                            secondaryButtonBehavior: .countdown)
        } else {
            alert = AlarmPresentation.Alert(title: title,
                                            stopButton: stop,
                                            secondaryButton: snooze,
                                            secondaryButtonBehavior: .countdown)
        }

        return AlarmAttributes(presentation: AlarmPresentation(alert: alert),
                               metadata: RereminderTimerData(timerName: timerName),
                               tintColor: SharedAccent.color)
    }
}

#else

/// AlarmKit 이 없는 곳(Mac Catalyst·App Clip)용 no-op.
/// 부르는 쪽이 그대로 컴파일되도록 같은 API 를 둔다 — 언제나 "못 걸었다"고 답하므로
/// UN 알림 경로가 그대로 남는다.
@MainActor
final class RereminderAlarmManager: ObservableObject {
    static let shared = RereminderAlarmManager()
    static let enabledKey = "useAlarmKit"
    nonisolated static var isPreferred: Bool { false }

    private init() {}

    var isEnabled: Bool { false }
    func refreshAuthorizationState() {}
    @discardableResult
    func requestAuthorization() async -> Bool { false }
    @discardableResult
    func scheduleFinishAlarm(at fireDate: Date, timerName: String?) async -> Bool { false }
    func cancelFinishAlarm() {}
}

#endif
