//
//  RepeatDetectorTests.swift
//  RereminderTests
//
//  "같은 설정을 여러 날 반복하는가"를 앱이 알아채는 규칙.
//  이 기능의 성패는 **잔소리가 되지 않는 것**이라, 막는 조건들을 특히 촘촘히 지킨다.
//

import XCTest
@testable import Rereminder

final class RepeatDetectorTests: XCTestCase {

    private static let suiteName = "RepeatDetectorTests.suite"
    private var suite: UserDefaults!

    /// 10분 + 1분 전 알림
    private let config = RepeatDetector.Config(mainSec: 600, offsets: [60])
    private let other = RepeatDetector.Config(mainSec: 1800, offsets: [300, 60])

    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Int) -> Date { day0.addingTimeInterval(Double(n) * 86_400) }

    override func setUpWithError() throws {
        try super.setUpWithError()
        suite = UserDefaults(suiteName: Self.suiteName)
        suite.removePersistentDomain(forName: Self.suiteName)
        RepeatDetector.defaults = suite
        // 요일·시각 판정이 실행 환경의 시간대에 휘둘리면 테스트가 기계마다 달라진다.
        var fixed = Calendar(identifier: .gregorian)
        fixed.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        RepeatDetector.calendar = fixed
    }

    override func tearDownWithError() throws {
        suite.removePersistentDomain(forName: Self.suiteName)
        RepeatDetector.defaults = .standard
        RepeatDetector.calendar = .current
        try super.tearDownWithError()
    }

    // MARK: - 지문

    func test_config_ignoresOffsetOrderAndOutOfRangeAlerts() {
        let a = RepeatDetector.Config(mainSec: 600, offsets: [300, 60])
        let b = RepeatDetector.Config(mainSec: 600, offsets: [60, 300])
        XCTAssertEqual(a, b, "순서가 다르다고 다른 설정이 되면 반복이 영영 안 잡힌다")

        // 전체 시간 밖의 알림은 울리지도 않는다 — 지문에서 뺀다
        let c = RepeatDetector.Config(mainSec: 600, offsets: [60, 900])
        XCTAssertEqual(c.offsets, [60])
    }

    // MARK: - 날짜 세기

    func test_sameDayRunsCountAsOneDay() {
        RepeatDetector.record(config, now: day(0))
        RepeatDetector.record(config, now: day(0).addingTimeInterval(3600))
        RepeatDetector.record(config, now: day(0).addingTimeInterval(7200))

        XCTAssertEqual(RepeatDetector.distinctDays(of: config, now: day(0)), 1,
                       "같은 날 여러 번은 한 번의 상황이지 반복이 아니다")
        XCTAssertFalse(RepeatDetector.shouldPropose(config, isAlreadySaved: false, now: day(0)))
    }

    func test_twoDistinctDays_makeItRecurring() {
        RepeatDetector.record(config, now: day(0))
        RepeatDetector.record(config, now: day(1))

        XCTAssertEqual(RepeatDetector.distinctDays(of: config, now: day(1)), 2)
        XCTAssertTrue(RepeatDetector.shouldPropose(config, isAlreadySaved: false, now: day(1)))
    }

    func test_oldDaysAreForgotten() {
        RepeatDetector.record(config, now: day(0))
        RepeatDetector.record(config, now: day(1))

        // 기억 기간을 한참 넘긴 시점 — 지난달 습관으로 오늘 제안하면 엉뚱하다
        let later = day(RepeatDetector.memoryDays + 10)
        XCTAssertEqual(RepeatDetector.distinctDays(of: config, now: later), 0)
        XCTAssertFalse(RepeatDetector.shouldPropose(config, isAlreadySaved: false, now: later))
    }

    func test_differentConfigsAreCountedSeparately() {
        RepeatDetector.record(config, now: day(0))
        RepeatDetector.record(config, now: day(1))
        RepeatDetector.record(other, now: day(0))

        XCTAssertEqual(RepeatDetector.distinctDays(of: config, now: day(1)), 2)
        XCTAssertEqual(RepeatDetector.distinctDays(of: other, now: day(1)), 1)
    }

    // MARK: - 잔소리 방지

    func test_doesNotProposeWhatIsAlreadySaved() {
        RepeatDetector.record(config, now: day(0))
        RepeatDetector.record(config, now: day(1))

        XCTAssertFalse(RepeatDetector.shouldPropose(config, isAlreadySaved: true, now: day(1)),
                       "이미 템플릿으로 있는 설정은 후보가 아니다")
    }

    func test_proposesEachConfigOnlyOnce_evenIfDeclined() {
        RepeatDetector.record(config, now: day(0))
        RepeatDetector.record(config, now: day(1))
        XCTAssertTrue(RepeatDetector.shouldPropose(config, isAlreadySaved: false, now: day(1)))

        RepeatDetector.markProposed(config)

        // 거절했든 저장했든 다시 묻지 않는다
        RepeatDetector.record(config, now: day(2))
        XCTAssertFalse(RepeatDetector.shouldPropose(config, isAlreadySaved: false, now: day(2)))
    }

    func test_stopsAfterTheProposalLimit() {
        for index in 0..<RepeatDetector.maxProposals {
            RepeatDetector.markProposed(.init(mainSec: 600 + index * 60, offsets: [60]))
        }
        XCTAssertEqual(RepeatDetector.proposalCount, RepeatDetector.maxProposals)

        RepeatDetector.record(other, now: day(0))
        RepeatDetector.record(other, now: day(1))
        XCTAssertFalse(RepeatDetector.shouldPropose(other, isAlreadySaved: false, now: day(1)),
                       "상한을 넘으면 아무리 반복해도 더는 말을 걸지 않는다")
    }

    func test_markProposedIsIdempotent() {
        RepeatDetector.markProposed(config)
        RepeatDetector.markProposed(config)
        XCTAssertEqual(RepeatDetector.proposalCount, 1,
                       "같은 설정을 두 번 세면 상한이 실제보다 빨리 찬다")
    }

    // MARK: - 지문 왕복

    func test_configRoundTripsThroughFingerprint() {
        let restored = RepeatDetector.Config(fingerprint: config.fingerprint)
        XCTAssertEqual(restored, config, "시간대 제안은 저장된 지문에서 설정을 되살려야 한다")

        // 알림이 없는 설정도 되살아나야 한다(지문 뒤가 빈 문자열)
        let bare = RepeatDetector.Config(mainSec: 600, offsets: [])
        XCTAssertEqual(RepeatDetector.Config(fingerprint: bare.fingerprint), bare)

        XCTAssertNil(RepeatDetector.Config(fingerprint: "쓰레기"))
    }

    // MARK: - 시간대 제안 ("지금이 그 시간인가")

    /// 서울 기준 특정 요일·시각의 Date
    private func at(day n: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 2 + n          // 2026-03-02 = 월요일
        components.hour = hour
        return RepeatDetector.calendar.date(from: components)!
    }

    func test_suggestsWhenSameWeekdayAndHourRepeatedOnDifferentDays() {
        // 월요일 오후 3시에 두 번(다른 주)
        RepeatDetector.record(config, now: at(day: 0, hour: 15))
        RepeatDetector.record(config, now: at(day: 7, hour: 15))

        XCTAssertEqual(RepeatDetector.timeOfDaySuggestion(now: at(day: 14, hour: 15)), config)
    }

    func test_doesNotSuggestOnADifferentWeekday() {
        RepeatDetector.record(config, now: at(day: 0, hour: 15))
        RepeatDetector.record(config, now: at(day: 7, hour: 15))

        // 화요일 같은 시각 — 요일이 다르면 같은 상황이 아니다
        XCTAssertNil(RepeatDetector.timeOfDaySuggestion(now: at(day: 15, hour: 15)))
    }

    func test_doesNotSuggestAtAFarOffHour() {
        RepeatDetector.record(config, now: at(day: 0, hour: 15))
        RepeatDetector.record(config, now: at(day: 7, hour: 15))

        XCTAssertNil(RepeatDetector.timeOfDaySuggestion(now: at(day: 14, hour: 9)))
    }

    func test_toleratesAnHourEitherSide() {
        RepeatDetector.record(config, now: at(day: 0, hour: 15))
        RepeatDetector.record(config, now: at(day: 7, hour: 15))

        // 3시에 하던 일을 2시에 열어도 같은 상황으로 본다
        XCTAssertEqual(RepeatDetector.timeOfDaySuggestion(now: at(day: 14, hour: 14)), config)
        XCTAssertEqual(RepeatDetector.timeOfDaySuggestion(now: at(day: 14, hour: 16)), config)
    }

    func test_sameDayRepeatsDoNotMakeATimeSuggestion() {
        // 같은 날 같은 시각대에 두 번 — 한 번의 상황이지 "매주 그 시간"이 아니다
        RepeatDetector.record(config, now: at(day: 0, hour: 15))
        RepeatDetector.record(config, now: at(day: 0, hour: 16))

        XCTAssertNil(RepeatDetector.timeOfDaySuggestion(now: at(day: 7, hour: 15)))
    }

    func test_suggestsEachConfigOnlyOnce() {
        RepeatDetector.record(config, now: at(day: 0, hour: 15))
        RepeatDetector.record(config, now: at(day: 7, hour: 15))
        XCTAssertNotNil(RepeatDetector.timeOfDaySuggestion(now: at(day: 14, hour: 15)))

        RepeatDetector.markTimeSuggested(config)
        XCTAssertNil(RepeatDetector.timeOfDaySuggestion(now: at(day: 21, hour: 15)),
                     "수락하든 거절하든 같은 설정을 다시 권하지 않는다")
    }

    func test_stopsAfterTheTimeSuggestionLimit() {
        for index in 0..<RepeatDetector.maxTimeSuggestions {
            RepeatDetector.markTimeSuggested(.init(mainSec: 600 + index * 60, offsets: [60]))
        }
        RepeatDetector.record(other, now: at(day: 0, hour: 15))
        RepeatDetector.record(other, now: at(day: 7, hour: 15))

        XCTAssertNil(RepeatDetector.timeOfDaySuggestion(now: at(day: 14, hour: 15)),
                     "상한을 넘으면 아무리 되풀이해도 더는 말을 걸지 않는다")
    }

    func test_picksTheMoreRepeatedConfigWhenTwoMatch() {
        // config: 두 주, other: 세 주 — 더 자주 되풀이된 쪽을 권한다
        RepeatDetector.record(config, now: at(day: 0, hour: 15))
        RepeatDetector.record(config, now: at(day: 7, hour: 15))
        RepeatDetector.record(other, now: at(day: 0, hour: 15))
        RepeatDetector.record(other, now: at(day: 7, hour: 15))
        RepeatDetector.record(other, now: at(day: 14, hour: 15))

        XCTAssertEqual(RepeatDetector.timeOfDaySuggestion(now: at(day: 21, hour: 15)), other)
    }
}
