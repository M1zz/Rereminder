//
//  TimerViewModel.swift
//  Rereminder
//
//  Created by 내꺼다 on 8/8/25.
//

import Foundation

class TimerViewModel: ObservableObject {
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

    func start() {
        startDate = Date()
        accumulatedPause = 0
        isPaused = false

        startTimer()

        // 알림 sec기화
        notificationService.removeAllNotifications()
        scheduleNotifications(for: mainDuration)

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

            // iOS로 Resume Timer 메시지 전송
            Task { @MainActor in
                WatchConnectivityManager.shared.sendTimerResume(remainingDuration: TimeInterval(timeRemaining))
            }
        }
    }

    // MARK: - Private Methods

    private func startTimer() {
        guard timer == nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTimeRemaining()
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
        notificationService.scheduleNotification(
            timeInterval: TimeInterval(duration),
            title: "Timer Finished",
            body: "Your set time has ended.",
            identifier: "main_timer_notification"
        )

        // 다중 Pre-alerts
        if !prealertOffsets.isEmpty {
            for offset in prealertOffsets {
                if duration > offset {
                    let pointTime = duration - offset
                    notificationService.scheduleNotification(
                        timeInterval: TimeInterval(pointTime),
                        title: AppName.notification,
                        body: "\(offset / 60) min remaining",
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

    deinit {
        stop()
    }
}
