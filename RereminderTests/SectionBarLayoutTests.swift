//
//  SectionBarLayoutTests.swift
//  RereminderTests
//
//  구간 막대의 자리 계산. 여기가 어긋나면 **알림이 울린 순간 재생헤드가 경계에 있지 않고**,
//  그 순간 이 막대는 못 믿을 물건이 된다.
//

import XCTest
@testable import Rereminder

final class SectionBarLayoutTests: XCTestCase {

    private let gap: CGFloat = 3
    private let minWidth: CGFloat = 6

    private func slots(_ segments: [TimerSections.Segment], width: CGFloat) -> [SectionBarLayout.Slot] {
        SectionBarLayout.slots(segments: segments, totalWidth: width, gap: gap, minWidth: minWidth)
    }

    // MARK: - 폭

    func test_widthIsProportionalToDuration() {
        // 30분 = 5분 + 25분 → 폭도 1 : 5
        let segments = TimerSections.derive(mainSeconds: 1800, alertOffsets: [1500])
        let result = slots(segments, width: 303)   // 303 - gap 3 = 300 트랙

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].width, 50, accuracy: 0.01)
        XCTAssertEqual(result[1].width, 250, accuracy: 0.01)
    }

    func test_slotsFillTheWholeWidth() {
        let segments = TimerSections.derive(mainSeconds: 2700, alertOffsets: [1500, 900])
        let result = slots(segments, width: 320)

        XCTAssertEqual(result.first?.x, 0)
        XCTAssertEqual(result.last?.maxX ?? 0, 320, accuracy: 0.01, "마지막 칸이 오른쪽 끝에 닿아야 한다")
    }

    func test_narrowSectionKeepsMinimumWidth() {
        // 60분 안의 30초짜리 구간 — 비례대로면 2.5pt 라 화면에서 사라진다
        let segments = TimerSections.derive(mainSeconds: 3600, alertOffsets: [1800, 1770])
        let result = slots(segments, width: 320)

        XCTAssertEqual(result[1].width, minWidth, accuracy: 0.01, "사라진 구간은 없는 구간으로 읽힌다")
        XCTAssertEqual(result.last?.maxX ?? 0, 320, accuracy: 0.01, "최소 폭을 준 만큼 다른 칸이 줄어든다")
    }

    func test_tooNarrowForEveryone_splitsEvenly() {
        let segments = TimerSections.derive(mainSeconds: 3600, alertOffsets: [3000, 2400, 1800])
        let result = slots(segments, width: 20)     // 칸 4개 × 최소 6pt 를 못 준다

        let widths = Set(result.map { ($0.width * 100).rounded() })
        XCTAssertEqual(widths.count, 1, "줄 수 없으면 균등 분할이 가장 정직하다")
    }

    // MARK: - 재생헤드

    func test_playheadSitsExactlyOnBoundaryWhenAlertFires() {
        // 최소 폭으로 넓혀 준 칸이 섞여 있어도 경계는 어긋나면 안 된다
        let segments = TimerSections.derive(mainSeconds: 3600, alertOffsets: [1800, 1770])
        let result = slots(segments, width: 320)

        let atFirstAlert = SectionBarLayout.playheadX(slots: result, segments: segments, elapsedSec: 1800)
        XCTAssertEqual(atFirstAlert, result[1].x, accuracy: 0.01)

        let atSecondAlert = SectionBarLayout.playheadX(slots: result, segments: segments, elapsedSec: 1830)
        XCTAssertEqual(atSecondAlert, result[2].x, accuracy: 0.01)
    }

    func test_playheadMovesWithinItsOwnSlot() {
        let segments = TimerSections.derive(mainSeconds: 1800, alertOffsets: [1500])
        let result = slots(segments, width: 303)

        let half = SectionBarLayout.playheadX(slots: result, segments: segments, elapsedSec: 150)
        XCTAssertEqual(half, 25, accuracy: 0.01, "5분 구간의 절반은 그 칸의 절반이다")
    }

    func test_playheadStartsAtZeroAndEndsAtRightEdge() {
        let segments = TimerSections.derive(mainSeconds: 1800, alertOffsets: [1500])
        let result = slots(segments, width: 303)

        XCTAssertEqual(SectionBarLayout.playheadX(slots: result, segments: segments, elapsedSec: 0), 0)
        XCTAssertEqual(SectionBarLayout.playheadX(slots: result, segments: segments, elapsedSec: 1800),
                       result.last?.maxX ?? 0, accuracy: 0.01)
        XCTAssertEqual(SectionBarLayout.playheadX(slots: result, segments: segments, elapsedSec: 9999),
                       result.last?.maxX ?? 0, accuracy: 0.01, "오버타임에도 오른쪽 끝을 넘지 않는다")
    }

    // MARK: - 빈 입력

    func test_emptyInputsProduceNoSlots() {
        XCTAssertTrue(slots([], width: 320).isEmpty)
        XCTAssertTrue(slots(TimerSections.derive(mainSeconds: 600, alertOffsets: []), width: 0).isEmpty)
    }

    // MARK: - 시간 표기

    func test_clockTextKeepsHoursReadable() {
        XCTAssertEqual(TimeMapper.clockText(1200), "20:00")
        XCTAssertEqual(TimeMapper.clockText(3900), "1:05:00", "3900초를 65:00 으로 적으면 못 읽는다")
        XCTAssertEqual(TimeMapper.clockText(-5), "0:00")
    }
}
