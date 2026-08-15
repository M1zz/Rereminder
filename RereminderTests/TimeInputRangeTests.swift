//
//  TimeInputRangeTests.swift
//  RereminderTests
//
//  수동 시간 입력이 다이얼과 같은 범위를 보는지 검증한다.
//
//  회귀 방지: 110분을 맞춰 둔 상태에서 수동 입력을 열면 휠이 먹통이 돼 45분으로 줄일 수 없었다.
//  분 목록이 0~60 으로 굳어 있어 현재 값(110)이 목록에 없었던 탓이다.
//

import XCTest
@testable import Rereminder

final class TimeInputRangeTests: XCTestCase {

    // MARK: - 범위가 다이얼과 같은 소스인가

    func test_maxMinutes_matchesDialRange() {
        XCTAssertEqual(TimeMapper.maxMinutes, TimeMapper.maxSeconds / 60)
        XCTAssertEqual(TimeMapper.maxMinutes, 120, "다이얼이 2바퀴(120분)까지 도는데 입력이 그보다 좁으면 못 줄인다")
    }

    func test_dialMaximumIsSelectableInPicker() {
        // 다이얼로 만들 수 있는 가장 긴 시간이 피커 목록(0...maxMinutes) 안에 있어야 한다
        let longest = TimeMapper.angleToSeconds(from: TimeMapper.maxAngle)
        XCTAssertLessThanOrEqual(longest / 60, TimeMapper.maxMinutes)
    }

    // MARK: - 회귀: 110분 → 45분

    func test_clampedInput_keepsValueBeyondOneHour() {
        // 110분은 잘리지 않고 그대로 열려야 한다 (예전엔 목록 밖 값이라 휠이 반응하지 않았다)
        let opened = TimeMapper.clampedInput(minutes: 110, seconds: 0)
        XCTAssertEqual(opened.minutes, 110)
        XCTAssertEqual(opened.seconds, 0)
        XCTAssertLessThanOrEqual(opened.minutes, TimeMapper.maxMinutes)
    }

    func test_clampedInput_allowsReducingToShorterTime() {
        let reduced = TimeMapper.clampedInput(minutes: 45, seconds: 0)
        XCTAssertEqual(reduced.minutes, 45)
        XCTAssertEqual(reduced.seconds, 0)
    }

    // MARK: - 경계

    func test_clampedInput_clampsOverMaximum() {
        let over = TimeMapper.clampedInput(minutes: TimeMapper.maxMinutes, seconds: 59)
        XCTAssertEqual(over.minutes, TimeMapper.maxMinutes)
        XCTAssertEqual(over.seconds, 0, "상한을 넘는 조합은 상한 시각으로 맞춘다 — 다이얼이 조용히 자르게 두지 않는다")
    }

    func test_clampedInput_normalizesNegativeAndOverflowingSeconds() {
        XCTAssertEqual(TimeMapper.clampedInput(minutes: -5, seconds: -10).minutes, 0)
        XCTAssertEqual(TimeMapper.clampedInput(minutes: -5, seconds: -10).seconds, 0)
        XCTAssertEqual(TimeMapper.clampedInput(minutes: 1, seconds: 120).seconds, 59)
    }
}
