//
//  DialRingTests.swift
//  RereminderTests
//
//  다이얼이 몇 줄로 그려지는지의 규칙을 고정한다.
//  60분을 넘는 타이머는 **대기 중이든 진행 중이든** 두 줄이어야 한다 — 진행 중에만 비율로 눌러
//  한 줄로 만들면, 시작 버튼을 누른 순간 다이얼 모양이 바뀌어 버린다.
//

import XCTest
@testable import Rereminder

final class DialRingTests: XCTestCase {

    // MARK: - 두 줄 나누기

    func test_rows_underOneLap_usesOuterRowOnly() {
        let rows = DialRing.rows(laps: 0.5)          // 30분
        XCTAssertEqual(rows.outer, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rows.inner, 0, accuracy: 0.0001)
    }

    func test_rows_overOneLap_spillsIntoInnerRow() {
        let rows = DialRing.rows(laps: 1.5)          // 90분
        XCTAssertEqual(rows.outer, 1.0, accuracy: 0.0001, "첫 바퀴는 바깥 줄이 가득 찬다")
        XCTAssertEqual(rows.inner, 0.5, accuracy: 0.0001, "넘어간 30분이 안쪽 줄로 간다")
    }

    func test_rows_atMaximum_bothRowsFull() {
        let rows = DialRing.rows(laps: 2.0)          // 120분 = 다이얼 상한
        XCTAssertEqual(rows.outer, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rows.inner, 1.0, accuracy: 0.0001)
    }

    func test_rows_clampsNegativeAndOverflow() {
        XCTAssertEqual(DialRing.rows(laps: -1).outer, 0)
        XCTAssertEqual(DialRing.rows(laps: -1).inner, 0)
        XCTAssertEqual(DialRing.rows(laps: 5).inner, 1, "상한을 넘겨도 줄은 두 개뿐이다")
    }

    // MARK: - 좌표계 선택

    func test_idle_alwaysUsesAbsoluteCoordinates() {
        XCTAssertTrue(DialRing.usesAbsoluteCoordinates(isRunning: false, configuredSeconds: 600))
        XCTAssertTrue(DialRing.usesAbsoluteCoordinates(isRunning: false, configuredSeconds: 5400))
    }

    func test_shortTimerWhileRunning_usesRatio() {
        // 10분 타이머는 진행 중 링이 가득 찼다가 줄어드는 기존 동작을 유지한다
        XCTAssertFalse(DialRing.usesAbsoluteCoordinates(isRunning: true, configuredSeconds: 600))
        XCTAssertFalse(DialRing.usesAbsoluteCoordinates(isRunning: true, configuredSeconds: TimeMapper.secondsPerLap))
    }

    func test_longTimerWhileRunning_keepsAbsoluteCoordinates() {
        // 90분 타이머는 진행 중에도 두 줄이 유지돼야 한다
        XCTAssertTrue(DialRing.usesAbsoluteCoordinates(isRunning: true, configuredSeconds: 5400))
    }

    // MARK: - 진행 중 두 줄이 실제로 나오는가

    func test_runningLongTimer_drawsTwoRows() {
        let configured = 5400                        // 90분
        let remaining: Double = 4800                 // 80분 남음
        XCTAssertTrue(DialRing.usesAbsoluteCoordinates(isRunning: true, configuredSeconds: configured))

        let rows = DialRing.rows(laps: DialRing.laps(ofSeconds: remaining))
        XCTAssertEqual(rows.outer, 1.0, accuracy: 0.0001)
        XCTAssertEqual(rows.inner, 1.0 / 3.0, accuracy: 0.0001, "80분 = 한 바퀴 + 20분")
    }

    func test_runningLongTimer_fallsToSingleRowUnderAnHour() {
        // 90분 타이머라도 남은 시간이 60분 밑으로 내려오면 안쪽 줄은 비고 바깥 줄만 남는다
        let rows = DialRing.rows(laps: DialRing.laps(ofSeconds: 1800))
        XCTAssertEqual(rows.outer, 0.5, accuracy: 0.0001)
        XCTAssertEqual(rows.inner, 0, accuracy: 0.0001)
    }

    func test_laps_matchesOneHourPerLap() {
        XCTAssertEqual(DialRing.laps(ofSeconds: Double(TimeMapper.secondsPerLap)), 1.0, accuracy: 0.0001)
        XCTAssertEqual(DialRing.laps(ofSeconds: -100), 0)
    }
}
