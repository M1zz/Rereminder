//
//  LastUsedConfigRestoreTests.swift
//  RereminderTests
//
//  앱 재실행 시 마지막 사용 타이머 설정 복원 리그레션 테스트
//  - 타이머 시작(applyCurrentSettings/apply(template:)) 시 설정이 UserDefaults에 저장되고
//  - 새 인스턴스에서 restoreLastUsedConfigIfNeeded()가 다이얼 상태를 복원해야 한다
//

import XCTest
@testable import Rereminder

@MainActor
final class LastUsedConfigRestoreTests: XCTestCase {

    private let storageKey = "rereminder.lastUsedConfig.v1"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
        clearSharedTimerState()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        clearSharedTimerState()
        super.tearDown()
    }

    /// 앱 그룹에 남아 있는 "실행 중 타이머" 흔적을 지운다.
    ///
    /// ⚠️ 이게 없으면 기기에 실제로 돌던(혹은 디버깅하며 심어 둔) 타이머가 복원돼
    ///    "저장된 게 없을 때 기본값" 같은 전제가 조용히 깨진다 — 실제로 겪은 실패다.
    private func clearSharedTimerState() {
        let shared = UserDefaults(suiteName: "group.leeo.toki")
        for key in ["timerIsRunning", "timerIsPaused", "timerMainDuration",
                    "timerEndDate", "timerStartDate", "timerPrealertOffsets", "timerName"] {
            shared?.removeObject(forKey: key)
        }
    }

    func test_applyCurrentSettings_persistsLastUsedConfig() {
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 25
        vm.mainSeconds = 30
        vm.selectedOffsets = [180, 60]

        vm.applyCurrentSettings()

        XCTAssertNotNil(
            UserDefaults.standard.data(forKey: storageKey),
            "타이머 시작 시 마지막 사용 설정이 저장되어야 한다"
        )
    }

    func test_restore_appliesPersistedConfigToDial() {
        let saver = TimerScreenViewModel()
        saver.mainMinutes = 25
        saver.mainSeconds = 30
        saver.selectedOffsets = [180, 60]
        saver.applyCurrentSettings()

        // 앱 재실행을 시뮬레이션 — 새 인스턴스는 기본값(10:00)으로 시작
        let restored = TimerScreenViewModel()
        XCTAssertEqual(restored.mainMinutes, 10)

        restored.restoreLastUsedConfigIfNeeded()

        XCTAssertEqual(restored.mainMinutes, 25)
        XCTAssertEqual(restored.mainSeconds, 30)
        XCTAssertEqual(restored.selectedOffsets, [180, 60])
        XCTAssertEqual(restored.configuredMainSeconds, 25 * 60 + 30)
    }

    func test_restore_withoutSavedData_keepsDefaults() {
        let vm = TimerScreenViewModel()

        vm.restoreLastUsedConfigIfNeeded()

        XCTAssertEqual(vm.mainMinutes, 10)
        XCTAssertEqual(vm.mainSeconds, 0)
        XCTAssertEqual(vm.selectedOffsets, [60])
    }

    func test_restore_isOneShot_doesNotOverwriteUserEdits() {
        let saver = TimerScreenViewModel()
        saver.mainMinutes = 25
        saver.applyCurrentSettings()

        let vm = TimerScreenViewModel()
        vm.restoreLastUsedConfigIfNeeded()
        XCTAssertEqual(vm.mainMinutes, 25)

        // 복원 후 사용자가 다이얼을 조정
        vm.mainMinutes = 5
        vm.restoreLastUsedConfigIfNeeded()

        XCTAssertEqual(vm.mainMinutes, 5, "복원은 최초 1회만 동작해야 한다")
    }

    func test_applyTemplate_persistsTemplateConfig() {
        let vm = TimerScreenViewModel()
        let template = Timer(
            name: "Test 40",
            mainSeconds: 2400,
            prealertOffsetsSec: [300, 60]
        )

        vm.apply(template: template)
        vm.timerVM.stop()

        let restored = TimerScreenViewModel()
        restored.restoreLastUsedConfigIfNeeded()

        XCTAssertEqual(restored.mainMinutes, 40)
        XCTAssertEqual(restored.selectedOffsets, [300, 60])
    }
}
