//
//  DeviceOwnership.swift
//  Rereminder
//
//  "이 사람은 워치·맥을 가지고 있나"를 **직접 물어보고 기억하는** 곳.
//
//  왜 필요한가: 이 앱은 아이폰 말고도 워치·맥에서 남은 시간을 볼 수 있는데, 그걸 아는 사람이 드물다.
//  그렇다고 모두에게 "워치에서도 보세요"라고 하면 워치가 없는 사람에게는 소음일 뿐이다.
//  그래서 **타이머를 실제로 쓰는 중에 한 번 물어보고**, 그 답을 계속 존중한다:
//   • "없어요" → 그 기기 이야기는 다시 꺼내지 않는다 (안내도, 질문도)
//   • "있어요" → 설정에 저장하고, 그 기기에서 아직 안 써 봤다면 가끔 권한다
//
//  묻지 않아도 아는 경우가 있다 — 워치가 페어링돼 있거나 Mac Catalyst로 실행 중이면 그 기기는
//  **있는 것으로 확정**하고 질문을 건너뛴다(`confirmOwned`). 워치에서 조작이 오면 사용까지
//  확정된다(`markUsed`) — 그때부터는 권하는 안내도 멈춘다.
//
//  ⚠️ 판정은 전부 순수 함수(`nextQuestion` / `dueReminder`)로 두고 저장소 접근과 분리한다 —
//     유닛 테스트 대상(`RereminderTests/DeviceOwnershipTests.swift`). 물어보는 규칙이 조용히
//     바뀌면 "없다고 했는데 또 물어보는" 앱이 된다.
//

import Foundation

enum DeviceOwnership {

    // MARK: - 값

    /// 아직 안 물어봤는지(`unknown`), 있다고 했는지(`yes`), 없다고 했는지(`no`).
    /// ⚠️ `unknown`과 `no`를 하나로 합치지 말 것 — "아직 모름"은 물어봐도 되지만 "없음"은 아니다.
    enum Answer: String, CaseIterable, Identifiable {
        case unknown, yes, no
        var id: String { rawValue }
    }

    /// 물어볼 수 있는 기기.
    enum Device: String, CaseIterable, Identifiable {
        case watch, mac
        var id: String { rawValue }
    }

    // MARK: - 정책 상수

    /// 이만큼 타이머를 걸어 본 다음부터 묻는다 — 처음 쓰는 사람에게 첫 타이머부터 질문을 던지지 않는다.
    static let minTimerStarts = 2
    /// 질문 사이 최소 간격 — 한 번에 하나씩만 묻는다(워치 먼저, 맥은 다음 날).
    static let askCooldown: TimeInterval = 24 * 3600
    /// "있다"고 한 기기를 아직 안 쓸 때, 타이머를 몇 번 더 건 뒤에 다시 권할지.
    static let reminderInterval = 5
    /// 같은 기기를 권하는 최대 횟수 — 이 이상은 잔소리다.
    static let reminderMaxCount = 3

    // MARK: - 판정 (순수 함수)

    /// 지금 물어볼 질문. 없으면 nil.
    /// - Parameters:
    ///   - timerStarts: 지금까지 타이머를 시작한 횟수(`UsageMetrics.timerStarts`).
    ///   - lastAskedAt: 마지막으로 물어본 시각. 한 번도 안 물었으면 nil.
    static func nextQuestion(watch: Answer,
                             mac: Answer,
                             timerStarts: Int,
                             lastAskedAt: Date?,
                             now: Date = Date()) -> Device? {
        guard timerStarts >= minTimerStarts else { return nil }
        if let lastAskedAt, now.timeIntervalSince(lastAskedAt) < askCooldown { return nil }
        if watch == .unknown { return .watch }
        if mac == .unknown { return .mac }
        return nil
    }

    /// 한 기기에 대해 "권해도 되는 상태인가"를 판정하는 데 필요한 것.
    struct ReminderInput {
        let answer: Answer
        /// 그 기기에서 실제로 써 본 적이 있는지 — 이미 쓰는 사람에게 권하면 잔소리다.
        let hasUsed: Bool
        /// 지금까지 권한 횟수.
        let shownCount: Int
        /// 마지막으로 권했을 때의 타이머 시작 횟수(한 번도 안 권했으면 0).
        let lastShownAtStart: Int

        init(answer: Answer, hasUsed: Bool, shownCount: Int, lastShownAtStart: Int = 0) {
            self.answer = answer
            self.hasUsed = hasUsed
            self.shownCount = shownCount
            self.lastShownAtStart = lastShownAtStart
        }
    }

    /// 타이머를 걸 때 "그 기기에서도 보세요"라고 권할 차례인지. 없으면 nil.
    /// 있다고 답했고, 아직 그 기기에서 안 써 봤고, 지난번 권한 뒤로 충분히 지났고, 최대 세 번까지.
    ///
    /// ⚠️ "시작 횟수가 5의 배수일 때"로 만들지 말 것. 시작 횟수를 올리는 것과 이 판정이 같은
    ///    순간에 일어나서 한 칸 어긋나면 그 차례를 통째로 건너뛴다(그러면 안내가 영영 안 뜬다).
    ///    "지난번 이후 몇 번 더 걸었나"로 재면 어긋나도 다음 기회에 뜬다.
    static func dueReminder(watch: ReminderInput,
                            mac: ReminderInput,
                            timerStarts: Int) -> Device? {
        guard timerStarts >= minTimerStarts else { return nil }

        func isDue(_ input: ReminderInput) -> Bool {
            input.answer == .yes
                && !input.hasUsed
                && input.shownCount < reminderMaxCount
                && timerStarts - input.lastShownAtStart >= reminderInterval
        }
        if isDue(watch) { return .watch }
        if isDue(mac) { return .mac }
        return nil
    }

    // MARK: - 저장소

    /// 설정 화면이 `@AppStorage`로 같은 키를 읽는다 — **키 문자열을 바꾸면 두 곳을 함께 고칠 것.**
    static func answerKey(_ device: Device) -> String { "device.owns.\(device.rawValue)" }
    private static func usedKey(_ device: Device) -> String { "device.used.\(device.rawValue)" }
    private static func reminderCountKey(_ device: Device) -> String { "device.reminded.\(device.rawValue)" }
    private static func reminderStartKey(_ device: Device) -> String { "device.remindedAtStart.\(device.rawValue)" }
    private static let lastAskedAtKey = "device.ownership.lastAskedAt"

    /// 저장소 — 테스트에서 격리된 suite 를 꽂기 위해 var 로 둔다(프로덕션에서는 바꾸지 않는다).
    /// ⚠️ 앱 화면은 같은 키를 `@AppStorage`(표준 저장소)로 읽는다 — 여기서 다른 suite 를 쓰면
    ///    설정 화면과 값이 갈라진다. **테스트 전용 주입구다.**
    static var defaults: UserDefaults = .standard

    private static var store: UserDefaults { defaults }

    static func answer(for device: Device) -> Answer {
        Answer(rawValue: store.string(forKey: answerKey(device)) ?? "") ?? .unknown
    }

    /// 사용자의 대답을 저장한다. 어떤 답이든 그 기기는 다시 묻지 않는다.
    static func record(_ answer: Answer, for device: Device, now: Date = Date()) {
        store.set(answer.rawValue, forKey: answerKey(device))
        store.set(now, forKey: lastAskedAtKey)
        guard answer != .unknown else { return }
        AnalyticsManager.log(.deviceOwnershipAnswered(device: device.rawValue, owns: answer == .yes))
    }

    /// 묻지 않아도 "있다"가 확정된 경우 — 워치가 페어링돼 있거나 Mac Catalyst로 실행 중일 때.
    /// **`markUsed`와 다르다**: 가지고 있다는 것만 확정할 뿐 "이 앱을 그 기기에서 써 봤다"는 아니다.
    /// (그래서 워치를 가진 사람에게 워치 앱을 권하는 안내는 계속 나간다 — 그게 요점이다.)
    static func confirmOwned(_ device: Device) {
        guard answer(for: device) != .yes else { return }
        store.set(Answer.yes.rawValue, forKey: answerKey(device))
    }

    /// 그 기기에서 실제로 쓴 흔적 — 소유도 함께 확정된다. 이후로는 권하지 않는다.
    static func markUsed(_ device: Device) {
        store.set(true, forKey: usedKey(device))
        confirmOwned(device)
    }

    static func hasUsed(_ device: Device) -> Bool { store.bool(forKey: usedKey(device)) }

    // MARK: - 저장소 연결 (화면에서 부르는 것)

    /// 지금 물어볼 질문 — 저장된 답과 마지막 질문 시각을 읽어 위 순수 함수에 넘긴다.
    static func pendingQuestion(timerStarts: Int, now: Date = Date()) -> Device? {
        guard !isRunningTests else { return nil }
        return nextQuestion(watch: answer(for: .watch),
                            mac: answer(for: .mac),
                            timerStarts: timerStarts,
                            lastAskedAt: store.object(forKey: lastAskedAtKey) as? Date,
                            now: now)
    }

    /// 지금 권할 기기.
    static func pendingReminder(timerStarts: Int) -> Device? {
        guard !isRunningTests else { return nil }
        func input(_ device: Device) -> ReminderInput {
            ReminderInput(answer: answer(for: device),
                          hasUsed: hasUsed(device),
                          shownCount: store.integer(forKey: reminderCountKey(device)),
                          lastShownAtStart: store.integer(forKey: reminderStartKey(device)))
        }
        return dueReminder(watch: input(.watch), mac: input(.mac), timerStarts: timerStarts)
    }

    static func markReminderShown(_ device: Device, atStart timerStarts: Int) {
        store.set(store.integer(forKey: reminderCountKey(device)) + 1, forKey: reminderCountKey(device))
        store.set(timerStarts, forKey: reminderStartKey(device))
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    #if DEBUG
    /// 테스트·디버그 전용 — 처음 깐 상태로 되돌린다.
    static func resetAll() {
        for device in Device.allCases {
            store.removeObject(forKey: answerKey(device))
            store.removeObject(forKey: usedKey(device))
            store.removeObject(forKey: reminderCountKey(device))
            store.removeObject(forKey: reminderStartKey(device))
        }
        store.removeObject(forKey: lastAskedAtKey)
    }
    #endif
}
