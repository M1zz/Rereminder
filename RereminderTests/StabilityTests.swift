//
//  StabilityTests.swift
//  RereminderTests
//
//  크래시로 죽거나 멈춘 채 남을 수 있던 자리를 지킨다(2026-11-25 안정화).
//

import XCTest
@testable import Rereminder

final class StabilityTests: XCTestCase {

    // MARK: - 회 계산은 깨진 경과에도 죽지 않는다

    /// 무한대·NaN·아주 큰 경과가 `Int(...)` 에 그대로 들어가면 그 자리에서 앱이 죽는다.
    func test_roundIndex_survivesNonFiniteAndHugeElapsed() {
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: .infinity, roundSeconds: 90, rounds: 3), 0)
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: .nan, roundSeconds: 90, rounds: 3), 0)
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: 1e300, roundSeconds: 90, rounds: 3), 2)
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: -1e300, roundSeconds: 90, rounds: 3), 0)
        // 회 길이가 0 이어도 나누지 않는다
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: 10, roundSeconds: 0, rounds: 3), 0)
        // 회 수가 0 이하로 와도 첫 회다
        XCTAssertEqual(RoundSchedule.roundIndex(elapsed: 500, roundSeconds: 90, rounds: 0), 0)
    }

    func test_upcoming_withBrokenElapsed_doesNotCrash() {
        XCTAssertEqual(RoundSchedule.upcoming(roundSeconds: 90, rounds: 3, offsets: [30],
                                              after: .infinity, limit: 10), [])
        _ = RoundSchedule.upcoming(roundSeconds: 90, rounds: 3, offsets: [30], after: .nan, limit: 10)
    }

    // MARK: - 엔진의 틱은 메인 스레드에서 돈다

    /// 틱이 다른 스레드에서 돌면 정지·다른 기기에서 받은 타이머와 겹치는 순간 같은 값을 두 스레드가 고쳐 죽을 수 있었다.
    func test_engineTick_runsOnMainThread() {
        let engine = TimerEngine()
        defer { engine.stop() }
        let ticked = expectation(description: "tick")
        ticked.assertForOverFulfill = false
        var offMain = false
        engine.configure(mainSeconds: 600, prealertOffsetsSec: [], name: "")
        engine.start()
        engine.onTick = { _ in
            if !Thread.isMainThread { offMain = true }
            ticked.fulfill()
        }
        wait(for: [ticked], timeout: 3)
        XCTAssertFalse(offMain)
    }

    // MARK: - 돌지 않는 타이머에 온 일시정지·재개는 무시한다

    /// 워치가 보낸 "일시정지"는 이 기기에 타이머가 없을 때도 온다. 예전에는 화면만 "일시정지"가 되어
    /// 아무것도 돌지 않는 일시정지 화면이 남았다.
    @MainActor
    func test_pauseAndResume_whenIdle_changeNothing() {
        let vm = TimerViewModel()
        XCTAssertEqual(vm.state, .idle)
        vm.pause()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.engine.state, .idle)
        vm.resume()
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.engine.state, .idle)
    }

    // MARK: - 옛 템플릿의 구간 글

    /// 대본(`script`)이 생기기 전에 저장한 구간도 읽힌다 — 예전에는 통째로 못 읽혀 구간 이름이 빈 채로 열렸다.
    func test_presentationSection_decodesLegacyJSONWithoutNewKeys() throws {
        let legacy = #"[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"도입","durationSeconds":300,"alertAtEnd":false},{"name":"본론","durationSeconds":600}]"#
        let sections = try JSONDecoder().decode([PresentationSection].self, from: Data(legacy.utf8))
        XCTAssertEqual(sections.map(\.name), ["도입", "본론"])
        XCTAssertEqual(sections.map(\.script), ["", ""])
        XCTAssertEqual(sections.map(\.alertAtEnd), [false, true])
        XCTAssertEqual(sections[0].id.uuidString, "6F9619FF-8B86-D011-B42D-00C04FC964FF")

        // 새로 저장한 것은 그대로 오간다
        var section = PresentationSection(name: "질의", durationSeconds: 120)
        section.script = "질문 받기"
        let roundTrip = try JSONDecoder().decode(PresentationSection.self, from: JSONEncoder().encode(section))
        XCTAssertEqual(roundTrip, section)
    }

    // MARK: - Siri 명령은 오래 묵히지 않는다

    func test_siriCommand_expiresAndIsTakenOnce() {
        let suite = "rereminder.tests.siri.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date(timeIntervalSince1970: 10_000)

        SiriTimerCommand.post("stop", to: defaults, now: now)
        XCTAssertEqual(SiriTimerCommand.take(from: defaults, now: now.addingTimeInterval(5)), "stop")
        XCTAssertNil(SiriTimerCommand.take(from: defaults, now: now.addingTimeInterval(6)))

        // 몇 시간 묵은 "시작"은 버리고, 함께 남은 시간도 치운다
        SiriTimerCommand.post("start", to: defaults, now: now)
        defaults.set(600, forKey: "siriTimerDuration")
        XCTAssertNil(SiriTimerCommand.take(from: defaults, now: now.addingTimeInterval(3 * 3600)))
        XCTAssertNil(defaults.object(forKey: "siriTimerDuration"))

        // 시각이 없는 옛 기록도 버린다
        defaults.set("start", forKey: SiriTimerCommand.actionKey)
        XCTAssertNil(SiriTimerCommand.take(from: defaults, now: now))
    }
}
