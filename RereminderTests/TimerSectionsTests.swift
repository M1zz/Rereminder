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

    // MARK: - 링 조각 → 구간 번호 (진행 중에도 색이 밀리지 않게)

    /// 링은 "남은 시간" 좌표라 순서가 반대다. 대기 화면(호가 전체)에서의 기본 매핑.
    func test_ringSectionIndex_mapsRemainingCoordinateBackToElapsedOrder() {
        // 10분 타이머, 알림 1·3·7분 전 → 구간 4개(경과 순서 0~3)
        let markers = [60.0, 180.0, 420.0]
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 60, markers: markers), 3,
                       "종료 직전 1분 조각 = 마지막 구간")
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 180, markers: markers), 2)
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 420, markers: markers), 1)
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 600, markers: markers), 0,
                       "시작 직후 조각 = 첫 구간")
    }

    /// 진행 중에는 지나간 경계가 호에서 빠져 조각 수가 줄어든다.
    /// 자리 번호로 세면 이때 남은 구간의 색이 통째로 한 칸씩 밀렸다.
    func test_ringSectionIndex_staysCorrectWhileSectionsElapse() {
        let markers = [60.0, 180.0, 420.0]

        // 남은 시간 5분: 7분 경계는 이미 지나가 호에 없다 → 조각은 [0,60] [60,180] [180,300]
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 60, markers: markers), 3)
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 180, markers: markers), 2)
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 300, markers: markers), 1,
                       "지금 지나는 중인 구간의 번호는 남은 조각 수와 무관하다")

        // 남은 시간 30초: 마지막 구간 하나만 남는다
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 30, markers: markers), 3)
    }

    func test_ringSectionIndex_withNoAlerts_isAlwaysTheFirstSection() {
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 600, markers: []), 0)
    }

    /// 링 좌표(1.0 = 한 바퀴)로 넘어와도 같은 규칙이 그대로 성립해야 한다 —
    /// 화면은 초가 아니라 이 단위로 부른다.
    func test_ringSectionIndex_worksInRingFractions() {
        // 10분 타이머 비율 좌표: 1분 전 = 0.1, 3분 전 = 0.3
        let markers = [0.1, 0.3]
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 0.1, markers: markers), 2)
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 0.3, markers: markers), 1)
        XCTAssertEqual(TimerSections.ringSectionIndex(segmentEnd: 1.0, markers: markers), 0)
    }

    // MARK: - 구간별 카운트다운 (원 아래 리스트)

    /// 45분을 20분 + 25분으로 나눈 경우 — 화면에서 실제로 벌어져야 하는 일.
    func test_remainingSeconds_onlyTheCurrentSectionCountsDown() {
        let segments = TimerSections.derive(mainSeconds: 2700, alertOffsets: [1500])   // 20분 + 25분
        XCTAssertEqual(segments.map(\.durationSec), [1200, 1500])

        // 시작 직후: 앞 구간만 줄고 뒤 구간은 통째로 서 있다
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[0], elapsedSec: 0), 1200)
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[1], elapsedSec: 0), 1500)

        // 5분 지남: 앞 구간만 5분 줄었다
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[0], elapsedSec: 300), 900)
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[1], elapsedSec: 300), 1500,
                       "뒤 구간은 앞 구간이 끝나기 전까지 줄지 않는다")

        // 20분 지나 경계를 넘음: 앞은 0, 이제 뒤가 줄기 시작한다
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[0], elapsedSec: 1200), 0)
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[1], elapsedSec: 1200), 1500)
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[1], elapsedSec: 1500), 1200)

        // 전부 끝남
        XCTAssertEqual(TimerSections.remainingSeconds(of: segments[1], elapsedSec: 2700), 0)
    }

    func test_phase_treatsTheBoundaryAsDone() {
        let segments = TimerSections.derive(mainSeconds: 2700, alertOffsets: [1500])

        XCTAssertEqual(TimerSections.phase(of: segments[0], elapsedSec: 0), .active)
        XCTAssertEqual(TimerSections.phase(of: segments[1], elapsedSec: 0), .upcoming)

        // 경계에 딱 걸리면 지나간 것으로 본다 — 그 순간 알림이 울리기 때문이다
        XCTAssertEqual(TimerSections.phase(of: segments[0], elapsedSec: 1200), .done)
        XCTAssertEqual(TimerSections.phase(of: segments[1], elapsedSec: 1200), .active)
    }

    /// 오버타임(설정 시간을 넘김)이면 모든 구간이 끝난 것으로 보여야 한다.
    func test_phase_afterOvertime_everySectionIsDone() {
        let segments = TimerSections.derive(mainSeconds: 600, alertOffsets: [60])
        for segment in segments {
            XCTAssertEqual(TimerSections.phase(of: segment, elapsedSec: 900), .done)
            XCTAssertEqual(TimerSections.remainingSeconds(of: segment, elapsedSec: 900), 0)
        }
    }
}
