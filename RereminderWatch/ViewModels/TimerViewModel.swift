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

    private var startDate: Date?        // Start Timer 시각
    private var pauseDate: Date?        // Pause한 시각
    private var accumulatedPause: TimeInterval = 0 // 총 정지 시간

    // 단일 알림용 sec기화
    init(mainDuration: Int, notificationDuration: Int, notificationService: NotificationService = .init()) {
        self.mainDuration = mainDuration
        self.timeRemaining = mainDuration
        self.notificationTime = notificationDuration
        self.prealertOffsets = []
        self.notificationService = notificationService
    }

    // 다중 알림용 sec기화
    init(mainDuration: Int, prealertOffsets: [Int], notificationService: NotificationService = .init()) {
        self.mainDuration = mainDuration
        self.timeRemaining = mainDuration
        self.notificationTime = 0
        self.prealertOffsets = prealertOffsets
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
        scheduleNotifications(for: mainDuration)

        saveState()

        // iOS로 Start Timer 메시지 전송
        Task { @MainActor in
            WatchConnectivityManager.shared.sendTimerStart(
                duration: TimeInterval(mainDuration),
                prealertOffsets: prealertOffsets
            )
        }
    }

    func stop() {
        stopTimer()
        startDate = nil
        pauseDate = nil
        accumulatedPause = 0
        timeRemaining = mainDuration

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
            if timeRemaining > 0 {
                scheduleNotifications(for: timeRemaining)
            }

            startTimer()
            saveState()

            // iOS로 Resume Timer 메시지 전송
            Task { @MainActor in
                WatchConnectivityManager.shared.sendTimerResume(remainingDuration: TimeInterval(timeRemaining))
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

    private func updateTimeRemaining() {
        guard let startDate else { return }

        // 실제 경과 시간 = (현재 - Start) - 멈췄던 시간
        let elapsed = Date().timeIntervalSince(startDate) - accumulatedPause
        let remaining = mainDuration - Int(elapsed)  // max 제거 - 음수도 허용

        self.timeRemaining = remaining

        // 0sec가 되어도 Timer는 계속 실행 (음수로 진행)
        // stopTimer()를 호출하지 않음
    }

    private func scheduleNotifications(for duration: Int) {
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

        // 다중 Pre-alerts
        if !prealertOffsets.isEmpty {
            for offset in prealertOffsets {
                if duration > offset {
                    let pointTime = duration - offset
                    notificationService.scheduleNotification(
                        timeInterval: TimeInterval(pointTime),
                        title: AppName.notification,
                        // iPhone(`TimerEngine`)과 같은 키 — 두 기기가 다른 말을 하면 안 된다.
                        body: String(localized: "\(offset / 60) min remaining"),
                        identifier: "prealert_\(offset)"
                    )
                }
            }
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
            pauseDate: pauseDate
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
                                prealertOffsets: saved.prealertOffsets)
        vm.startDate = saved.startDate
        vm.accumulatedPause = saved.accumulatedPause
        vm.isPaused = saved.isPaused
        vm.pauseDate = saved.pauseDate
        // 남은 시간은 저장된 숫자가 아니라 **지금** 다시 센다 — 앱이 꺼져 있던 동안에도 시간은 갔다.
        // (위젯도 같은 계산을 쓴다 — `WatchTimerState.remainingSeconds`.)
        vm.timeRemaining = saved.remainingSeconds()

        if !saved.isPaused {
            vm.startTimer()

            // 남은 알림 재스케줄
            if vm.timeRemaining > 0 {
                vm.scheduleNotifications(for: vm.timeRemaining)
            }
        }

        return vm
    }

    deinit {
        stop()
    }
}
