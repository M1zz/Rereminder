//
//  RoundedRectRingTests.swift
//  RereminderTests
//
//  워치 실행 화면의 링은 **둘레 위의 t 하나**로 두 가지를 정한다 — 줄어드는 호가 어디서 끝나는지
//  (`Ring.trim`)와 알림 종이 어디 찍히는지(`point(atFraction:)`). 둘이 갈라지면 종과 호 끝이
//  서로 다른 시각을 가리킨다. 여기서 지키는 건 그 좌표계다.
//

import XCTest
import SwiftUI
@testable import Rereminder

final class RoundedRectRingTests: XCTestCase {

    private let square = CGSize(width: 100, height: 100)

    // MARK: - 둘레

    func test_perimeter_withoutCorners_isPlainRectangle() {
        XCTAssertEqual(RoundedRectRing.perimeter(in: square, cornerRadius: 0), 400, accuracy: 0.001)
        XCTAssertEqual(RoundedRectRing.perimeter(in: CGSize(width: 80, height: 120), cornerRadius: 0),
                       400, accuracy: 0.001)
    }

    /// 반지름이 짧은 변의 절반이면 그건 원이다 — 둘레도 원과 같아야 한다.
    func test_perimeter_atMaxRadius_equalsCircle() {
        XCTAssertEqual(RoundedRectRing.perimeter(in: square, cornerRadius: 50),
                       100 * .pi, accuracy: 0.001)
    }

    /// 직선 몫 + 호 몫. 이 식이 깨지면 종 위치가 통째로 밀린다.
    func test_perimeter_withCorners_isStraightsPlusArcs() {
        let r: CGFloat = 20
        let expected = 2 * (100 - 2 * r) + 2 * (100 - 2 * r) + 2 * .pi * r
        XCTAssertEqual(RoundedRectRing.perimeter(in: square, cornerRadius: r),
                       expected, accuracy: 0.001)
    }

    /// 반지름이 너무 크면 경로가 뒤집힌다 — 짧은 변의 절반으로 자른다.
    func test_radiusIsClampedToHalfTheShortSide() {
        XCTAssertEqual(RoundedRectRing.clampedRadius(999, in: CGSize(width: 80, height: 120)), 40)
        XCTAssertEqual(RoundedRectRing.clampedRadius(-5, in: square), 0)
    }

    // MARK: - 둘레 위의 자리

    /// 12시(위 가운데)에서 시작한다 — 원형 링과 같은 문법이라야 사용자가 다시 배우지 않는다.
    func test_startsAtTopCenter() {
        assertPoint(RoundedRectRing.point(atFraction: 0, in: square, cornerRadius: 0),
                    equals: CGPoint(x: 50, y: 0))
        assertPoint(RoundedRectRing.point(atFraction: 1, in: square, cornerRadius: 0),
                    equals: CGPoint(x: 50, y: 0), message: "한 바퀴 돌면 제자리")
    }

    /// 정사각형이면 1/4씩이 정확히 오른쪽·아래·왼쪽 가운데다(시계 방향).
    func test_quarterTurns_goClockwise() {
        assertPoint(RoundedRectRing.point(atFraction: 0.25, in: square, cornerRadius: 0),
                    equals: CGPoint(x: 100, y: 50), message: "1/4 = 오른쪽 가운데")
        assertPoint(RoundedRectRing.point(atFraction: 0.5, in: square, cornerRadius: 0),
                    equals: CGPoint(x: 50, y: 100), message: "1/2 = 아래 가운데")
        assertPoint(RoundedRectRing.point(atFraction: 0.75, in: square, cornerRadius: 0),
                    equals: CGPoint(x: 0, y: 50), message: "3/4 = 왼쪽 가운데")
    }

    /// ⚠️ 반지름 0이면 네 호의 길이가 전부 0이다. 그 조각을 건너뛰지 않으면 t 와 상관없이
    ///    첫 모서리 좌표가 나와 **종이 전부 한 자리에 몰린다**(실제로 그랬다).
    func test_zeroLengthCornerArcs_areSkipped() {
        let points = stride(from: 0.0, through: 1.0, by: 0.1).map {
            RoundedRectRing.point(atFraction: $0, in: square, cornerRadius: 0)
        }
        XCTAssertEqual(Set(points.map { "\($0.x),\($0.y)" }).count, points.count - 1,
                       "0 과 1 만 같은 자리이고 나머지는 모두 달라야 한다")
    }

    /// 모서리가 둥글어도 둘레를 벗어나지 않는다.
    func test_everyPointStaysInsideTheBounds() {
        let size = CGSize(width: 162, height: 197)
        for step in 0...100 {
            let p = RoundedRectRing.point(atFraction: Double(step) / 100, in: size, cornerRadius: 40)
            XCTAssertTrue((0...size.width).contains(p.x), "x=\(p.x) 가 화면 밖")
            XCTAssertTrue((0...size.height).contains(p.y), "y=\(p.y) 가 화면 밖")
        }
    }

    /// 진행은 단조롭게 나아가야 한다 — 되돌아가면 종 순서가 뒤집힌다.
    func test_progressMovesClockwiseWithoutJumpingBack() {
        let size = CGSize(width: 162, height: 197)
        var previous = RoundedRectRing.point(atFraction: 0, in: size, cornerRadius: 40)
        var totalTravel: CGFloat = 0
        for step in 1...200 {
            let p = RoundedRectRing.point(atFraction: Double(step) / 200, in: size, cornerRadius: 40)
            let hop = hypot(p.x - previous.x, p.y - previous.y)
            XCTAssertLessThan(hop, 10, "한 걸음이 지나치게 크다 — 경로가 끊긴 것")
            totalTravel += hop
            previous = p
        }
        // 걸어간 거리의 합이 둘레와 거의 같아야 한다(다각형 근사라 아주 조금 짧다)
        let perimeter = RoundedRectRing.perimeter(in: size, cornerRadius: 40)
        XCTAssertEqual(totalTravel, perimeter, accuracy: perimeter * 0.01)
    }

    // MARK: -

    private func assertPoint(_ actual: CGPoint,
                             equals expected: CGPoint,
                             message: String = "",
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.001, message, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.001, message, file: file, line: line)
    }
}
