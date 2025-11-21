//
//  TimerViewModel.swift
//  Toki
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
    let prealertOffsets: [Int]  // 여러 개의 예비 알림

    private var startDate: Date?        // 타이머 시작 시각
    private var pauseDate: Date?        // 일시정지한 시각
    private var accumulatedPause: TimeInterval = 0 // 총 정지 시간

    // 단일 알림용 초기화
    init(mainDuration: Int, notificationDuration: Int, notificationService: NotificationService = .init()) {
        self.mainDuration = mainDuration
        self.timeRemaining = mainDuration
        self.notificationTime = notificationDuration
        self.prealertOffsets = []
        self.notificationService = notificationService
    }

    // 다중 알림용 초기화
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

        // 알림 초기화
        notificationService.removeAllNotifications()
        scheduleNotifications(for: mainDuration)

        // iOS로 타이머 시작 메시지 전송
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

        // iOS로 타이머 중지 메시지 전송
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

            // iOS로 타이머 일시정지 메시지 전송
            Task { @MainActor in
                WatchConnectivityManager.shared.sendTimerPause()
            }
        } else {
            // 정지 시간 보정
            if let pauseDate {
                accumulatedPause += Date().timeIntervalSince(pauseDate)
            }
            self.pauseDate = nil

            // 알림 재설정
            notificationService.removeAllNotifications()
            if timeRemaining > 0 {
                scheduleNotifications(for: timeRemaining)
            }

            startTimer()

            // iOS로 타이머 재개 메시지 전송
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

        // 실제 경과 시간 = (현재 - 시작) - 멈췄던 시간
        let elapsed = Date().timeIntervalSince(startDate) - accumulatedPause
        let remaining = mainDuration - Int(elapsed)  // max 제거 - 음수도 허용

        self.timeRemaining = remaining

        // 0초가 되어도 타이머는 계속 실행 (음수로 진행)
        // stopTimer()를 호출하지 않음
    }

    private func scheduleNotifications(for duration: Int) {
        // 메인 완료 알림
        notificationService.scheduleNotification(
            timeInterval: TimeInterval(duration),
            title: "타이머 종료",
            body: "설정한 시간이 종료되었습니다.",
            identifier: "main_timer_notification"
        )

        // 다중 예비 알림
        if !prealertOffsets.isEmpty {
            for offset in prealertOffsets {
                let offsetSeconds = offset * 60
                if duration > offsetSeconds {
                    let pointTime = duration - offsetSeconds
                    notificationService.scheduleNotification(
                        timeInterval: TimeInterval(pointTime),
                        title: "Toki 타이머",
                        body: "\(offset)분 남았습니다",
                        identifier: "prealert_\(offset)"
                    )
                }
            }
        }
        // 단일 종료 전 알림 (하위 호환성)
        else if notificationTime > 0 && duration > notificationTime {
            let pointTime = duration - notificationTime
            notificationService.scheduleNotification(
                timeInterval: TimeInterval(pointTime),
                title: "지정 알림",
                body: "완료 \(notificationTime.formattedTimeString) 전입니다.",
                identifier: "point_timer_notification"
            )
        }
    }

    deinit {
        stop()
    }
}
