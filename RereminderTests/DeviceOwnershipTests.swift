//
//  DeviceOwnershipTests.swift
//  RereminderTests
//
//  "워치 있으세요?"를 언제 묻고 언제 입을 다무는지의 규칙 검증.
//
//  이 규칙이 조용히 틀어지면 앱이 무례해진다 — 없다고 한 사람에게 계속 묻거나,
//  이미 워치로 잘 쓰는 사람에게 워치를 권하거나, 첫 타이머부터 질문을 던지게 된다.
//

import XCTest
@testable import Rereminder

final class DeviceOwnershipTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var suiteName = ""

    /// ⚠️ 앱의 실제 저장소를 쓰면 시뮬레이터에 남아 있던 값(손으로 확인하다 넣어 둔 것 등)이
    ///    그대로 새어 들어와 테스트가 엉뚱하게 실패한다. 매번 빈 suite 를 꽂는다.
    override func setUp() {
        super.setUp()
        suiteName = "DeviceOwnershipTests.\(UUID().uuidString)"
        DeviceOwnership.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    override func tearDown() {
        DeviceOwnership.defaults.removePersistentDomain(forName: suiteName)
        DeviceOwnership.defaults = .standard
        super.tearDown()
    }

    // MARK: - 언제 묻나

    func test_nextQuestion_staysQuietUntilTheAppHasActuallyBeenUsed() {
        XCTAssertNil(DeviceOwnership.nextQuestion(watch: .unknown, mac: .unknown,
                                                  timerStarts: DeviceOwnership.minTimerStarts - 1,
                                                  lastAskedAt: nil, now: now),
                     "첫 타이머부터 질문을 던지지 않는다")
        XCTAssertEqual(DeviceOwnership.nextQuestion(watch: .unknown, mac: .unknown,
                                                    timerStarts: DeviceOwnership.minTimerStarts,
                                                    lastAskedAt: nil, now: now),
                       .watch)
    }

    func test_nextQuestion_asksWatchFirstThenMac() {
        XCTAssertEqual(DeviceOwnership.nextQuestion(watch: .yes, mac: .unknown,
                                                    timerStarts: 5, lastAskedAt: nil, now: now),
                       .mac)
        XCTAssertEqual(DeviceOwnership.nextQuestion(watch: .no, mac: .unknown,
                                                    timerStarts: 5, lastAskedAt: nil, now: now),
                       .mac,
                       "워치가 없다고 해도 맥은 따로 물어볼 수 있다")
    }

    func test_nextQuestion_neverAsksAgainOnceAnswered() {
        for watch in [DeviceOwnership.Answer.yes, .no] {
            for mac in [DeviceOwnership.Answer.yes, .no] {
                XCTAssertNil(DeviceOwnership.nextQuestion(watch: watch, mac: mac,
                                                          timerStarts: 50, lastAskedAt: nil, now: now),
                             "이미 답한 기기는 다시 묻지 않는다 (watch=\(watch), mac=\(mac))")
            }
        }
    }

    func test_nextQuestion_asksOneQuestionPerDay() {
        let justAsked = now.addingTimeInterval(-DeviceOwnership.askCooldown + 60)
        XCTAssertNil(DeviceOwnership.nextQuestion(watch: .yes, mac: .unknown,
                                                  timerStarts: 5, lastAskedAt: justAsked, now: now),
                     "워치를 방금 물어봤으면 맥은 내일 묻는다")

        let dayAgo = now.addingTimeInterval(-DeviceOwnership.askCooldown - 60)
        XCTAssertEqual(DeviceOwnership.nextQuestion(watch: .yes, mac: .unknown,
                                                    timerStarts: 5, lastAskedAt: dayAgo, now: now),
                       .mac)
    }

    // MARK: - 언제 권하나

    private func input(_ answer: DeviceOwnership.Answer,
                       used: Bool = false,
                       shown: Int = 0,
                       lastShownAtStart: Int = 0) -> DeviceOwnership.ReminderInput {
        DeviceOwnership.ReminderInput(answer: answer, hasUsed: used,
                                      shownCount: shown, lastShownAtStart: lastShownAtStart)
    }

    func test_dueReminder_onlyForDevicesTheUserSaidTheyHave() {
        let starts = DeviceOwnership.reminderInterval
        XCTAssertEqual(DeviceOwnership.dueReminder(watch: input(.yes), mac: input(.no), timerStarts: starts),
                       .watch)
        XCTAssertNil(DeviceOwnership.dueReminder(watch: input(.no), mac: input(.no), timerStarts: starts),
                     "없다고 한 기기는 권하지도 않는다")
        XCTAssertNil(DeviceOwnership.dueReminder(watch: input(.unknown), mac: input(.unknown), timerStarts: starts),
                     "아직 안 물어본 기기를 먼저 권하지 않는다")
    }

    func test_dueReminder_stopsOnceTheDeviceIsActuallyUsed() {
        let starts = DeviceOwnership.reminderInterval
        XCTAssertNil(DeviceOwnership.dueReminder(watch: input(.yes, used: true),
                                                 mac: input(.no),
                                                 timerStarts: starts),
                     "이미 워치로 쓰는 사람에게 워치를 권하면 잔소리다")
        XCTAssertEqual(DeviceOwnership.dueReminder(watch: input(.yes, used: true),
                                                   mac: input(.yes),
                                                   timerStarts: starts),
                       .mac,
                       "워치는 이미 쓰고 있으면 맥으로 넘어간다")
    }

    func test_dueReminder_waitsAFewRunsAfterTheLastOneAndStopsAtThree() {
        let interval = DeviceOwnership.reminderInterval

        // 방금 권했으면 바로 다음 타이머에서 또 권하지 않는다.
        XCTAssertNil(DeviceOwnership.dueReminder(watch: input(.yes, shown: 1, lastShownAtStart: 10),
                                                 mac: input(.no),
                                                 timerStarts: 10 + interval - 1),
                     "권한 직후에는 조용하다")
        XCTAssertEqual(DeviceOwnership.dueReminder(watch: input(.yes, shown: 1, lastShownAtStart: 10),
                                                   mac: input(.no),
                                                   timerStarts: 10 + interval),
                       .watch)
        XCTAssertNil(DeviceOwnership.dueReminder(watch: input(.yes, shown: DeviceOwnership.reminderMaxCount),
                                                 mac: input(.no),
                                                 timerStarts: interval * 4),
                     "세 번까지만 권한다")
    }

    /// "시작 횟수가 5의 배수일 때"로 만들면 그 한 번을 놓쳤을 때 안내가 영영 안 뜬다.
    /// (시작 횟수를 올리는 것과 이 판정이 같은 순간에 일어나 한 칸 어긋난 적이 있다.)
    func test_dueReminder_doesNotDependOnHittingAnExactMultiple() {
        for starts in (DeviceOwnership.minTimerStarts + DeviceOwnership.reminderInterval)...20 {
            XCTAssertEqual(DeviceOwnership.dueReminder(watch: input(.yes), mac: input(.no),
                                                       timerStarts: starts),
                           .watch,
                           "한 번도 안 권했다면 언제 걸든 다음 타이머에서 뜬다 (starts=\(starts))")
        }
    }

    // MARK: - 저장

    func test_record_and_markUsed_keepTheAnswerAndSilenceFurtherQuestions() {
        XCTAssertEqual(DeviceOwnership.answer(for: .watch), .unknown)

        DeviceOwnership.record(.no, for: .watch, now: now)
        XCTAssertEqual(DeviceOwnership.answer(for: .watch), .no)
        XCTAssertNil(DeviceOwnership.nextQuestion(watch: DeviceOwnership.answer(for: .watch),
                                                  mac: .no, timerStarts: 99, lastAskedAt: nil, now: now))

        // 실제로 맥에서 돌고 있으면 묻지 않아도 "있음"이 확정된다.
        DeviceOwnership.markUsed(.mac)
        XCTAssertEqual(DeviceOwnership.answer(for: .mac), .yes)
        XCTAssertTrue(DeviceOwnership.hasUsed(.mac))
    }

    func test_confirmOwned_marksOwnershipWithoutClaimingUse() {
        // 페어링된 워치 — 가지고 있는 건 확실하지만 이 앱을 워치에서 써 본 건 아니다.
        DeviceOwnership.confirmOwned(.watch)
        XCTAssertEqual(DeviceOwnership.answer(for: .watch), .yes)
        XCTAssertFalse(DeviceOwnership.hasUsed(.watch), "소유 확정이 사용 확정으로 번지면 안내가 사라진다")
    }
}
