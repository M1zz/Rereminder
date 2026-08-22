//
//  SectionCountdownBarTests.swift
//  RereminderTests
//
//  실행 중 구간 목록의 **길이 비례 막대** — 숫자가 못 하는 "이 구간이 저 구간의 두 배"를
//  길이로 말한다. 그 비율이 틀리면 막대는 거짓말이 되므로 여기서 지킨다.
//

import XCTest
@testable import Rereminder

final class SectionCountdownBarTests: XCTestCase {

    private let maxWidth: CGFloat = 116
    private let minWidth: CGFloat = 10

    private func width(_ durationSec: Int, longest: Int) -> CGFloat {
        SectionCountdownList.trackWidth(durationSec: durationSec,
                                        longestSec: longest,
                                        maxWidth: maxWidth,
                                        minWidth: minWidth)
    }

    // MARK: - 길이 비례

    func test_longestSectionGetsTheFullWidth() {
        XCTAssertEqual(width(480, longest: 480), maxWidth)
    }

    func test_widthsAreProportionalToDuration() {
        // 사용자 예시 그대로: 4분 / 8분 / 8분 → 1 : 2 : 2
        let four = width(240, longest: 480)
        let eight = width(480, longest: 480)

        XCTAssertEqual(eight, maxWidth)
        XCTAssertEqual(four, maxWidth / 2, accuracy: 0.001)
        XCTAssertEqual(eight / four, 2, accuracy: 0.001,
                       "8분 구간은 4분 구간의 두 배로 보여야 한다 — 그게 이 막대의 존재 이유다")
    }

    // MARK: - 사라지지 않기

    func test_veryShortSectionKeepsMinimumWidth() {
        // 20분 중 30초 — 비례대로면 2.9pt 라 사라진다. 사라진 구간은 "없는 구간"으로 읽힌다.
        let tiny = width(30, longest: 1200)
        XCTAssertEqual(tiny, minWidth)
        XCTAssertGreaterThan(tiny, maxWidth * 30 / 1200)
    }

    func test_widthNeverExceedsTheMaximum() {
        // 방어: 가장 긴 구간보다 긴 값이 들어와도 칸을 넘지 않는다
        XCTAssertEqual(width(9999, longest: 480), maxWidth)
    }

    func test_zeroLongest_doesNotDivideByZero() {
        XCTAssertEqual(width(0, longest: 0), minWidth)
    }

    // MARK: - 줄어드는 몫

    func test_fillRatio_shrinksWithRemainingTime() {
        XCTAssertEqual(SectionCountdownList.fillRatio(remaining: 480, durationSec: 480), 1)
        XCTAssertEqual(SectionCountdownList.fillRatio(remaining: 240, durationSec: 480), 0.5, accuracy: 0.001)
        XCTAssertEqual(SectionCountdownList.fillRatio(remaining: 0, durationSec: 480), 0)
    }

    func test_fillRatio_isClampedAndSafe() {
        // 아직 오지 않은 구간(남은 시간 = 길이)이 1을 넘거나, 지나간 구간이 음수가 되면 안 된다
        XCTAssertEqual(SectionCountdownList.fillRatio(remaining: 900, durationSec: 480), 1)
        XCTAssertEqual(SectionCountdownList.fillRatio(remaining: -60, durationSec: 480), 0)
        XCTAssertEqual(SectionCountdownList.fillRatio(remaining: 60, durationSec: 0), 0)
    }
}
