//
//  TimerSectionsTests.swift
//  RereminderTests
//
//  구간 계산은 링에 그려지는 색·구간 리스트·실제로 울리는 발표 구간이 **같은 답**을 쓰게 하는
//  단일 소스다. 여기가 어긋나면 화면에 보이는 구간과 실제 알림이 달라진다.
//

import XCTest
@testable import Rereminder

final class TimerSectionsTests: XCTestCase {

    func test_noAlerts_isOneWholeSection() {
        let segments = TimerSections.derive(mainSeconds: 600, alertOffsets: [])
        XCTAssertEqual(segments, [.init(index: 0, startSec: 0, endSec: 600)])
    }

    func test_alertsBecomeBoundaries_inElapsedOrder() {
        // 15분 타이머 + 5분 전 알림 → 0~10분, 10~15분
        let segments = TimerSections.derive(mainSeconds: 900, alertOffsets: [300])
        XCTAssertEqual(segments, [
            .init(index: 0, startSec: 0, endSec: 600),
            .init(index: 1, startSec: 600, endSec: 900)
        ])
    }

    func test_multipleAlerts_areSortedAndContiguous() {
        let segments = TimerSections.derive(mainSeconds: 1800, alertOffsets: [300, 900, 600])

        XCTAssertEqual(segments.map(\.startSec), [0, 900, 1200, 1500])
        XCTAssertEqual(segments.map(\.endSec), [900, 1200, 1500, 1800])
        // 빈틈도 겹침도 없어야 한다 — 구간 합 = 전체 시간
        XCTAssertEqual(segments.reduce(0) { $0 + $1.durationSec }, 1800)
        for (previous, next) in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(previous.endSec, next.startSec)
        }
    }

    func test_outOfRangeAlerts_areIgnored() {
        // 0 이하이거나 전체 길이 이상인 알림은 경계가 될 수 없다
        let segments = TimerSections.derive(mainSeconds: 600, alertOffsets: [0, 600, 900, 300])
        XCTAssertEqual(segments, [
            .init(index: 0, startSec: 0, endSec: 300),
            .init(index: 1, startSec: 300, endSec: 600)
        ])
    }

    func test_zeroOrNegativeDuration_hasNoSections() {
        XCTAssertTrue(TimerSections.derive(mainSeconds: 0, alertOffsets: [60]).isEmpty)
        XCTAssertTrue(TimerSections.derive(mainSeconds: -10, alertOffsets: []).isEmpty)
    }

    func test_indexOrder_matchesSectionNumbering() {
        // 구간 색·이름("Section 1")이 이 번호를 따라간다 — 경과 순서와 같아야 한다
        let segments = TimerSections.derive(mainSeconds: 1200, alertOffsets: [600])
        XCTAssertEqual(segments.map(\.index), [0, 1])
        XCTAssertEqual(segments.first?.startSec, 0)
    }
}
