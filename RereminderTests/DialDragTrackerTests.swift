//
//  DialDragTrackerTests.swift
//  RereminderTests
//
//  다이얼 드래그의 "튐 방지" 규칙을 고정한다. 이 세 가지는 전부 실제로 났던 버그의 수리다 —
//  메인 앱과 App Clip 이 같은 코드를 쓰게 됐으므로, 여기서 한 번 지키면 네 군데가 다 지켜진다.
//

import XCTest
@testable import Rereminder

final class DialDragTrackerTests: XCTestCase {

    private let center = CGPoint(x: 100, y: 100)

    /// 12시 = 0°, 시계 방향. 반지름 80 위의 점을 각도로 준다.
    private func point(atDegrees deg: Double, radius: CGFloat = 80) -> CGPoint {
        let radians: Double = (deg - 90) * .pi / 180
        return CGPoint(x: center.x + radius * CGFloat(cos(radians)),
                       y: center.y + radius * CGFloat(sin(radians)))
    }

    // MARK: - ① 잡은 순간의 어긋남을 기억한다

    /// 노브가 90° 에 있는데 손가락이 100° 를 짚었다면, 그 10° 차이는 끝까지 유지돼야 한다.
    /// 이게 없으면 집는 순간 노브가 손끝으로 순간이동한다.
    func test_grabDelta_keepsKnobUnderFingerOffset() {
        var t = DialDragTracker()
        t.begin(at: point(atDegrees: 100), center: center, knobAngle: 90)

        // 손가락을 그대로 둔 채 갱신하면 노브도 제자리(90°)여야 한다
        let angle = t.update(to: point(atDegrees: 100), center: center, maxAngle: 360)
        XCTAssertEqual(angle, 90, accuracy: 0.5, "집는 순간 노브가 손끝으로 튀면 안 된다")
    }

    func test_grabDelta_movesKnobByFingerDelta() {
        var t = DialDragTracker()
        t.begin(at: point(atDegrees: 100), center: center, knobAngle: 90)

        // 손가락을 +30° 옮기면 노브도 +30° (90 → 120)
        let angle = t.update(to: point(atDegrees: 130), center: center, maxAngle: 360)
        XCTAssertEqual(angle, 120, accuracy: 0.5)
    }

    // MARK: - ② 각도를 이어 붙인다 (359° → 1° 을 +2° 로)

    func test_unwrapsAcrossTwelveOClock() {
        var t = DialDragTracker()
        t.begin(at: point(atDegrees: 350), center: center, knobAngle: 350)

        // 350° → 10° 로 넘어가면 값이 20° 로 떨어지는 게 아니라 370° 로 이어져야 한다
        let angle = t.update(to: point(atDegrees: 10), center: center, maxAngle: 720)
        XCTAssertEqual(angle, 370, accuracy: 0.5, "한 바퀴를 넘길 때 값이 뒤집히면 안 된다")
    }

    // MARK: - ③ 자르는 건 마지막에 한 번만 (되먹이지 않는다)

    /// 손가락이 허용 범위를 넘겨 계속 끌어도, 되돌아오면 벗어난 만큼 그대로 따라와야 한다.
    /// 잘린 값을 되먹이면 최단 방향이 뒤집혀 반대편으로 튄다 — 고치려던 바로 그 버그.
    ///
    /// ⚠️ 손가락은 **연속으로** 움직인다(`unwrappedAngle` 이 최단 방향 ±180° 로 이어 붙이므로).
    ///    한 번에 200° 를 건너뛰는 입력은 실제 드래그가 아니라 순간이동이고, 그때 반대로 도는 것은
    ///    버그가 아니라 설계다. 그래서 여기서는 실제처럼 조금씩 끈다.
    func test_clampDoesNotFeedBack() {
        var t = DialDragTracker()
        t.begin(at: point(atDegrees: 0), center: center, knobAngle: 0)

        // 상한 90° 를 넘겨 120° 까지 조금씩 끈다 → 표시는 90° 에서 멈춘다
        var shown: Double = 0
        for deg in stride(from: 30.0, through: 120.0, by: 30.0) {
            shown = t.update(to: point(atDegrees: deg), center: center, maxAngle: 90)
        }
        XCTAssertEqual(shown, 90, accuracy: 0.5, "상한을 넘으면 표시는 상한에서 멈춘다")
        // 내부 각도는 잘리지 않은 120° 를 그대로 들고 있어야 한다
        XCTAssertEqual(t.fingerAngle, 120, accuracy: 0.5, "잘린 값을 되먹이면 안 된다")

        // 되돌아오면 잘린 자리(90°)가 아니라 실제 손가락 위치를 따라온다
        let back = t.update(to: point(atDegrees: 45), center: center, maxAngle: 90)
        XCTAssertEqual(back, 45, accuracy: 0.5, "벗어났다 돌아오면 손가락을 그대로 따라야 한다")
    }

    func test_clampNeverGoesBelowZero() {
        XCTAssertEqual(DialDragTracker.clamped(-30, maxAngle: 90), 0)
    }

    /// 총 시간이 10초 미만이면 종이 갈 자리가 없다 — 음수 상한에도 0 아래로 내려가지 않는다.
    func test_clampSurvivesNegativeMax() {
        XCTAssertEqual(DialDragTracker.clamped(50, maxAngle: -10), 0)
    }

    // MARK: - 종 노브 상한 (메인 앱과 클립이 같은 여유를 써야 한다)

    func test_maxAlertAngle_leavesTenSecondsBeforeEnd() {
        // 600초 타이머 → 종은 590초까지
        let expected = Double(590) / TimeMapper.secondsPerDegree
        XCTAssertEqual(DialDragTracker.maxAlertAngle(totalSeconds: 600), expected, accuracy: 0.001)
    }

    // MARK: - 겹친 종에서 핸들로 넘기기

    func test_handOff_whenBellAtLimitAndFingerGoesClockwise() {
        // 30초 타이머(3°) + 20초 종(2°): 종의 한계가 곧 2° 다
        XCTAssertTrue(DialDragTracker.shouldHandOffToDial(rawAngle: 4, maxAlertAngle: 2, bellAngle: 2,
                                                          dialAngle: 3, grabSpanDegrees: 26))
    }

    func test_noHandOff_whenFingerGoesCounterclockwise() {
        XCTAssertFalse(DialDragTracker.shouldHandOffToDial(rawAngle: 1, maxAlertAngle: 2, bellAngle: 2,
                                                           dialAngle: 3, grabSpanDegrees: 26))
    }

    func test_noHandOff_whenDialIsFarFromBell() {
        // 10분 타이머 + 1분 종: 멀리 떨어져 있으면 종은 그냥 종이다
        XCTAssertFalse(DialDragTracker.shouldHandOffToDial(rawAngle: 80, maxAlertAngle: 59, bellAngle: 6,
                                                           dialAngle: 60, grabSpanDegrees: 26))
    }

    // MARK: - 활성 상태

    func test_isActiveTracksBeginAndEnd() {
        var t = DialDragTracker()
        XCTAssertFalse(t.isActive)
        t.begin(at: point(atDegrees: 0), center: center, knobAngle: 0)
        XCTAssertTrue(t.isActive)
        t.end()
        XCTAssertFalse(t.isActive)
    }
}
