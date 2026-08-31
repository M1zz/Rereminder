//
//  EscalatingAlertTests.swift
//  RereminderTests
//
//  "확인할 때까지 알린다"는 **미리 깔아 둔 알림 여러 개**로 만든다(iOS 는 60초 미만 반복을
//  허용하지 않고, 앱이 꺼져 있으면 반복을 멈출 수도 없다). 그래서 이 계산이 틀리면 결과는
//  둘 중 하나다 — 한 번 울리고 마는 것(기능이 없는 것과 같다), 또는 상한 없이 울려서 사용자가
//  앱을 지우는 것. 여기서 지키는 건 그 사이의 정확한 개수와 시각이다.
//

import XCTest
@testable import Rereminder

final class EscalatingAlertTests: XCTestCase {

    private func policy(_ interval: AlertRepeatInterval,
                        _ duration: AlertRepeatDuration = .twoMinutes,
                        escalates: Bool = false) -> EscalationPolicy {
        EscalationPolicy(interval: interval, duration: duration, escalatesAcrossDevices: escalates)
    }

    // MARK: - 타이머를 직접 돌리는 기기

    /// 되풀이가 꺼져 있으면 아무것도 깔지 않는다 — 지금까지의 동작 그대로.
    func test_primary_withRepeatOff_schedulesNothing() {
        XCTAssertEqual(EscalationSchedule.offsets(policy: policy(.off), role: .primary), [])
    }

    /// 종료 순간의 알림은 타이머가 이미 예약했다 — 여기엔 **그 뒤의 것만** 나온다.
    func test_primary_repeatsFromOneIntervalAfterTheEnd() {
        XCTAssertEqual(EscalationSchedule.offsets(policy: policy(.thirtySeconds), role: .primary),
                       [30, 60, 90, 120])
        XCTAssertEqual(EscalationSchedule.offsets(policy: policy(.fifteenSeconds, .oneMinute), role: .primary),
                       [15, 30, 45, 60])
        XCTAssertEqual(EscalationSchedule.offsets(policy: policy(.oneMinute, .fiveMinutes), role: .primary),
                       [60, 120, 180, 240, 300])
    }

    /// ⚠️ 상한을 넘겨 울리면 그건 알림이 아니라 괴롭힘이다.
    func test_neverRingsPastTheChosenDuration() {
        for interval in AlertRepeatInterval.allCases {
            for duration in AlertRepeatDuration.allCases {
                let offsets = EscalationSchedule.offsets(policy: policy(interval, duration, escalates: true),
                                                         role: .primary)
                XCTAssertTrue(offsets.allSatisfy { $0 <= Double(duration.rawValue) },
                              "\(interval)/\(duration) 가 상한을 넘겼다: \(offsets)")
            }
        }
    }

    // MARK: - 뒤늦게 합류하는 기기

    func test_secondary_staysSilentWhenEscalationIsOff() {
        XCTAssertEqual(EscalationSchedule.offsets(policy: policy(.thirtySeconds), role: .secondary), [])
    }

    /// 손목이 먼저 울리고, 확인이 없으면 30초 뒤 이 기기가 합류한다.
    func test_secondary_joinsAfterTheCrossDeviceDelay() {
        let offsets = EscalationSchedule.offsets(
            policy: policy(.thirtySeconds, .twoMinutes, escalates: true), role: .secondary)
        XCTAssertEqual(offsets.first, EscalationSchedule.crossDeviceDelay)
        XCTAssertEqual(offsets, [30, 60, 90, 120])
    }

    /// 되풀이는 원치 않지만 "다른 기기로 번지기"만 켠 경우 — 합류 **한 번**으로 끝난다.
    func test_secondary_withRepeatOff_joinsExactlyOnce() {
        XCTAssertEqual(EscalationSchedule.offsets(
            policy: policy(.off, .twoMinutes, escalates: true), role: .secondary), [30])
    }

    /// 두 기기가 **동시에** 울면 "번진다"는 말이 성립하지 않는다.
    func test_secondaryAlwaysStartsLaterThanPrimary() {
        let config = policy(.fifteenSeconds, .fiveMinutes, escalates: true)
        let primary = EscalationSchedule.offsets(policy: config, role: .primary)
        let secondary = EscalationSchedule.offsets(policy: config, role: .secondary)
        XCTAssertLessThan(primary.first!, secondary.first!)
    }

    // MARK: - 예약 예산

    /// ⚠️ 알림 예약은 앱당 64개다. 넘치면 iOS 가 조용히 앞의 것을 버려 **종료 알림 자체가
    ///    사라진다.** 어떤 조합을 골라도 상한 안이어야 한다.
    func test_neverExceedsTheNotificationBudget() {
        for interval in AlertRepeatInterval.allCases {
            for duration in AlertRepeatDuration.allCases {
                for role in [EscalationRole.primary, .secondary] {
                    let count = EscalationSchedule.offsets(
                        policy: policy(interval, duration, escalates: true), role: role).count
                    XCTAssertLessThanOrEqual(count, EscalationSchedule.maxAlerts,
                                             "\(interval)/\(duration)/\(role) 가 \(count)개")
                }
            }
        }
    }

    // MARK: - 저장

    /// ⚠️ 켠 적 없는 사용자에게 되풀이 알림이 가면 그건 기능이 아니라 사고다.
    func test_defaultsToOff() {
        let store = temporaryDefaults()
        let loaded = EscalationPolicy.current(store)
        XCTAssertEqual(loaded.interval, .off)
        XCTAssertFalse(loaded.escalatesAcrossDevices)
        XCTAssertFalse(loaded.isActive)
        XCTAssertEqual(EscalationSchedule.offsets(policy: loaded, role: .primary), [])
    }

    func test_savesAndLoadsBack() {
        let store = temporaryDefaults()
        let saved = policy(.fifteenSeconds, .fiveMinutes, escalates: true)
        saved.save(to: store)
        XCTAssertEqual(EscalationPolicy.current(store), saved)
    }

    /// 워치로 넘어간 설정이 그대로 살아야 한다 — 한쪽만 바뀌면 손목과 주머니가 다르게 운다.
    func test_syncPayloadSurvivesTheTripToTheOtherDevice() {
        let store = temporaryDefaults()
        let sent = policy(.thirtySeconds, .oneMinute, escalates: true)
        XCTAssertTrue(EscalationPolicy.applySyncPayload(sent.syncPayload, to: store))
        XCTAssertEqual(EscalationPolicy.current(store), sent)
    }

    /// 모르는 표현이면 손대지 않는다(다른 목적의 context 가 설정을 지우면 안 된다).
    func test_unrelatedSyncPayloadIsIgnored() {
        let store = temporaryDefaults()
        policy(.thirtySeconds, escalates: true).save(to: store)
        XCTAssertFalse(EscalationPolicy.applySyncPayload(["ringMode": "sound"], to: store))
        XCTAssertEqual(EscalationPolicy.current(store).interval, .thirtySeconds)
    }

    // MARK: -

    private var suiteNames: [String] = []

    private func temporaryDefaults() -> UserDefaults {
        let name = "test.escalation.\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }
}
