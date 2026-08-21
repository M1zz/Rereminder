//
//  MinimumTimerLengthTests.swift
//  RereminderTests
//
//  "켜 둔 알림보다 짧게는 줄일 수 없다" 규칙.
//  알림은 종료 N분 전이라 전체 시간보다 짧아야 존재할 수 있고, 전체 시간을 그 아래로 줄이면
//  사용자가 지운 적 없는 알림이 조용히 사라진다. 그래서 줄이는 쪽을 막는다.
//

import XCTest
@testable import Rereminder

final class MinimumTimerLengthTests: XCTestCase {

    func test_noAlerts_hasNoFloor() {
        XCTAssertEqual(TimeMapper.minimumSeconds(forAlertOffsets: []), 0)
    }

    func test_floorIsJustAboveEarliestAlert() {
        // 5분 전 알림이 있으면 최소 5분 10초 — 딱 5분이면 그 알림이 시작과 동시에 울린다
        XCTAssertEqual(TimeMapper.minimumSeconds(forAlertOffsets: [300]), 310)
    }

    func test_earliestAlertDecidesTheFloor() {
        // 여러 개면 가장 이른(=가장 큰 offset) 알림이 기준이다
        XCTAssertEqual(TimeMapper.minimumSeconds(forAlertOffsets: [60, 1800, 300]), 1810)
    }

    func test_invalidOffsetsAreIgnored() {
        XCTAssertEqual(TimeMapper.minimumSeconds(forAlertOffsets: [0, -60]), 0)
    }

    func test_floorNeverExceedsDialMaximum() {
        // 상한 근처의 알림 때문에 다이얼 밖 값이 나오면 안 된다
        let floor = TimeMapper.minimumSeconds(forAlertOffsets: [TimeMapper.maxSeconds - 5])
        XCTAssertLessThanOrEqual(floor, TimeMapper.maxSeconds)
    }

    func test_alertSurvivesAtTheFloor() {
        // 최소 시간으로 줄여도 그 알림은 살아남아야 한다 (구간 계산이 offset < mainSec 을 요구)
        let offsets: Set<Int> = [300]
        let floor = TimeMapper.minimumSeconds(forAlertOffsets: offsets)
        let segments = TimerSections.derive(mainSeconds: floor, alertOffsets: offsets)

        XCTAssertEqual(segments.count, 2, "알림이 경계로 살아 있어야 구간이 둘로 나뉜다")
    }
}

// MARK: - 화면 쪽 하한 (지금 유효한 알림만 센다)

@MainActor
final class TimerScreenMinimumLengthTests: XCTestCase {

    func test_floorIgnoresAlertsLongerThanCurrentTime() {
        // 템플릿 등으로 "현재 시간보다 긴" 알림이 남아 있어도 하한을 끌어올리면 안 된다
        // (그런 알림은 어차피 울리지 않는데, 시간을 줄이려는 순간 오히려 늘어나 버린다)
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 10
        vm.mainSeconds = 0
        vm.selectedOffsets = [1800]          // 30분 전 알림 — 10분 타이머에서는 유효하지 않다

        XCTAssertEqual(vm.alertFloorSeconds, 0)
    }

    func test_floorFollowsValidAlert() {
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 10
        vm.mainSeconds = 0
        vm.selectedOffsets = [300]           // 5분 전 알림 — 유효

        XCTAssertEqual(vm.alertFloorSeconds, 310)
    }

    func test_cannotShrinkBelowAlert() {
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 10
        vm.mainSeconds = 0
        vm.selectedOffsets = [300]

        vm.setMainSeconds(180, announceClamp: false)   // 3분으로 줄이려 시도

        XCTAssertEqual(vm.mainMinutes * 60 + vm.mainSeconds, 310,
                       "알림이 살아남는 가장 짧은 시간에서 멈춘다")
    }

    func test_canStillGrow() {
        let vm = TimerScreenViewModel()
        vm.mainMinutes = 10
        vm.selectedOffsets = [300]

        vm.setMainSeconds(1800, announceClamp: false)
        XCTAssertEqual(vm.mainMinutes, 30)
    }
}
