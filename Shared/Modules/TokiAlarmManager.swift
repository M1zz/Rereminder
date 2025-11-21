//
//  TokiAlarmManager.swift
//  Toki
//
//  Timer notification manager with Live Activity support
//

import Foundation
import UserNotifications
import ActivityKit

@MainActor
class TokiAlarmManager: ObservableObject {
    static let shared = TokiAlarmManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private var scheduledNotifications: [String] = []
    private var currentActivity: Activity<AlarmAttributes>?
    private var currentAlarmID: UUID?

    private init() {
        setupNotificationObservers()
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PauseTimerIntent"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let alarmID = notification.userInfo?["alarmID"] as? String,
               UUID(uuidString: alarmID) == self?.currentAlarmID {
                self?.handlePauseIntent()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResumeTimerIntent"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let alarmID = notification.userInfo?["alarmID"] as? String,
               UUID(uuidString: alarmID) == self?.currentAlarmID {
                self?.handleResumeIntent()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StopTimerIntent"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let alarmID = notification.userInfo?["alarmID"] as? String,
               UUID(uuidString: alarmID) == self?.currentAlarmID {
                self?.handleStopIntent()
            }
        }
    }

    private func handlePauseIntent() {
        // Broadcast to TimerViewModel
        NotificationCenter.default.post(name: NSNotification.Name("TimerShouldPause"), object: nil)
    }

    private func handleResumeIntent() {
        // Broadcast to TimerViewModel
        NotificationCenter.default.post(name: NSNotification.Name("TimerShouldResume"), object: nil)
    }

    private func handleStopIntent() {
        // Broadcast to TimerViewModel
        NotificationCenter.default.post(name: NSNotification.Name("TimerShouldStop"), object: nil)
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            let settings = await UNUserNotificationCenter.current().notificationSettings()
            authorizationStatus = settings.authorizationStatus

            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Live Activity Management

    func startLiveActivity(
        duration: TimeInterval,
        tintColor: String = "FF9900"
    ) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("❌ Live Activities가 비활성화되어 있습니다")
            return
        }

        let alarmID = UUID()
        currentAlarmID = alarmID

        let presentation = AlarmPresentation(
            countdown: CountdownPresentation(
                title: "타이머 진행 중",
                pauseButton: AlarmButton(text: "일시정지", systemImageName: "pause.fill")
            ),
            paused: PausedPresentation(
                title: "일시정지됨",
                resumeButton: AlarmButton(text: "재개", systemImageName: "play.fill")
            ),
            alert: AlertPresentation(
                title: "타이머",
                stopButton: AlarmButton(text: "중지", systemImageName: "xmark")
            )
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            tintColor: tintColor
        )

        let fireDate = Date().addingTimeInterval(duration)
        let initialState = AlarmAttributes.ContentState(
            mode: .countdown(AlarmMode.CountdownState(
                fireDate: fireDate,
                totalDuration: duration
            )),
            alarmID: alarmID
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity 시작: \(activity.id)")
        } catch {
            print("❌ Live Activity 시작 실패: \(error)")
            throw error
        }
    }

    func updateLiveActivityToPaused(
        totalDuration: TimeInterval,
        elapsedDuration: TimeInterval
    ) async {
        guard let activity = currentActivity else { return }

        let pausedState = AlarmAttributes.ContentState(
            mode: .paused(AlarmMode.PausedState(
                totalCountdownDuration: totalDuration,
                previouslyElapsedDuration: elapsedDuration
            )),
            alarmID: currentAlarmID ?? UUID()
        )

        await activity.update(using: pausedState)
        print("🔄 Live Activity 일시정지 업데이트")
    }

    func updateLiveActivityToCountdown(
        fireDate: Date,
        totalDuration: TimeInterval
    ) async {
        guard let activity = currentActivity else { return }

        let countdownState = AlarmAttributes.ContentState(
            mode: .countdown(AlarmMode.CountdownState(
                fireDate: fireDate,
                totalDuration: totalDuration
            )),
            alarmID: currentAlarmID ?? UUID()
        )

        await activity.update(using: countdownState)
        print("🔄 Live Activity 카운트다운 업데이트")
    }

    func endLiveActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = AlarmAttributes.ContentState(
            mode: .alert,
            alarmID: currentAlarmID ?? UUID()
        )

        await activity.end(
            using: finalState,
            dismissalPolicy: .after(.now + 5)
        )
        currentActivity = nil
        currentAlarmID = nil
        print("✅ Live Activity 종료")
    }

    // MARK: - Schedule Timer with Prealerts

    func scheduleTimer(
        mainDuration: TimeInterval,
        prealertOffsets: [Int]
    ) async throws {
        // 권한 확인
        let isAuthorized = await checkAuthorizationStatus()
        if !isAuthorized {
            let granted = await requestAuthorization()
            if !granted {
                throw TimerNotificationError.notAuthorized
            }
        }

        // 기존 알림 취소
        try await cancelAllAlarms()

        let center = UNUserNotificationCenter.current()

        // 예비 알림들 스케줄 (offset은 남은 시간)
        for offset in prealertOffsets.sorted(by: >) {
            let prealertTime = mainDuration - TimeInterval(offset)

            guard prealertTime > 0 else { continue }

            let minutes = offset / 60

            let content = UNMutableNotificationContent()
            content.title = "Toki 타이머"
            content.body = "\(minutes)분 남았습니다"
            content.sound = .default
            content.categoryIdentifier = "TIMER_ALERT"

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: prealertTime,
                repeats: false
            )

            let identifier = "prealert_\(offset)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try await center.add(request)
            scheduledNotifications.append(identifier)
        }

        // 메인 타이머 종료 알림
        let mainContent = UNMutableNotificationContent()
        mainContent.title = "Toki 타이머"
        mainContent.body = "타이머가 종료되었습니다"
        mainContent.sound = .default
        mainContent.categoryIdentifier = "TIMER_COMPLETE"

        let mainTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: mainDuration,
            repeats: false
        )

        let mainIdentifier = "main_timer"
        let mainRequest = UNNotificationRequest(
            identifier: mainIdentifier,
            content: mainContent,
            trigger: mainTrigger
        )

        try await center.add(mainRequest)
        scheduledNotifications.append(mainIdentifier)

        print("✅ 타이머 알림 스케줄 완료: \(scheduledNotifications.count)개")
    }

    // MARK: - Cancel Alarms

    func cancelAllAlarms() async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: scheduledNotifications)
        scheduledNotifications.removeAll()
        await endLiveActivity()
        print("🗑️ 모든 타이머 알림 취소")
    }
}

// MARK: - Live Activity Integration

extension TokiAlarmManager {
    func startTimerWithLiveActivity(
        mainDuration: TimeInterval,
        prealertOffsets: [Int]
    ) async throws {
        // 푸시 알림 스케줄
        try await scheduleTimer(mainDuration: mainDuration, prealertOffsets: prealertOffsets)

        // Live Activity 시작
        try await startLiveActivity(duration: mainDuration)
    }

    func pauseTimerWithLiveActivity(totalDuration: TimeInterval, elapsedDuration: TimeInterval) async {
        // 알림 취소
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: scheduledNotifications)
        scheduledNotifications.removeAll()

        // Live Activity 업데이트
        await updateLiveActivityToPaused(totalDuration: totalDuration, elapsedDuration: elapsedDuration)
    }

    func resumeTimerWithLiveActivity(remainingDuration: TimeInterval) async {
        // 남은 시간으로 알림 재스케줄
        do {
            let center = UNUserNotificationCenter.current()

            // 메인 타이머 종료 알림
            let mainContent = UNMutableNotificationContent()
            mainContent.title = "Toki 타이머"
            mainContent.body = "타이머가 종료되었습니다"
            mainContent.sound = .default
            mainContent.categoryIdentifier = "TIMER_COMPLETE"

            let mainTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: remainingDuration,
                repeats: false
            )

            let mainIdentifier = "main_timer"
            let mainRequest = UNNotificationRequest(
                identifier: mainIdentifier,
                content: mainContent,
                trigger: mainTrigger
            )

            try await center.add(mainRequest)
            scheduledNotifications.append(mainIdentifier)
        } catch {
            print("❌ 알림 재스케줄 실패: \(error)")
        }

        // Live Activity 업데이트
        let fireDate = Date().addingTimeInterval(remainingDuration)
        await updateLiveActivityToCountdown(fireDate: fireDate, totalDuration: remainingDuration)
    }
}

// MARK: - Error

enum TimerNotificationError: Error {
    case notAuthorized
    case schedulingFailed
}

extension TimerNotificationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "알림 권한이 필요합니다"
        case .schedulingFailed:
            return "알림 스케줄링에 실패했습니다"
        }
    }
}
