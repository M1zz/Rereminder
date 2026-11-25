//
//  TimerEngine.swift
//  Rereminder
//
//  Created by POS on 8/24/25.
//
//  리팩토링:
//  - endDate 기반 remaining 계산 (Date 비교만으로 정확)
//  - Pre-alert/종료 알림을 UNNotificationRequest로 스케줄 (백그라운드 보장)
//  - UI tick은 포그라운드에서만 500ms 간격 (배터리 절약)
//  - 앱이 돌아올 때 endDate 기반으로 즉시 재계산
//

import Foundation
import UserNotifications
#if !APPCLIP
import WidgetKit
#endif

enum TimerState: Equatable { case idle, running, paused, finished, overtime }

final class TimerEngine {

    struct Configuration: Equatable {
        /// 한 회의 길이. 반복이 없으면 곧 전체 길이다.
        var mainDuration: TimeInterval
        var prealertOffsetsSec: [TimeInterval]
        var name: String = ""
        /// 몇 번 돌리나(`RoundSchedule`). 1 이면 반복 없음.
        var rounds: Int = 1

        /// 처음부터 끝까지
        var totalDuration: TimeInterval { RoundSchedule.total(roundSeconds: mainDuration, rounds: rounds) }
    }

    // MARK: - Callbacks (UI 업데이트용)
    var onTick: ((TimeInterval) -> Void)?
    var onPreAlert: ((Int) -> Void)?   // 포그라운드일 때 인앱 토스트용
    var onFinish: (() -> Void)?
    /// 반복 중 다음 회로 넘어갔다(새 회 번호, 0부터). 마지막 회가 끝나면 이게 아니라 `onFinish` 다.
    var onRoundChange: ((Int) -> Void)?

    /// 지금 몇 번째 회인가(0부터)
    private(set) var currentRound = 0

    /// Test Mode용 Time Multiplier (기본값 1.0 = 실시간)
    var timeMultiplier: Double = 1.0

    // MARK: - State
    private(set) var config: Configuration?
    private(set) var endDate: Date?
    private static let sharedSuiteName = "group.leeo.toki"

    private(set) var state: TimerState = .idle {
        didSet {
            // App Clip은 App Group·위젯·워치가 없으므로 상태 공유를 건너뛴다.
            #if APPCLIP
            return
            #else
            let shared = UserDefaults(suiteName: Self.sharedSuiteName)
            let isRunning = (state == .running || state == .overtime)
            shared?.set(isRunning, forKey: "timerIsRunning")
            shared?.set(endDate?.timeIntervalSince1970 ?? 0, forKey: "timerEndDate")
            // 위젯은 처음부터 끝까지를 그린다 — 반복이면 전체 길이, 회 길이는 따로 둔다.
            shared?.set(config?.totalDuration ?? 0, forKey: "timerMainDuration")
            shared?.set(config?.mainDuration ?? 0, forKey: "timerRoundDuration")
            shared?.set(config?.rounds ?? 1, forKey: "timerRounds")
            shared?.set(state == .paused, forKey: "timerIsPaused")
            shared?.set(startDate?.timeIntervalSince1970 ?? 0, forKey: "timerStartDate")
            // 반복이면 위젯의 전체 링에 회 안의 알림 자리가 맞지 않는다 — 싣지 않는다.
            let offsets = (config?.rounds ?? 1) > 1 ? [] : (config?.prealertOffsetsSec.map { Int($0) } ?? [])
            shared?.set(offsets, forKey: "timerPrealertOffsets")
            shared?.set(config?.name ?? "", forKey: "timerName")
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    private var startDate: Date?
    private var pausedElapsed: TimeInterval = 0
    private var remainingWhenPaused: TimeInterval?
    private var firedOffsets = Set<Int>()

    // MARK: - Timer (UI tick 전용)
    // ⚠️ 틱은 **메인 큐**에서 돈다. 예전에는 따로 만든 직렬 큐에서 돌며 `firedOffsets`(Set)·`config`·`state` 를
    //    고쳤는데, 같은 값을 메인 스레드의 `stop()`·`start()`·`applyRemoteRunning()` 도 고친다.
    //    `stopUITick()` 은 이미 돌고 있는 틱을 기다리지 않으므로, 정지·다른 기기에서 받은 타이머와 틱이 겹치는 순간
    //    한 Set·배열을 두 스레드가 동시에 고쳐 앱이 죽을 수 있었다. 틱이 하는 일은 가벼워 메인에서 돌아도 된다.
    private var timer: DispatchSourceTimer?

    // MARK: - Notification IDs
    private static let notificationPrefix = "rereminder.timer."

    #if !APPCLIP
    /// 되풀이 알림 사슬에서 이 기기가 몇 번째인가.
    ///
    /// 직접 시작한 타이머면 `.primary`(종료 순간 바로 울린다), 워치가 돌리는 것을 받아 온
    /// 것이면 `.secondary`(손목이 먼저 울리고, 확인이 없을 때만 30초 뒤 합류한다).
    /// ⚠️ 둘 다 primary 로 두면 폰과 워치가 **동시에** 울려 "번지는" 뜻이 사라진다.
    private(set) var escalationRole: EscalationRole = .primary
    #endif

    // MARK: - Public API

    func configure(mainSeconds: Int, prealertOffsetsSec: [Int], name: String = "", rounds: Int = 1) {
        let dur = TimeInterval(max(1, mainSeconds))
        let offsets = prealertOffsetsSec
            .filter { $0 > 0 && $0 < Int(dur) }
            .sorted(by: >)
            .map(TimeInterval.init)
        config = .init(mainDuration: dur, prealertOffsetsSec: offsets, name: name, rounds: max(1, rounds))
        currentRound = 0
        state = .idle
    }

    /// 처음부터 끝까지 남은 시간. 잠금화면·다른 기기는 회가 아니라 이것을 센다 —
    /// 앱이 멈춰 있으면 회가 바뀔 때 표시를 고칠 수 없지만 전체 카운트다운은 끝까지 맞다.
    var totalRemaining: TimeInterval {
        guard let cfg = config else { return 0 }
        if state == .paused { return remainingWhenPaused ?? 0 }
        guard let e = elapsedNow() else { return cfg.totalDuration }
        return cfg.totalDuration - e
    }

    /// 처음부터 잰 경과(테스트 배속 포함). 도는 중에만 뜻이 있다.
    private func elapsedNow() -> TimeInterval? {
        guard let start = startDate else { return nil }
        return Date().timeIntervalSince(start) * timeMultiplier + pausedElapsed
    }

    /// 회 안의 알림 하나를 기억하는 열쇠 — 같은 1분 전이라도 회마다 따로다.
    private static func firedKey(round: Int, offset: Int) -> Int { round * 1_000_000 + offset }

    /// 경과 e 에서 이미 지나간 알림을 표시해 둔다(돌아왔을 때 몰아서 울리지 않게).
    private func markPassedAlerts(elapsed e: TimeInterval, config cfg: Configuration) {
        let round = RoundSchedule.roundIndex(elapsed: e, roundSeconds: cfg.mainDuration, rounds: cfg.rounds)
        let remain = RoundSchedule.roundRemaining(elapsed: e, roundSeconds: cfg.mainDuration, rounds: cfg.rounds)
        currentRound = round
        for off in cfg.prealertOffsetsSec where remain <= off {
            firedOffsets.insert(Self.firedKey(round: round, offset: Int(off)))
        }
    }

    func start() {
        guard let cfg = config else { return }
        firedOffsets.removeAll()
        pausedElapsed = 0
        currentRound = 0
        startDate = Date()
        endDate = Date().addingTimeInterval(cfg.totalDuration / timeMultiplier)
        state = .running

        onTick?(cfg.mainDuration)

        #if !APPCLIP
        escalationRole = .primary
        #endif

        // 백그라운드 알림 스케줄
        scheduleNotifications(elapsed: 0)

        // UI tick 시작
        startUITick()

        // 분석은 ProGate(인앱결제)에 의존하므로 App Clip 빌드에서는 제외한다.
        #if !APPCLIP
        AnalyticsManager.log(.timerStarted(
            durationSeconds: Int(cfg.mainDuration),
            alertCount: cfg.prealertOffsetsSec.count,
            presetName: cfg.name.isEmpty ? nil : cfg.name
        ))
        #endif
    }

    func pause() {
        guard state == .running || state == .overtime,
              let start = startDate,
              let cfg = config else { return }

        let actualElapsed = Date().timeIntervalSince(start)
        pausedElapsed += actualElapsed * timeMultiplier
        remainingWhenPaused = cfg.totalDuration - pausedElapsed

        stopUITick()
        cancelScheduledNotifications()
        state = .paused
    }

    func resume() {
        guard state == .paused,
              let r = remainingWhenPaused,
              let cfg = config else { return }

        startDate = Date()
        endDate = Date().addingTimeInterval(r / timeMultiplier)

        // 아직 발생하지 않은 알림만 다시 스케줄 (지금 경과 뒤의 것)
        scheduleNotifications(elapsed: cfg.totalDuration - r)

        startUITick()
        state = r > 0 ? .running : .overtime
    }

    func stop() {
        let wasActive = (state == .running || state == .paused)
        let remainingForCancel: Int = {
            guard wasActive, let cfg = config, let start = startDate else { return 0 }
            let elapsed = Date().timeIntervalSince(start) * timeMultiplier + pausedElapsed
            return max(0, Int(cfg.totalDuration - elapsed))
        }()

        stopUITick()
        cancelScheduledNotifications()
        endDate = nil
        startDate = nil
        pausedElapsed = 0
        remainingWhenPaused = nil
        firedOffsets.removeAll()
        currentRound = 0
        state = .idle

        if wasActive {
            #if !APPCLIP
            // 정지는 "확인했다"이기도 하다 — 워치에서 뒤늦게 합류할 알림까지 함께 멈춘다.
            EscalatingAlert.acknowledgeEverywhere()
            AnalyticsManager.log(.timerCancelled(remainingSeconds: remainingForCancel))
            #endif
        }
    }

    /// Cold launch 시 App Group에서 타이머 상태 복원
    /// 복원 성공 시 true 반환, 복원할 상태가 없으면 false
    @discardableResult
    func restoreFromSharedState() -> Bool {
        let shared = UserDefaults(suiteName: Self.sharedSuiteName)
        let isRunning = shared?.bool(forKey: "timerIsRunning") ?? false
        let isPaused = shared?.bool(forKey: "timerIsPaused") ?? false

        guard isRunning || isPaused else { return false }

        // 반복이면 회 길이를 따로 남겨 두었다. 없으면 예전 그대로 한 번짜리다.
        let storedRounds = max(1, shared?.integer(forKey: "timerRounds") ?? 1)
        let storedRound = shared?.double(forKey: "timerRoundDuration") ?? 0
        let mainDuration = storedRound > 0 ? storedRound : (shared?.double(forKey: "timerMainDuration") ?? 0)
        let rounds = storedRound > 0 ? storedRounds : 1
        guard mainDuration > 0 else { return false }

        let endEpoch = shared?.double(forKey: "timerEndDate") ?? 0
        let startEpoch = shared?.double(forKey: "timerStartDate") ?? 0
        let offsets = (shared?.array(forKey: "timerPrealertOffsets") as? [Int]) ?? []

        guard endEpoch > 0, startEpoch > 0 else { return false }

        // 설정 복원
        let dur = mainDuration
        let offsetTIs = offsets
            .filter { $0 > 0 && $0 < Int(dur) }
            .sorted(by: >)
            .map(TimeInterval.init)
        // 위젯 몫으로 반복일 때는 알림을 비워 두었다 — 회 안의 알림은 되살리지 못하고, 회 끝 알림만 남는다.
        config = .init(mainDuration: dur, prealertOffsetsSec: offsetTIs, rounds: rounds)
        let total = RoundSchedule.total(roundSeconds: dur, rounds: rounds)

        let restoredEndDate = Date(timeIntervalSince1970: endEpoch)
        let restoredStartDate = Date(timeIntervalSince1970: startEpoch)

        if isPaused {
            // 일시정지 상태 복원: endDate는 "재개 시 남은 시간"을 담고 있음
            let remaining = restoredEndDate.timeIntervalSinceNow
            startDate = nil
            endDate = restoredEndDate
            pausedElapsed = total - max(0, remaining)
            remainingWhenPaused = max(0, remaining)
            currentRound = RoundSchedule.roundIndex(elapsed: pausedElapsed, roundSeconds: dur, rounds: rounds)
            state = .paused
            onTick?(max(0, RoundSchedule.roundRemaining(elapsed: pausedElapsed, roundSeconds: dur, rounds: rounds)))
            return true
        }

        // 실행 중 복원 — 끝나는 시각에서 거꾸로 잰다. 저장된 시작 시각은 일시정지가 있었으면 재개한 때라 맞지 않는다.
        _ = restoredStartDate
        startDate = restoredEndDate.addingTimeInterval(-total)
        endDate = restoredEndDate
        pausedElapsed = 0
        firedOffsets.removeAll()

        let remaining = restoredEndDate.timeIntervalSinceNow
        let elapsed = total - remaining

        // 이미 지나간 pre-alert 마킹
        markPassedAlerts(elapsed: elapsed, config: config!)
        let roundRemain = RoundSchedule.roundRemaining(elapsed: elapsed, roundSeconds: dur, rounds: rounds)

        if remaining <= 0 {
            state = .overtime
            onTick?(remaining)
            DispatchQueue.main.async { self.onFinish?() }
        } else {
            state = .running
            onTick?(roundRemain)
            startUITick()
            // 앱이 멈춰 있는 동안 울린 만큼 회 알림을 다시 채운다
            topUpRoundNotifications(elapsed: elapsed)
        }

        return true
    }

    #if !APPCLIP
    /// 엔진(화면)이 아직 없을 때 들어온 **정지**를 처리한다 — 잠금화면의 정지 버튼이 꺼져 있던 앱을 뒤에서 깨운 경우.
    /// 걸어 둔 알림·되풀이·AlarmKit 알람을 걷고, 저장된 실행 상태를 내려 다음에 열 때 되살리지 않게 한다.
    /// ⚠️ 상태를 남겨 두면 명령이 버려진 뒤(10분) 앱을 열었을 때 알림이 모두 걷힌 "도는" 타이머가 되살아났다.
    @MainActor
    static func stopWithoutScreen() {
        EscalatingAlert.acknowledgeEverywhere()
        RereminderAlarmManager.shared.cancelFinishAlarm()
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(Self.notificationPrefix) }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
        let shared = UserDefaults(suiteName: Self.sharedSuiteName)
        shared?.set(false, forKey: "timerIsRunning")
        shared?.set(false, forKey: "timerIsPaused")
        WidgetCenter.shared.reloadAllTimelines()
    }
    #endif

    // MARK: - Remote Sync 적용 (다른 기기에서 제어된 타이머 반영)

    /// 다른 기기에서 시작/재개된 타이머를 endDate 절대 시각 기준으로 반영
    /// 동기화 지연과 무관하게 남은 시간이 원본 기기와 일치한다
    func applyRemoteRunning(mainSeconds: Int, prealertOffsetsSec: [Int], name: String, endDate remoteEndDate: Date) {
        stopUITick()
        cancelScheduledNotifications()
        timeMultiplier = 1.0

        let dur = TimeInterval(max(1, mainSeconds))
        let offsets = prealertOffsetsSec
            .filter { $0 > 0 && $0 < Int(dur) }
            .sorted(by: >)
            .map(TimeInterval.init)
        config = .init(mainDuration: dur, prealertOffsetsSec: offsets, name: name)

        pausedElapsed = 0
        remainingWhenPaused = nil
        firedOffsets.removeAll()
        startDate = remoteEndDate.addingTimeInterval(-dur)
        endDate = remoteEndDate

        let remaining = remoteEndDate.timeIntervalSinceNow

        // 이미 지나간 pre-alert 마킹
        currentRound = 0
        for off in offsets where remaining <= off {
            firedOffsets.insert(Self.firedKey(round: 0, offset: Int(off)))
        }

        if remaining <= 0 {
            state = .overtime
            onTick?(remaining)
            DispatchQueue.main.async { self.onFinish?() }
            return
        }

        #if !APPCLIP
        // 워치가 돌리는 타이머다 — 손목이 먼저 울리고 이 기기는 확인이 없을 때만 합류한다.
        escalationRole = .secondary
        #endif

        // 이 기기에서도 알림이 울리도록 남은 시점 기준으로 스케줄
        scheduleNotifications(elapsed: dur - remaining)

        state = .running
        onTick?(remaining)
        startUITick()
    }

    /// 다른 기기에서 일시정지된 타이머를 반영 (남은 시간을 그대로 넘겨받아 오차 없음)
    func applyRemotePause(mainSeconds: Int, prealertOffsetsSec: [Int], name: String, remaining: TimeInterval) {
        stopUITick()
        cancelScheduledNotifications()
        timeMultiplier = 1.0

        let dur = TimeInterval(max(1, mainSeconds))
        let offsets = prealertOffsetsSec
            .filter { $0 > 0 && $0 < Int(dur) }
            .sorted(by: >)
            .map(TimeInterval.init)
        config = .init(mainDuration: dur, prealertOffsetsSec: offsets, name: name)

        let r = max(0, remaining)
        startDate = nil
        pausedElapsed = dur - r
        remainingWhenPaused = r
        firedOffsets.removeAll()
        currentRound = 0
        for off in offsets where r <= off {
            firedOffsets.insert(Self.firedKey(round: 0, offset: Int(off)))
        }
        // 복원 규칙과 동일: paused 상태의 endDate는 "지금 기준 남은 시간"을 담는다
        endDate = Date().addingTimeInterval(r)
        state = .paused
        onTick?(r)
    }

    /// 앱이 포그라운드로 돌아왔을 때 호출 — endDate 기반 재계산
    func recalculateOnForeground() {
        guard state == .running || state == .overtime,
              let e = elapsedNow(),
              let cfg = config else { return }

        let remainTotal = cfg.totalDuration - e
        let previousRound = currentRound

        // 포그라운드에 없는 동안 지나간 pre-alert·회 처리 (몰아서 울리지 않는다)
        markPassedAlerts(elapsed: e, config: cfg)
        let remain = remainTotal <= 0
            ? remainTotal
            : RoundSchedule.roundRemaining(elapsed: e, roundSeconds: cfg.mainDuration, rounds: cfg.rounds)
        if currentRound != previousRound, remainTotal > 0 {
            let round = currentRound
            DispatchQueue.main.async { self.onRoundChange?(round) }
        }

        if remainTotal <= 0 && state == .running {
            state = .overtime
            DispatchQueue.main.async { self.onFinish?() }
        } else if remainTotal > 0 {
            // 멈춰 있는 동안 울린 만큼 다시 채운다
            topUpRoundNotifications(elapsed: e)
        }

        DispatchQueue.main.async { self.onTick?(remain) }
    }

    // MARK: - UI Tick (포그라운드 전용, 500ms)

    private func startUITick() {
        stopUITick()

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(
            deadline: .now(),
            repeating: .milliseconds(500),   // 100ms → 500ms (배터리 절약)
            leeway: .milliseconds(100)
        )
        t.setEventHandler { [weak self] in
            guard let self,
                  let e = self.elapsedNow(),
                  let cfg = self.config else { return }

            let remainTotal = cfg.totalDuration - e
            let round = RoundSchedule.roundIndex(elapsed: e, roundSeconds: cfg.mainDuration, rounds: cfg.rounds)
            // 화면은 이 회 안에서 남은 시간을 본다. 마지막 회가 끝나면 음수로 이어진다(오버타임).
            let remain = remainTotal <= 0
                ? remainTotal
                : RoundSchedule.roundRemaining(elapsed: e, roundSeconds: cfg.mainDuration, rounds: cfg.rounds)

            // 다음 회로 넘어갔다 — 알리고, 울린 만큼 예약을 다시 채운다
            if round > self.currentRound, remainTotal > 0 {
                self.currentRound = round
                DispatchQueue.main.async { self.onRoundChange?(round) }
                self.topUpRoundNotifications(elapsed: e)
            }

            // 포그라운드 인앱 pre-alert (토스트 + 사운드)
            for off in cfg.prealertOffsetsSec {
                let offInt = Int(off)
                let key = Self.firedKey(round: self.currentRound, offset: offInt)
                if !self.firedOffsets.contains(key), remain <= off, remain > 0 {
                    self.firedOffsets.insert(key)
                    DispatchQueue.main.async { self.onPreAlert?(offInt) }
                }
            }

            if remainTotal <= 0 && self.state == .running {
                self.state = .overtime
                DispatchQueue.main.async { self.onFinish?() }
                #if !APPCLIP
                AnalyticsManager.log(.timerCompleted(
                    durationSeconds: Int(cfg.totalDuration),
                    // 걸어 둔 개수가 아니라 **실제로 울린 개수**다 — 중간에 알림을 지나치지 않고
                    // 끝까지 간 실행만이 "이 앱이 도움이 됐다"의 증거다.
                    firedAlertCount: self.firedOffsets.count
                ))
                #endif
            }

            DispatchQueue.main.async { self.onTick?(remain) }
        }
        t.resume()
        timer = t
    }

    private func stopUITick() {
        guard let t = timer else { return }
        t.setEventHandler {}
        t.cancel()
        timer = nil
    }

    // MARK: - UNNotificationRequest 스케줄 (백그라운드 보장)

    /// 경과 `elapsed` 뒤에 울릴 것을 전부 예약한다 — 회 안의 알림은 가까운 것부터 예약 몫만큼, 종료는 언제나.
    private func scheduleNotifications(elapsed: TimeInterval) {
        #if DEBUG
        // 스크린샷 장면(`ScreenshotScene`)은 맥에서 진짜 앱과 같은 자리로 돈다 — 그 타이머를 남에게 알리지 않는다.
        if UserDefaults.standard.string(forKey: "screenshotScene") != nil { return }
        #endif
        guard let cfg = config else { return }
        let center = UNUserNotificationCenter.current()
        let duration = cfg.totalDuration - elapsed

        topUpRoundNotifications(elapsed: elapsed)

        // 종료 알림
        let finishFireAfter = duration / timeMultiplier
        if finishFireAfter > 0 {
            let content = UNMutableNotificationContent()
            content.title = AppName.notification
            content.body = String(localized: "Timer finished")
            content.sound = RingMode.notificationSound
            #if !APPCLIP
            // ⚠️ **첫 종료 알림에도 카테고리를 붙여야** 정지·다시 알림 버튼이 달린다.
            //    되풀이 알림에만 붙어 있어서, 첫 알림을 길게 눌러 끄려던 사람은 버튼을 못 찾고
            //    다음 되풀이까지 기다려야 했다.
            content.categoryIdentifier = EscalatingAlert.categoryIdentifier
            content.interruptionLevel = .timeSensitive
            #endif

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: finishFireAfter,
                repeats: false
            )
            let id = "\(Self.notificationPrefix)finish"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)

            #if !APPCLIP
            // 확인할 때까지 다시 부른다. 켠 사람에게만 간다(기본값은 꺼짐).
            EscalatingAlert.schedule(policy: EscalationPolicy.current(),
                                     role: escalationRole,
                                     finishFireAfter: finishFireAfter)

            // **끌 때까지 크게 울리는 알람**으로 갈아탈 수 있으면 갈아탄다.
            // ⚠️ 순서가 중요하다 — 위 UN 알림을 **먼저 깔아 두고**, AlarmKit 예약이 성공한
            //    뒤에야 그것을 걷는다. 반대로 하면 권한이 없거나 예약이 실패했을 때
            //    **종료 시각에 아무 데서도 울리지 않는다.**
            adoptAlarmKitFinishIfPossible(fireAfter: finishFireAfter)
            #endif
        }
    }

    /// 회 안의 알림(예비 알림·회 끝)을 가까운 것부터 예약 몫만큼 깐다. 같은 일은 같은 이름이라 다시 깔아도 겹치지 않는다.
    /// 반복이 없으면 예비 알림 몇 개가 전부라 몫 안에 다 들어간다.
    private func topUpRoundNotifications(elapsed e: TimeInterval) {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "screenshotScene") != nil { return }
        #endif
        guard let cfg = config else { return }
        let events = RoundSchedule.upcoming(roundSeconds: cfg.mainDuration, rounds: cfg.rounds,
                                            offsets: cfg.prealertOffsetsSec, after: e,
                                            limit: RoundSchedule.budget(escalationCount: Self.escalationCount))
        let center = UNUserNotificationCenter.current()
        for event in events {
            let content = UNMutableNotificationContent()
            content.title = AppName.notification
            switch event.kind {
            case .prealert(let offInt):
                content.body = offInt < 60
                    ? String(localized: "\(offInt) sec remaining")
                    : String(localized: "\(offInt / 60) min remaining")
            case .roundEnd:
                content.body = String(localized: "Round \(event.round + 1) of \(cfg.rounds) done")
            }
            content.sound = RingMode.notificationSound
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(0.5, (event.at - e) / timeMultiplier),  // test mode 보정
                repeats: false
            )
            let id = "\(Self.notificationPrefix)\(event.identifierSuffix)"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    /// 되풀이 알림이 쓰는 예약 몫
    private static var escalationCount: Int {
        #if APPCLIP
        return 0
        #else
        return EscalationSchedule.offsets(policy: EscalationPolicy.current(), role: .primary).count
        #endif
    }

    #if !APPCLIP
    /// 종료 알림을 AlarmKit 알람으로 승격시킨다(성공했을 때만).
    ///
    /// ⚠️ **이 기기가 타이머를 직접 돌릴 때만**(`.primary`) 갈아탄다. 워치가 돌리는 타이머를
    ///    받아 온 경우(`.secondary`)는 "손목이 먼저, 30초 뒤 폰이 합류"라는 사슬이 있는데,
    ///    AlarmKit 은 종료 순간에 곧바로 울려서 그 순서를 깨뜨린다.
    private func adoptAlarmKitFinishIfPossible(fireAfter: TimeInterval) {
        guard escalationRole == .primary else { return }
        guard RereminderAlarmManager.isPreferred else { return }

        let fireDate = Date().addingTimeInterval(fireAfter)
        let name = config?.name
        let finishID = "\(Self.notificationPrefix)finish"

        Task { @MainActor in
            guard await RereminderAlarmManager.shared.scheduleFinishAlarm(at: fireDate,
                                                                          timerName: name) else { return }
            // 알람이 이 몫을 대신하므로 같은 순간에 두 번 울리지 않게 걷는다.
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [finishID])
            EscalatingAlert.cancel()
        }
    }
    #endif

    private func cancelScheduledNotifications() {
        #if !APPCLIP
        // ⚠️ 되풀이 알림은 접두어가 달라 아래 필터에 걸리지 않는다 — 따로 걷지 않으면
        //    타이머를 정지해도 종료 시각에 알림이 계속 울린다.
        EscalatingAlert.cancel()
        // ⚠️ AlarmKit 알람도 같은 이유로 따로 걷는다. 이건 알림 센터가 아니라 시스템 알람이라
        //    `removePendingNotificationRequests` 로는 **절대 지워지지 않는다** — 빼먹으면
        //    타이머를 정지해도 종료 시각에 전체 화면 알람이 울린다.
        Task { @MainActor in RereminderAlarmManager.shared.cancelFinishAlarm() }
        #endif

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.notificationPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }
}
