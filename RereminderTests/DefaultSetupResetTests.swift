//
//  DefaultSetupResetTests.swift
//  RereminderTests
//
//  다이얼 아래 초기화 버튼 / 템플릿 저장 버튼 노출 규칙 테스트
//  - 갓 설치한 기본 설정 그대로면 두 버튼 다 숨어야 한다 (isAtDefaultSetup == true)
//  - 초기화는 갓 설치했을 때의 설정으로 되돌리고, 다음 실행에도 그 상태가 유지돼야 한다
//

import XCTest
@testable import Rereminder

@MainActor
final class DefaultSetupResetTests: XCTestCase {

    private let storageKey = "rereminder.lastUsedConfig.v1"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        super.tearDown()
    }

    // MARK: - 갓 설치했을 때

    func test_freshInstall_isAtDefaultSetup() {
        let vm = TimerScreenViewModel()

        XCTAssertTrue(
            vm.isAtDefaultSetup,
            "새 인스턴스는 갓 설치한 상태와 같아야 한다 — 저장·초기화 버튼이 둘 다 숨는다"
        )
    }

    func test_defaultSetup_is10MinutesWithOneAlert() {
        XCTAssertEqual(TimerScreenViewModel.DefaultSetup.mainSeconds, 600)
        XCTAssertEqual(TimerScreenViewModel.DefaultSetup.offsets, [60])

        // @Published 초기값도 같은 상수를 써야 한다 (정의가 두 곳으로 갈라지지 않도록)
        let vm = TimerScreenViewModel()
        XCTAssertEqual(vm.mainMinutes, 10)
        XCTAssertEqual(vm.mainSeconds, 0)
        XCTAssertEqual(vm.selectedOffsets, [60])
        XCTAssertEqual(vm.configuredMainSeconds, 600)
    }

    // MARK: - 뭔가 바꿨을 때

    func test_changingDuration_leavesDefaultSetup() {
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 25

        XCTAssertFalse(vm.isAtDefaultSetup)
    }

    func test_addingAlert_leavesDefaultSetup() {
        let vm = TimerScreenViewModel()
        vm.selectedOffsets = [60, 180]

        XCTAssertFalse(vm.isAtDefaultSetup)
    }

    func test_addingMessage_leavesDefaultSetup() {
        let vm = TimerScreenViewModel()
        vm.finishMessage = "끝!"

        XCTAssertFalse(vm.isAtDefaultSetup)
    }

    // MARK: - 초기화

    func test_reset_restoresDefaultSetup() {
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 25
        vm.mainSeconds = 30
        vm.selectedOffsets = [600, 300, 60]
        vm.prealertMessages = [60: "1분 남았어요"]
        vm.finishMessage = "끝!"
        XCTAssertFalse(vm.isAtDefaultSetup)

        vm.resetToDefaultSetup()

        XCTAssertEqual(vm.mainMinutes, 10)
        XCTAssertEqual(vm.mainSeconds, 0)
        XCTAssertEqual(vm.selectedOffsets, [60])
        XCTAssertEqual(vm.configuredMainSeconds, 600)
        XCTAssertTrue(vm.prealertMessages.isEmpty)
        XCTAssertTrue(vm.finishMessage.isEmpty)
        XCTAssertTrue(vm.isAtDefaultSetup, "초기화 직후에는 두 버튼이 다시 숨어야 한다")
    }

    func test_reset_survivesRelaunch() {
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 25
        vm.selectedOffsets = [300, 60]
        vm.applyCurrentSettings()   // 마지막 사용 설정이 저장된다
        vm.timerVM.stop()

        vm.resetToDefaultSetup()

        // 앱 재실행 — 초기화한 설정이 되살아난 옛 설정에 덮이면 안 된다
        let relaunched = TimerScreenViewModel()
        relaunched.restoreLastUsedConfigIfNeeded()

        XCTAssertEqual(relaunched.mainMinutes, 10)
        XCTAssertEqual(relaunched.selectedOffsets, [60])
        XCTAssertTrue(relaunched.isAtDefaultSetup)
    }
}
