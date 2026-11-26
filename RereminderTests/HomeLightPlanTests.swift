//
//  HomeLightPlanTests.swift
//  RereminderTests
//
//  조명 색이 링의 구간 색과 같은 구간을 가리키는지 지킨다(`HomeLightAlert.swift`).
//

import XCTest
@testable import Rereminder

final class HomeLightPlanTests: XCTestCase {

    /// 표가 링 팔레트와 개수가 같아야 "방이 파래졌다 = 링의 파란 구간"이 맞는다.
    func test_shadeTableMatchesSectionPalette() {
        XCTAssertEqual(HomeLightPlan.sectionShades.count, SectionPalette.count)
    }

    /// 10분에 3분 전·1분 전 — 3분 전 종이 울리면 2구간(1번), 1분 전 종이면 3구간(2번)이 시작된다.
    func test_bellStartsTheNextSection() {
        let offsets = [180, 60]
        XCTAssertEqual(HomeLightPlan.sectionStarting(afterBell: 180, among: offsets), 1)
        XCTAssertEqual(HomeLightPlan.sectionStarting(afterBell: 60, among: offsets), 2)
    }

    /// 알림 순서가 뒤섞여 저장돼 있어도 같은 답이다.
    func test_orderOfOffsetsDoesNotMatter() {
        XCTAssertEqual(HomeLightPlan.sectionStarting(afterBell: 60, among: [60, 300, 180]), 3)
    }

    /// 구간이 팔레트보다 많으면 처음부터 다시 쓴다 — 링과 같다.
    func test_shadesWrapLikeThePalette() {
        XCTAssertEqual(HomeLightPlan.shade(forSection: SectionPalette.count), HomeLightPlan.shade(forSection: 0))
    }

    /// 끝은 빨강, 어느 구간 색과도 겹치지 않는다.
    func test_finishIsDistinct() {
        XCTAssertFalse(HomeLightPlan.sectionShades.contains(HomeLightPlan.finish))
    }

    /// 기본값은 꺼짐·잠깐 바뀌기.
    func test_defaultsAreOff() {
        let d = UserDefaults.standard
        let saved = (d.object(forKey: HomeLightSettings.enabledKey), d.object(forKey: HomeLightSettings.modeKey))
        d.removeObject(forKey: HomeLightSettings.enabledKey)
        d.removeObject(forKey: HomeLightSettings.modeKey)
        XCTAssertFalse(HomeLightSettings.isEnabled)
        XCTAssertEqual(HomeLightSettings.mode, .flash)
        d.set(saved.0, forKey: HomeLightSettings.enabledKey)
        d.set(saved.1, forKey: HomeLightSettings.modeKey)
    }
}
