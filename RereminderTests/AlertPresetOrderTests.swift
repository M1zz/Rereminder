//
//  AlertPresetOrderTests.swift
//  RereminderTests
//
//  알림 칩 줄의 배치 규칙 — 켜진 알림이 먼저, 나머지가 시간순.
//  "지금 뭐가 걸려 있나"를 스크롤 없이 보여주는 게 이 줄의 목적이라, 순서가 조용히
//  시간순으로 돌아가면 그 목적이 사라진다.
//

import XCTest
@testable import Rereminder

final class AlertPresetOrderTests: XCTestCase {

    func test_selectedComesFirst_restStaysInTimeOrder() {
        // 프리셋 1:00·3:00 에 1:30 을 켜 둔 상태 → 1:30, 1:00, 3:00
        let order = AlertPresets.displayOrder(presets: [60, 180], selected: [90])
        XCTAssertEqual(order, [90, 60, 180])
    }

    func test_multipleSelected_areSortedAmongThemselves() {
        let order = AlertPresets.displayOrder(presets: [60, 120, 180, 300], selected: [300, 120])
        XCTAssertEqual(order, [120, 300, 60, 180])
    }

    func test_nothingSelected_isPlainTimeOrder() {
        XCTAssertEqual(AlertPresets.displayOrder(presets: [300, 60, 180], selected: []),
                       [60, 180, 300])
    }

    func test_selectedPresetIsNotDuplicated() {
        // 켜진 시점이 프리셋에도 있는 흔한 경우 — 칩이 두 번 나오면 안 된다
        let order = AlertPresets.displayOrder(presets: [60, 180, 300], selected: [180])
        XCTAssertEqual(order, [180, 60, 300])
        XCTAssertEqual(Set(order).count, order.count)
    }

    func test_selectionOutsidePresets_stillAppearsFirst() {
        // 링에서 종을 끌어 만든 시점(프리셋에 없는 값)도 맨 앞에 온다
        let order = AlertPresets.displayOrder(presets: [60, 180], selected: [45, 240])
        XCTAssertEqual(order, [45, 240, 60, 180])
    }
}
