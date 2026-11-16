//
//  TimerViewModel.swift
//  Rereminder
//
//  Created by 내꺼다 on 8/8/25.
//

import Foundation

class TimerViewModel: ObservableObject, Identifiable {
    let id = UUID()
    @Published var timeRemaining: Int
    @Published var isPaused: Bool = false

    private var timer: Timer?
    private let notificationService: NotificationService
    let mainDuration: Int
    let notificationTime: Int
    let prealertOffsets: [Int]  // 여러 개의 Pre-alerts
    /// 반복 횟수(`RoundSchedule`). `mainDuration` 은 한 회의 길이이고 `timeRemaining` 은 그 회에 남은 시간이다.
    let rounds: Int
    /// 지금 몇 번째 회인가(0부터)
    @Published private(set) var currentRound = 0
    private var totalDuration: Int { mainDuration * rounds }

    private var startDate: Date?        // Start Timer 시각
    private var pauseDate: Date?        // Pause한 시각
    private var accumulatedPause: TimeInterval = 0 // 총 정지 시간

    // 단일 알림용 sec기화
    init(mainDuration: Int, notificationDuration: Int, notificationService: NotificationService = .init()) {
        self.mainDuration = mainDuration
        self.timeRemaining = mainDuration
        self.notificationTime = notificationDuration
        self.prealertOffsets = []
        self.rounds = 1
        self.notificationService = notificationService
    }

    // 다중 알림용 sec기화
    init(mainDuration: Int, prealertOffsets: [Int], rounds: Int = 1,
         notificationService: NotificationService = .init()) {
        self.mainDuration = mainDuration
        self.timeRemaining = mainDuration
        self.notificationTime = 0
        self.prealertOffsets = prealertOffsets
        self.rounds = max(1, rounds)
        self.notificationService = notificationService
    }

    // MARK: - Public Methods

    /// 타이머를 건다.
    ///
    /// ⚠️ **이미 걸려 있으면 아무것도 하지 않는다.** 이걸 부르는 곳은 `TimerView.onAppear` 하나인데,
    ///    그 화면에는 새로 만든 타이머뿐 아니라 **cold launch 로 복원한 타이머**도 실린다
    ///    (`SettingView` 의 `fullScreenCover`). 무조건 다시 걸면 `startDate` 가 지금으로 덮여
    ///    복원해 둔 경과 시간이 통째로 버려진다 — 앱을 껐다 켤 때마다 30분 타이머가 30:00 부터
    ///    다시 시작하던 문제이고, 스마트 스택 위젯도 같은 값을 읽으므로 손목까지 되감겼다.
    ///    (`onAppear` 는 화면이 다시 그려질 때도 오므로, 복원이 아니어도 다시 걸면 안 된다.)
    func start() {
        guard startDate == nil else { return }

        startDate = Date()
        accumulatedPause = 0
        isPaused = false

        startTimer()

        // 알림 sec기화
        notificationService.removeAllNotifications()
        scheduleNotifications(elapsed: 0)

        saveState()

        // iOS로 Start Timer 메시지 전송 — 반복이면 아이폰은 회를 모르므로 전체 길이 한 번으로 보낸다
        let duration = totalDuration
        let offsets = rounds > 1 ? [] : prealertOffsets
        Task { @MainActor in
            WatchConnectivityManager.shared.sendTimerStart(
                duration: TimeInterval(duration),
                prealertOffsets: offsets
            )
        }
    }

    func stop() {
        stopTimer()
        startDate = nil
        pauseDate = nil
        accumulatedPause = 0
        timeRemaining = mainDuration
        currentRound = 0

        notificationService.removeAllNotifications()
        // 앱 안의 정지도 "확인했다"이다 — 폰에서 뒤늦게 합류할 알림까지 멈춘다.
        EscalatingAlert.acknowledgeEverywhere()
        clearState()

        // iOS로 Timer Stop 메시지 전송
        Task { @MainActor in
            WatchConnectivityManager.shared.sendTimerStop()
        }
    }

    func togglePause() {
        isPaused.toggle()

        if isPaused {
            // 멈춤 상태 기록
            pauseDate = Date()
            stopTimer()
            notificationService.removeAllNotifications()
            saveState()

            // iOS로 Pause Timer 메시지 전송
            Task { @MainActor in
                WatchConnectivityManager.shared.sendTimerPause()
            }
        } else {
            // 정지 시간 보정
            if let pauseDate {
                accumulatedPause += Date().timeIntervalSince(pauseDate)
            }
            self.pauseDate = nil

            // 알림 재Settings
            notificationService.removeAllNotifications()
            let elapsed = elapsedSeconds
            if totalDuration - elapsed > 0 {
                scheduleNotifications(elapsed: elapsed)
            }

            startTimer()
            saveState()

            // iOS로 Resume Timer 메시지 전송 (아이폰은 전체를 센다)
            let left = totalDuration - elapsed
            Task { @MainActor in
                WatchConnectivityManager.shared.sendTimerResume(remainingDuration: TimeInterval(left))
            }
        }
    }

    // MARK: - Private Methods

    private func startTimer() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// 처음부터 잰 경과(초). 멈춰 있으면 멈춘 시각까지.
    private var elapsedSeconds: Int {
        guard let startDate else { return 0 }
        let reference = pauseDate ?? Date()
        return Int(reference.timeIntervalSince(startDate) - accumulatedPause)
    }

    /// 경과로 이 회의 남은 시간을 센다. 마지막 회가 끝나면 음수로 이어진다(오버타임).
    private func applyElapsed(_ elapsed: Int) {
        let totalLeft = totalDuration - elapsed
        let round = RoundSchedule.roundIndex(elapsed: TimeInterval(elapsed),
                                             roundSeconds: TimeInterval(mainDuration), rounds: rounds)
        timeRemaining = totalLeft <= 0
            ? totalLeft
            : Int(RoundSchedule.roundRemaining(elapsed: TimeInterval(elapsed),
                                               roundSeconds: TimeInterval(mainDuration), rounds: rounds))
        if round != currentRound {
            currentRound = round
            // 울린 만큼 예약을 다시 채운다 — 같은 이름은 덮어써져 겹치지 않는다
            if totalLeft > 0, !isPaused { topUpRoundNotifications(elapsed: elapsed) }
        }
    }

    private func updateTimeRemaining() {
        guard startDate != nil else { return }
        applyElapsed(elapsedSeconds)

        // 0sec가 되어도 Timer는 계속 실행 (음수로 진행)
        // stopTimer()를 호출하지 않음
    }

    /// 경과 `elapsed` 뒤에 울릴 것을 예약한다. 종료는 언제나, 회 안의 알림은 가까운 것부터 몫만큼.
    private func scheduleNotifications(elapsed: Int) {
        let duration = totalDuration - elapsed
        // 메인 Done 알림
        // ⚠️ 문구는 되풀이 알림(`EscalatingAlert`)과 **같아야** 한다. 예전에는 여기만 영어
        //    리터럴이라, 되풀이를 켜면 첫 알림은 영어로 뜨고 두 번째부터 한국어로 바뀌었다.
        notificationService.scheduleNotification(
            timeInterval: TimeInterval(duration),
            title: AlertContent.timerFinished.title,
            body: AlertContent.timerFinished.body,
            identifier: "main_timer_notification"
        )

        // 확인할 때까지 다시 부른다.
        // ⚠️ 워치는 언제나 `.primary` 다 — 손목에 있으니 가장 먼저 울려야 하고, 폰이 뒤에서
        //    합류한다(`TimerEngine` 의 `.secondary`). 워치를 뒤로 미루면 사슬이 뒤집힌다.
        EscalatingAlert.schedule(policy: EscalationPolicy.current(),
                                 role: .primary,
                                 finishFireAfter: TimeInterval(duration))

        if !prealertOffsets.isEmpty || rounds > 1 {
            topUpRoundNotifications(elapsed: elapsed)
        }
        // 단일 종료 before alert (하위 호환성)
        else if notificationTime > 0 && duration > notificationTime {
            let pointTime = duration - notificationTime
            notificationService.scheduleNotification(
                timeInterval: TimeInterval(pointTime),
                title: "Custom Alert",
                body: "\(notificationTime.formattedTimeString) remaining.",
                identifier: "point_timer_notification"
            )
        }
    }

    /// 예비 알림·회 끝을 가까운 것부터 예약 몫만큼(`RoundSchedule`). 반복이 없으면 예비 알림 몇 개가 전부다.
    /// ⚠️ 워치도 앱이 멈춰 있으면 다시 채우지 못한다 — 처음 깔아 둔 만큼만 울린다.
    private func topUpRoundNotifications(elapsed: Int) {
        let escalation = EscalationSchedule.offsets(policy: EscalationPolicy.current(), role: .primary).count
        let events = RoundSchedule.upcoming(roundSeconds: TimeInterval(mainDuration), rounds: rounds,
                                            offsets: prealertOffsets.map(TimeInterval.init),
                                            after: TimeInterval(elapsed),
                                            limit: RoundSchedule.budget(escalationCount: escalation))
        for event in events {
            let body: String
            switch event.kind {
            case .prealert(let offset):
                // iPhone(`TimerEngine`)과 같은 키 — 두 기기가 다른 말을 하면 안 된다.
                body = offset < 60
                    ? String(localized: "\(offset) sec remaining")
                    : String(localized: "\(offset / 60) min remaining")
            case .roundEnd:
                body = String(localized: "Round \(event.round + 1) of \(rounds) done")
            }
            notificationService.scheduleNotification(
                timeInterval: event.at - TimeInterval(elapsed),
                title: AppName.notification,
                body: body,
                identifier: rounds > 1 ? event.identifierSuffix : "prealert_\(offsetID(event))"
            )
        }
    }

    private func offsetID(_ event: RoundSchedule.Event) -> Int {
        if case .prealert(let offset) = event.kind { return offset }
        return 0
    }

    // MARK: - Cold Launch State Persistence
    //
    // 저장·복원은 `WatchTimerStore` 한 곳만 쓴다 — **스마트 스택 위젯이 같은 값을 읽기 때문이다**
    // (앱 그룹 컨테이너). 여기서 따로 `UserDefaults.standard` 에 적으면 위젯은 다른 컨테이너를
    // 보고 있어 그 변화를 영영 알지 못한다(손목에 유령 타이머가 남는다).

    private func saveState() {
        guard let startDate else { return }
        WatchTimerStore.save(WatchTimerState(
            mainDuration: mainDuration,
            prealertOffsets: prealertOffsets,
            startDate: startDate,
            isPaused: isPaused,
            accumulatedPause: accumulatedPause,
            pauseDate: pauseDate,
            rounds: rounds
        ))
    }

    private func clearState() {
        WatchTimerStore.clear()
    }

    /// Cold launch 시 **되살릴** 타이머가 있는지.
    /// ⚠️ `restoreFromSavedState()` 와 같은 규칙을 봐야 한다 — 갈라지면 "있다는데 안 뜨는"
    ///    상태가 된다. 그래서 판정은 `shouldRestore` 한 곳에서만 한다.
    static func hasSavedState() -> Bool {
        guard let saved = WatchTimerStore.load() else { return false }
        return shouldRestore(saved)
    }

    /// 되살릴 만한가.
    ///
    /// 아직 도는 중이면 당연히 되살린다. **끝난 타이머는 되풀이 알림이 아직 울리고 있을 때만**
    /// 되살린다 — 그때 화면이 필요한 이유는 하나, **확인 버튼을 주기 위해서**다.
    /// ⚠️ 이걸 빼면 알림이 계속 울리는데 앱을 열면 설정 화면이 떠서 **끌 방법이 화면에 없다**
    ///    (알림을 직접 탭하는 길만 남는다 — 실제로 그랬다).
    /// ⚠️ 반대로 조건 없이 되살리면 세 시간 전에 끝난 타이머가 "00:00" 으로 떠오른다.
    private static func shouldRestore(_ saved: WatchTimerState) -> Bool {
        if saved.isActive() { return true }

        let policy = EscalationPolicy.current()
        guard policy.isActive else { return false }
        let secondsSinceEnd = -saved.remainingSeconds()
        return secondsSinceEnd <= policy.duration.rawValue
    }

    /// 저장된 상태로부터 TimerViewModel 복원
    static func restoreFromSavedState() -> TimerViewModel? {
        guard let saved = WatchTimerStore.load() else { return nil }

        guard shouldRestore(saved) else {
            // 되살릴 이유가 없으면 치운다 — 스마트 스택에 남아 있던 "완료" 카드도 함께 정리된다.
            WatchTimerStore.clear()
            return nil
        }

        let vm = TimerViewModel(mainDuration: saved.mainDuration,
                                prealertOffsets: saved.prealertOffsets,
                                rounds: saved.rounds)
        vm.startDate = saved.startDate
        vm.accumulatedPause = saved.accumulatedPause
        vm.isPaused = saved.isPaused
        vm.pauseDate = saved.pauseDate
        // 남은 시간은 저장된 숫자가 아니라 **지금** 다시 센다 — 앱이 꺼져 있던 동안에도 시간은 갔다.
        // (위젯도 같은 계산을 쓴다 — `WatchTimerState.remainingSeconds`.)
        let elapsed = saved.elapsedSeconds()
        vm.currentRound = RoundSchedule.roundIndex(elapsed: TimeInterval(elapsed),
                                                   roundSeconds: TimeInterval(saved.mainDuration), rounds: vm.rounds)
        vm.applyElapsed(elapsed)

        if !saved.isPaused {
            vm.startTimer()

            // 남은 알림 재스케줄
            if saved.remainingSeconds() > 0 {
                vm.scheduleNotifications(elapsed: elapsed)
            }
        }

        return vm
    }

    /// ⚠️ **여기서 `stop()` 을 부르지 말 것.**
    ///
    /// `stop()` 은 예약된 알림을 전부 걷고(`removeAllNotifications`), 아이폰에 "확인했다"를 보내고
    /// (`acknowledgeEverywhere`), 저장된 상태까지 지운다(`WatchTimerStore.clear`). 그런데 이
    /// 뷰모델은 **버려지는 사본이 수시로 만들어진다** — `SettingView.destination(for:)` 는 화면을
    /// 다시 그릴 때마다 `TimerViewModel(...)` 을 새로 만들고, `@StateObject` 는 처음 것만 쓰고
    /// 나머지를 버린다. 그 사본이 죽을 때마다 **지금 돌고 있는 타이머의 알림이 통째로 사라졌다.**
    /// (그래서 워치에서 타이머를 걸어도 끝날 때 아무 진동이 없었다.)
    ///
    /// 정리는 화면을 실제로 떠날 때 `TimerView` 가 `stop()` 으로 한다. 여기서는 이 사본이
    /// 들고 있던 1초 타이머만 놓아준다.
    deinit {
        timer?.invalidate()
        timer = nil
    }
}
