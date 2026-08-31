//
//  WatchTimerStateTests.swift
//  RereminderTests
//
//  워치 앱과 스마트 스택 위젯은 **다른 프로세스**라, 둘이 같은 숫자를 말하게 하는 유일한 장치가
//  `WatchTimerState` 의 계산과 `WatchTimerStore` 의 저장이다. 여기가 어긋나면 손목의 화면과
//  스마트 스택 카드가 서로 다른 남은 시간을 보여준다.
//

import XCTest
@testable import Rereminder

final class WatchTimerStateTests: XCTestCase {

    /// 기준 시각 하나로 모든 계산을 검사한다 — `Date()` 를 쓰면 실행 시각에 따라 흔들린다.
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func state(duration: Int = 1800,
                       offsets: [Int] = [600, 300, 60],
                       isPaused: Bool = false,
                       accumulatedPause: TimeInterval = 0,
                       pauseDate: Date? = nil) -> WatchTimerState {
        WatchTimerState(mainDuration: duration,
                        prealertOffsets: offsets,
                        startDate: start,
                        isPaused: isPaused,
                        accumulatedPause: accumulatedPause,
                        pauseDate: pauseDate)
    }

    // MARK: - 남은 시간

    func test_running_countsDownFromStart() {
        let sut = state()
        XCTAssertEqual(sut.remainingSeconds(at: start), 1800)
        XCTAssertEqual(sut.remainingSeconds(at: start.addingTimeInterval(300)), 1500)
    }

    /// 멈춰 있는 동안에는 시간이 흘러도 숫자가 그대로여야 한다.
    /// (위젯은 앱이 꺼진 뒤에도 계속 그려지므로, 여기서 흐르면 일시정지가 거짓말이 된다.)
    func test_paused_freezesAtPauseMoment() {
        let paused = start.addingTimeInterval(500)
        let sut = state(isPaused: true, pauseDate: paused)

        XCTAssertEqual(sut.remainingSeconds(at: paused), 1300)
        XCTAssertEqual(sut.remainingSeconds(at: paused.addingTimeInterval(3600)), 1300,
                       "일시정지 중에는 바깥 시간이 아무리 흘러도 남은 시간이 변하지 않아야 한다")
    }

    /// 멈췄다 다시 시작하면 멈춰 있던 만큼이 경과에서 빠진다.
    func test_accumulatedPause_isSubtractedFromElapsed() {
        let sut = state(accumulatedPause: 120)
        XCTAssertEqual(sut.remainingSeconds(at: start.addingTimeInterval(300)), 1620)
    }

    func test_isActive_isFalseOnceTimeIsUp() {
        let sut = state(duration: 600, offsets: [60])
        XCTAssertTrue(sut.isActive(at: start.addingTimeInterval(599)))
        XCTAssertFalse(sut.isActive(at: start.addingTimeInterval(600)))
        XCTAssertFalse(sut.isActive(at: start.addingTimeInterval(900)))
    }

    // MARK: - 종료 시각 (시스템 카운트다운이 보는 값)

    /// `Text(timerInterval:)` 는 이 값 하나로 초를 센다 — 앱이 꺼져 있어도 정확한 이유.
    func test_endDate_shiftsByPausedTime() {
        XCTAssertEqual(state().endDate, start.addingTimeInterval(1800))
        XCTAssertEqual(state(accumulatedPause: 120).endDate, start.addingTimeInterval(1920))
    }

    /// 멈춰 있는데 종료 시각을 주면 위젯이 흘러가는 카운트다운을 그린다 — 그건 거짓말이다.
    func test_endDate_isNilWhilePaused() {
        XCTAssertNil(state(isPaused: true, pauseDate: start.addingTimeInterval(60)).endDate)
    }

    // MARK: - 다음 알림 (이 위젯이 기본 타이머 위젯과 다른 이유)

    /// 알림은 "종료 O초 전"이므로 곧 울릴 것은 남은 시간보다 작은 offset 중 **가장 큰** 것이다.
    func test_nextAlert_isTheSoonestOneStillAhead() {
        let sut = state()  // 30분 + 10분·5분·1분 전

        // 시작 직후 → 10분 전 알림이 20분 뒤에 울린다
        XCTAssertEqual(sut.nextAlertDate(at: start), start.addingTimeInterval(1200))
        // 10분 전 알림을 지난 뒤(남은 9분) → 다음은 5분 전
        let after = start.addingTimeInterval(1260)
        XCTAssertEqual(sut.nextAlertDate(at: after), start.addingTimeInterval(1500))
    }

    /// 지금 막 울리는 알림은 "다음"이 아니다 — 그대로 두면 0:00 이 그 자리에 붙박인다.
    func test_nextAlert_skipsTheOneFiringRightNow() {
        let sut = state()
        let atTenMinuteMark = start.addingTimeInterval(1200)   // 남은 시간 == 600
        XCTAssertEqual(sut.nextAlertDate(at: atTenMinuteMark), start.addingTimeInterval(1500))
    }

    func test_nextAlert_isNilInTheLastSectionAndAfterTheEnd() {
        let sut = state()
        XCTAssertNil(sut.nextAlertDate(at: start.addingTimeInterval(1790)), "마지막 구간에는 다음 알림이 없다")
        XCTAssertNil(sut.nextAlertDate(at: start.addingTimeInterval(1800)))
    }

    // MARK: - 구간 (아이폰·워치 화면과 같은 답이어야 한다)

    func test_section_matchesTimerSections() {
        let sut = state()
        let elapsed = 1300
        let expected = TimerSections.progress(mainSeconds: 1800,
                                              alertOffsets: [600, 300, 60],
                                              elapsedSec: elapsed)
        XCTAssertEqual(sut.section(at: start.addingTimeInterval(TimeInterval(elapsed))), expected)
        // 30분을 10분·5분·1분 전으로 나누면 구간은 4개(0~20 / 20~25 / 25~29 / 29~30분).
        // 경과 1300초(21분 40초)는 두 번째 구간 — 카드에 "2/4" 로 붙는다.
        XCTAssertEqual(sut.section(at: start.addingTimeInterval(TimeInterval(elapsed)))?.index, 1)
        XCTAssertEqual(sut.section(at: start.addingTimeInterval(TimeInterval(elapsed)))?.totalCount, 4)
    }

    // MARK: - 타임라인 갱신 시점

    /// 새 항목이 필요한 건 표시가 바뀌는 순간뿐이다 — 알림 경계와 종료.
    func test_refreshDates_areAlertBoundariesAndEnd_futureOnlySorted() {
        let sut = state()
        XCTAssertEqual(sut.refreshDates(after: start), [
            start.addingTimeInterval(1200),   // 10분 전 알림
            start.addingTimeInterval(1500),   // 5분 전 알림
            start.addingTimeInterval(1740),   // 1분 전 알림
            start.addingTimeInterval(1800)    // 종료
        ])

        // 이미 지난 경계는 빠진다
        XCTAssertEqual(sut.refreshDates(after: start.addingTimeInterval(1300)), [
            start.addingTimeInterval(1500),
            start.addingTimeInterval(1740),
            start.addingTimeInterval(1800)
        ])
    }

    /// 멈춰 있으면 바뀔 것이 없다 — 항목을 세우면 위젯 갱신 예산만 쓴다.
    func test_refreshDates_areEmptyWhilePaused() {
        let sut = state(isPaused: true, pauseDate: start.addingTimeInterval(60))
        XCTAssertTrue(sut.refreshDates(after: start.addingTimeInterval(60)).isEmpty)
    }

    // MARK: - 저장소

    func test_store_roundTripsAndClears() {
        let (shared, legacy) = useTemporaryStores()
        defer { restoreStores() }

        let sut = state(accumulatedPause: 30, pauseDate: nil)
        WatchTimerStore.save(sut)
        XCTAssertEqual(WatchTimerStore.load(), sut)

        WatchTimerStore.clear()
        XCTAssertNil(WatchTimerStore.load())
        XCTAssertFalse(shared.bool(forKey: "watchTimer.active"))
        XCTAssertFalse(legacy.bool(forKey: "watchTimer.active"))
    }

    /// 타이머가 도는 **중에 업데이트한 사용자**의 복원이 끊기지 않아야 한다
    /// (2.2.2 이하는 앱 전용 저장소에 적었다).
    func test_store_fallsBackToLegacyStore_forAnInFlightUpgrade() {
        let (_, legacy) = useTemporaryStores()
        defer { restoreStores() }

        legacy.set(true, forKey: "watchTimer.active")
        legacy.set(1800, forKey: "watchTimer.mainDuration")
        legacy.set([300], forKey: "watchTimer.prealertOffsets")
        legacy.set(start.timeIntervalSince1970, forKey: "watchTimer.startDate")

        let loaded = WatchTimerStore.load()
        XCTAssertEqual(loaded?.mainDuration, 1800)
        XCTAssertEqual(loaded?.prealertOffsets, [300])
        XCTAssertEqual(loaded?.startDate, start)
    }

    /// ⚠️ 옛 저장소를 남겨 두면 이미 끝난 타이머가 되살아나 위젯에 유령 카드가 선다.
    func test_clear_alsoWipesLegacyStore_soNoGhostTimerComesBack() {
        let (_, legacy) = useTemporaryStores()
        defer { restoreStores() }

        legacy.set(true, forKey: "watchTimer.active")
        legacy.set(1800, forKey: "watchTimer.mainDuration")
        legacy.set(start.timeIntervalSince1970, forKey: "watchTimer.startDate")

        WatchTimerStore.clear()
        XCTAssertNil(WatchTimerStore.load())
    }

    // MARK: - 테스트용 저장소

    private var savedShared: UserDefaults?
    private var savedLegacy: UserDefaults?

    /// 시뮬레이터의 실제 앱 그룹을 건드리지 않도록 임시 스위트를 끼운다.
    private func useTemporaryStores() -> (shared: UserDefaults, legacy: UserDefaults) {
        savedShared = WatchTimerStore.shared
        savedLegacy = WatchTimerStore.legacy

        let sharedName = "test.watchTimer.shared.\(UUID().uuidString)"
        let legacyName = "test.watchTimer.legacy.\(UUID().uuidString)"
        let shared = UserDefaults(suiteName: sharedName)!
        let legacy = UserDefaults(suiteName: legacyName)!
        temporarySuiteNames = [sharedName, legacyName]

        WatchTimerStore.shared = shared
        WatchTimerStore.legacy = legacy
        return (shared, legacy)
    }

    private var temporarySuiteNames: [String] = []

    private func restoreStores() {
        for name in temporarySuiteNames {
            UserDefaults().removePersistentDomain(forName: name)
        }
        temporarySuiteNames = []
        if let savedShared { WatchTimerStore.shared = savedShared }
        if let savedLegacy { WatchTimerStore.legacy = savedLegacy }
    }
}
