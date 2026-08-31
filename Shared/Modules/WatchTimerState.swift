//
//  WatchTimerState.swift
//  Rereminder
//
//  워치 앱과 워치 스마트 스택 위젯이 **함께 보는** 타이머 상태 한 벌.
//
//  위젯은 앱과 다른 프로세스라 `UserDefaults.standard` 로는 서로의 값을 볼 수 없다
//  (각자 제 컨테이너를 본다). 그래서 앱 그룹에 한 벌 적어 두고 양쪽이 그것만 읽는다.
//
//  ⚠️ **남은 시간을 저장하지 않는다.** 시작 시각만 적고 읽는 쪽에서 뺀다.
//     초마다 저장하면 위젯이 갱신되는 시점과 어긋나 숫자가 튀고, 배터리도 그만큼 쓴다.
//     그래서 앱이 꺼져 있어도 위젯의 카운트다운은 정확하다.
//
//  ⚠️ 여기 있는 파생값(`remainingSeconds`·`section`)이 앱과 위젯의 **유일한** 계산이다.
//     한쪽에서 따로 세면 손목의 숫자와 스마트 스택의 숫자가 갈라진다.
//

import Foundation
#if os(watchOS)
import WidgetKit
#endif

/// 워치에서 돌고 있는 타이머 한 벌 — 앱이 적고, 스마트 스택 위젯이 읽는다.
struct WatchTimerState: Equatable, Sendable {

    /// 타이머 전체 길이(초).
    var mainDuration: Int
    /// **종료까지 남은 시간** 기준 예비 알림 지점(초). 예: 5분 전 = 300.
    var prealertOffsets: [Int]
    /// 시작 시각.
    var startDate: Date
    var isPaused: Bool
    /// 지금까지 멈춰 있던 시간의 합(초).
    var accumulatedPause: TimeInterval
    /// 지금 멈춰 있다면 멈춘 시각. 멈춰 있지 않으면 nil.
    var pauseDate: Date?

    init(mainDuration: Int,
         prealertOffsets: [Int],
         startDate: Date,
         isPaused: Bool = false,
         accumulatedPause: TimeInterval = 0,
         pauseDate: Date? = nil) {
        self.mainDuration = mainDuration
        self.prealertOffsets = prealertOffsets
        self.startDate = startDate
        self.isPaused = isPaused
        self.accumulatedPause = accumulatedPause
        self.pauseDate = pauseDate
    }

    // MARK: - 파생값

    /// 시작 후 경과 초. 멈춰 있으면 **멈춘 순간에 고정**된다.
    func elapsedSeconds(at now: Date = Date()) -> Int {
        // 멈춰 있는데 멈춘 시각을 모르면(있을 수 없지만) 지금으로 본다 — 복원이 통째로 깨지는 것보다 낫다.
        let reference = isPaused ? (pauseDate ?? now) : now
        return Int(reference.timeIntervalSince(startDate) - accumulatedPause)
    }

    /// 남은 초. 다 지났으면 0 이하가 된다.
    func remainingSeconds(at now: Date = Date()) -> Int {
        mainDuration - elapsedSeconds(at: now)
    }

    /// 아직 끝나지 않았나 — 위젯이 "돌고 있음"과 "끝남"을 가르는 기준.
    func isActive(at now: Date = Date()) -> Bool {
        remainingSeconds(at: now) > 0
    }

    /// 시스템이 알아서 세어 주는 카운트다운(`Text(timerInterval:)`)이 볼 종료 시각.
    ///
    /// ⚠️ 멈춰 있으면 nil 이다 — 멈춘 채로 흘러가는 카운트다운은 거짓말이다.
    ///    (일시정지 화면은 고정된 숫자를 그려야 한다.)
    var endDate: Date? {
        guard !isPaused else { return nil }
        return startDate.addingTimeInterval(accumulatedPause + TimeInterval(mainDuration))
    }

    /// 아직 울리지 않은 예비 알림 중 **가장 먼저** 울릴 것이 울리는 시각.
    ///
    /// 알림은 "종료 O초 전"이므로 남은 시간이 O 로 줄어드는 순간 울린다. 곧 울릴 것은
    /// 남은 시간보다 작은 offset 중 **가장 큰** 것이다.
    func nextAlertDate(at now: Date = Date()) -> Date? {
        let remaining = remainingSeconds(at: now)
        guard remaining > 0,
              let offset = prealertOffsets.filter({ $0 > 0 && $0 < remaining }).max()
        else { return nil }
        return now.addingTimeInterval(TimeInterval(remaining - offset))
    }

    /// 지금 지나는 중인 구간 — iPhone·워치 화면과 **같은 함수**(`TimerSections`)를 쓴다.
    func section(at now: Date = Date()) -> TimerSections.Progress? {
        TimerSections.progress(mainSeconds: mainDuration,
                               alertOffsets: Set(prealertOffsets),
                               elapsedSec: elapsedSeconds(at: now))
    }

    /// 위젯 타임라인이 새 항목을 세워야 하는 시각들 — **알림 경계와 종료**.
    ///
    /// 카운트다운 자체는 시스템이 세므로 새 항목이 필요한 건 표시가 바뀌는 순간뿐이다
    /// ("다음 알림"이 다음 것으로 넘어갈 때, 그리고 끝날 때).
    func refreshDates(after now: Date = Date()) -> [Date] {
        guard !isPaused, let end = endDate else { return [] }
        let boundaries = prealertOffsets
            .filter { $0 > 0 && $0 < mainDuration }
            .map { end.addingTimeInterval(-TimeInterval($0)) }
        return (boundaries + [end])
            .filter { $0 > now }
            .sorted()
    }
}

// MARK: - 저장소

/// 워치 타이머 상태가 사는 곳. 앱이 적고 위젯이 읽는다.
enum WatchTimerStore {

    /// iOS 앱·위젯이 쓰는 것과 같은 그룹 이름. 워치에서는 **워치 앱 ↔ 워치 위젯** 사이의
    /// 통로다(아이폰과 이어지는 통로가 아니다 — 앱 그룹 컨테이너는 기기마다 따로다).
    static let appGroup = "group.leeo.toki"

    private enum Key {
        static let active = "watchTimer.active"
        static let mainDuration = "watchTimer.mainDuration"
        static let prealertOffsets = "watchTimer.prealertOffsets"
        static let startDate = "watchTimer.startDate"
        static let isPaused = "watchTimer.isPaused"
        static let accumulatedPause = "watchTimer.accumulatedPause"
        static let pauseDate = "watchTimer.pauseDate"
    }

    /// 앱 그룹 저장소. 엔타이틀먼트가 빠지면 앱 전용 저장소로 물러선다 —
    /// 그러면 위젯은 못 읽지만 앱의 복원은 멀쩡히 돈다(둘 다 깨지는 것보다 낫다).
    ///
    /// ⚠️ 테스트에서 갈아 끼운다(`FoundingSupporter.defaults` 와 같은 방식) — 시뮬레이터의
    ///    앱 그룹에 남은 값을 그대로 쓰면 저장한 적 없는 타이머가 다음 테스트로 샌다.
    static var shared: UserDefaults = UserDefaults(suiteName: appGroup) ?? .standard

    /// 앱 그룹을 쓰기 전(2.2.2 이하) 워치 앱이 남긴 값. **읽을 때만** 본다.
    static var legacy: UserDefaults = .standard

    // MARK: 돌고 있는 타이머

    /// 지금 돌고 있는(또는 멈춰 있는) 타이머. 없으면 nil.
    ///
    /// 앱 그룹에 아무것도 없으면 옛 저장소를 한 번 더 본다 — **타이머가 도는 중에 업데이트한
    /// 사용자**의 복원이 끊기지 않게. (`clear()` 가 양쪽을 다 지우므로 지난 값이 되살아나지는 않는다.)
    static func load() -> WatchTimerState? {
        read(from: shared) ?? read(from: legacy)
    }

    private static func read(from store: UserDefaults) -> WatchTimerState? {
        guard store.bool(forKey: Key.active) else { return nil }
        let duration = store.integer(forKey: Key.mainDuration)
        let startEpoch = store.double(forKey: Key.startDate)
        guard duration > 0, startEpoch > 0 else { return nil }

        let pauseEpoch = store.double(forKey: Key.pauseDate)
        return WatchTimerState(
            mainDuration: duration,
            prealertOffsets: store.array(forKey: Key.prealertOffsets) as? [Int] ?? [],
            startDate: Date(timeIntervalSince1970: startEpoch),
            isPaused: store.bool(forKey: Key.isPaused),
            accumulatedPause: store.double(forKey: Key.accumulatedPause),
            pauseDate: pauseEpoch > 0 ? Date(timeIntervalSince1970: pauseEpoch) : nil
        )
    }

    static func save(_ state: WatchTimerState) {
        write(state, to: shared)
        reloadWidgets()
    }

    private static func write(_ state: WatchTimerState, to store: UserDefaults) {
        store.set(true, forKey: Key.active)
        store.set(state.mainDuration, forKey: Key.mainDuration)
        store.set(state.prealertOffsets, forKey: Key.prealertOffsets)
        store.set(state.startDate.timeIntervalSince1970, forKey: Key.startDate)
        store.set(state.isPaused, forKey: Key.isPaused)
        store.set(state.accumulatedPause, forKey: Key.accumulatedPause)
        store.set(state.pauseDate?.timeIntervalSince1970 ?? 0, forKey: Key.pauseDate)
    }

    /// ⚠️ **양쪽을 다 지운다.** 옛 저장소를 남겨 두면 `load()` 의 되돌아보기가 이미 끝난
    ///    타이머를 되살려 낸다(위젯에 유령 타이머가 선다).
    static func clear() {
        for store in [shared, legacy] {
            for key in [Key.active, Key.mainDuration, Key.prealertOffsets,
                        Key.startDate, Key.isPaused, Key.accumulatedPause, Key.pauseDate] {
                store.removeObject(forKey: key)
            }
        }
        reloadWidgets()
    }

    // MARK: 위젯 갱신

    /// 상태를 적었으면 스마트 스택도 따라와야 한다 — 저장과 갱신을 떼어 놓으면
    /// "앱에서는 멈췄는데 위젯은 계속 도는" 상태가 남는다.
    static func reloadWidgets() {
        #if os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
