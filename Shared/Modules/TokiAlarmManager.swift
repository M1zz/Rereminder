//
//  TokiAlarmManager.swift
//  Toki
//
//  Timer notification manager - uses UNNotification for now
//

import Foundation
import UserNotifications

@MainActor
class TokiAlarmManager: ObservableObject {
    static let shared = TokiAlarmManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private var scheduledNotifications: [String] = []

    private init() {}

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
        print("🗑️ 모든 타이머 알림 취소")
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
