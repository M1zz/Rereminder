//
//  FeatureSettingsTests.swift
//  RereminderTests
//
//  제보로 들어온 세 요청("크게 울려 달라", "끌 때까지 반복해 달라", "다이얼에 진동을 달라")이
//  **설정으로 켜고 끌 수 있어야** 한다는 약속을 지킨다.
//

import XCTest
@testable import Rereminder

final class FeatureSettingsTests: XCTestCase {

    private var suiteNames: [String] = []

    private func temporaryDefaults() -> UserDefaults {
        let name = "test.featureSettings.\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        for name in suiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
        suiteNames.removeAll()
        UserDefaults.standard.removeObject(forKey: Haptics.enabledKey)
        UserDefaults.standard.removeObject(forKey: RereminderAlarmManager.enabledKey)
        super.tearDown()
    }

    // MARK: - 햅틱

    /// ⚠️ **기본값은 켜짐이다.** iOS 에서 다이얼을 돌리면 딸깍하는 것이 기본 기대치라,
    ///    없는 것이 기능 부재가 아니라 **결함**으로 읽혔다("Haptics are needed when adjusting timer").
    func test_hapticsAreOnByDefault() {
        UserDefaults.standard.removeObject(forKey: Haptics.enabledKey)
        XCTAssertTrue(Haptics.isEnabled)
    }

    /// 끌 수 있어야 한다 — 강의 중에 손목이 계속 떨리면 그건 방해다.
    func test_hapticsCanBeTurnedOff() {
        UserDefaults.standard.set(false, forKey: Haptics.enabledKey)
        XCTAssertFalse(Haptics.isEnabled)

        UserDefaults.standard.set(true, forKey: Haptics.enabledKey)
        XCTAssertTrue(Haptics.isEnabled)
    }

    // MARK: - 전체 알람

    /// ⚠️ **기본값은 꺼짐이어야 한다.** 무음 모드와 집중 모드를 뚫고 알람 볼륨으로 우는
    ///    전체 화면 알람이 기본으로 켜져 있으면, 회의 중에 타이머를 건 사람에게 그건 사고다.
    func test_fullAlarmIsOffByDefault() {
        UserDefaults.standard.removeObject(forKey: RereminderAlarmManager.enabledKey)
        XCTAssertFalse(RereminderAlarmManager.isPreferred)
    }

    func test_fullAlarmFollowsTheSetting() {
        UserDefaults.standard.set(true, forKey: RereminderAlarmManager.enabledKey)
        XCTAssertTrue(RereminderAlarmManager.isPreferred)

        UserDefaults.standard.set(false, forKey: RereminderAlarmManager.enabledKey)
        XCTAssertFalse(RereminderAlarmManager.isPreferred)
    }

    // MARK: - 되풀이 알림

    /// 소개 화면(`FeatureIntroView`)과 설정 화면(`PersistentAlertSection`)은 **같은 키**를 본다.
    /// 갈라지면 한쪽에서 켠 것이 다른 쪽에서 꺼진 것으로 보인다.
    func test_repeatSettingIsSharedBetweenBothScreens() {
        let store = temporaryDefaults()
        EscalationPolicy(interval: .fifteenSeconds,
                         duration: .oneMinute,
                         escalatesAcrossDevices: true).save(to: store)

        XCTAssertEqual(store.integer(forKey: "alertRepeatInterval"), 15)
        XCTAssertEqual(store.integer(forKey: "alertRepeatDuration"), 60)
        XCTAssertTrue(store.bool(forKey: "alertEscalateAcrossDevices"))
        XCTAssertEqual(EscalationPolicy.current(store).interval, .fifteenSeconds)
    }
}
