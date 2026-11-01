//
//  AlertPresetOrderTests.swift
//  RereminderTests
//
//  `+` 가 켤 다음 알림 — 타이머 길이에 맞는 시간을 쓸모 있는 순서로.
//

import XCTest
@testable import Rereminder

final class AlertPresetOrderTests: XCTestCase {

    private func sequence(total: Int, raw: String = AlertPresets.defaultRaw, count: Int) -> [Int] {
        var selected = Set<Int>()
        var out: [Int] = []
        for _ in 0..<count {
            guard let next = AlertPresets.nextAlert(totalSeconds: total, presetsRaw: raw, selected: selected) else { break }
            out.append(next)
            selected.insert(next)
        }
        return out
    }

    func test_emphasis_timeOnly_andNotInsideLongerLabel() {
        let text = DialAlertLine.emphasized("11 min before, 1 min before", items: [
            .init(label: "11 min before", time: "11 min", color: .blue),
            .init(label: "1 min before", time: "1 min", color: .green),
        ])
        let strong = text.runs.filter { $0.inlinePresentationIntent == .stronglyEmphasized }
            .map { String(text[$0.range].characters) }
        XCTAssertEqual(strong, ["11 min", "1 min"])
    }

    func test_bellIndex_firstRingingBellIsFirstSection() {
        XCTAssertEqual(AlertPresets.bellSectionIndex(of: 600, among: [60, 300, 600]), 0)
        XCTAssertEqual(AlertPresets.bellSectionIndex(of: 60, among: [60, 300, 600]), 2)
    }

    func test_next_followsTimerLength() {
        XCTAssertEqual(sequence(total: 1800, count: 4), [300, 60, 600, 180])
        XCTAssertTrue(sequence(total: 30, count: 8).contains(20))
    }

    func test_next_neverReachesTheEnd_andNeverRepeats() {
        for total in [10, 30, 40, 90, 600, 3600, 7200] {
            let list = sequence(total: total, count: 12)
            XCTAssertTrue(list.allSatisfy { $0 < total }, "\(total)")
            XCTAssertEqual(Set(list).count, list.count, "\(total)")
        }
    }

    func test_next_customPresetsComeFirst() {
        XCTAssertEqual(AlertPresets.nextAlert(totalSeconds: 600, presetsRaw: "420", selected: []), 420)
    }

    func test_next_skipsWhatIsAlreadyOn() {
        XCTAssertEqual(AlertPresets.nextAlert(totalSeconds: 1800, presetsRaw: AlertPresets.defaultRaw, selected: [300]), 60)
    }
}
