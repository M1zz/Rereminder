//
//  TimerEngineTests.swift
//  RereminderTests
//
//  TimerEngine 상태 전환 단위 테스트
//  실제 타이머 tick (DispatchSource) 은 비동기적이고 외부 의존성 (UNUserNotificationCenter,
//  WidgetCenter) 이 있어 단위 테스트 범위 밖. 여기서는 동기적인 상태 전환만 검증.
//

import XCTest
@testable import Rereminder

final class TimerEngineTests: XCTestCase {

    // MARK: - Configure

    func test_configure_setsIdleStateWithProvidedDuration() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 60, prealertOffsetsSec: [], name: "Test")

        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.config?.mainDuration, 60)
        XCTAssertEqual(engine.config?.name, "Test")
    }

    func test_configure_filtersInvalidPrealertOffsets() {
        let engine = TimerEngine()
        engine.configure(
            mainSeconds: 60,
            prealertOffsetsSec: [-5, 0, 30, 60, 90, 100],
            name: ""
        )

        // 0 이하, mainDuration 이상은 모두 제외
        let offsets = engine.config?.prealertOffsetsSec.map { Int($0) } ?? []
        XCTAssertEqual(offsets, [30])
    }

    func test_configure_sortsPrealertOffsetsDescending() {
        let engine = TimerEngine()
        engine.configure(
            mainSeconds: 600,
            prealertOffsetsSec: [60, 300, 30, 120],
            name: ""
        )

        let offsets = engine.config?.prealertOffsetsSec.map { Int($0) } ?? []
        XCTAssertEqual(offsets, [300, 120, 60, 30])
    }

    // MARK: - State transitions

    func test_start_movesIdleToRunning() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 60, prealertOffsetsSec: [], name: "")

        engine.start()
        XCTAssertEqual(engine.state, .running)

        // cleanup
        engine.stop()
    }

    func test_pause_movesRunningToPaused() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 60, prealertOffsetsSec: [], name: "")
        engine.start()

        engine.pause()
        XCTAssertEqual(engine.state, .paused)

        engine.stop()
    }

    func test_resume_movesPausedToRunning() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 60, prealertOffsetsSec: [], name: "")
        engine.start()
        engine.pause()

        engine.resume()
        XCTAssertEqual(engine.state, .running)

        engine.stop()
    }

    func test_stop_movesAnyStateToIdle() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 60, prealertOffsetsSec: [], name: "")
        engine.start()
        engine.pause()

        engine.stop()
        XCTAssertEqual(engine.state, .idle)
    }

    // MARK: - Configuration without start

    func test_pause_withoutStart_isNoOp() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 60, prealertOffsetsSec: [], name: "")

        engine.pause()
        XCTAssertEqual(engine.state, .idle)
    }

    func test_resume_withoutPause_isNoOp() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 60, prealertOffsetsSec: [], name: "")
        engine.start()

        engine.resume()
        XCTAssertEqual(engine.state, .running)

        engine.stop()
    }

    // MARK: - Duration safeguard

    func test_configure_withZeroOrNegative_clampsToOne() {
        let engine = TimerEngine()
        engine.configure(mainSeconds: 0, prealertOffsetsSec: [], name: "")
        XCTAssertEqual(engine.config?.mainDuration, 1)

        engine.configure(mainSeconds: -10, prealertOffsetsSec: [], name: "")
        XCTAssertEqual(engine.config?.mainDuration, 1)
    }
}
