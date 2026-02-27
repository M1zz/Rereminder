//
//  RereminderAlarmManager.swift
//  Rereminder
//
//  AlarmKit-based timer alarm manager
//

import Foundation

#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
import AlarmKit
import SwiftUI
import AppIntents

@MainActor
class RereminderAlarmManager: ObservableObject {
    typealias AlarmConfiguration = AlarmManager.AlarmConfiguration<RereminderTimerData>

    static let shared = RereminderAlarmManager()

    @Published var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    private let alarmManager = AlarmManager.shared
    private var currentAlarmID: UUID?

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        authorizationState = alarmManager.authorizationState
    }

    func requestAuthorization() async -> Bool {
        switch alarmManager.authorizationState {
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                await MainActor.run {
                    self.authorizationState = state
                }
                return state == .authorized
            } catch {
                print("❌ 알림 Request Permission 실패: \(error)")
                return false
            }
        case .denied:
            return false
        case .authorized:
            return true
        @unknown default:
            return false
        }
    }

    // MARK: - Schedule Timer Alarm

    func scheduleTimerAlarm(
        mainDuration: TimeInterval,
        prealertOffsets: [Int],
        prealertMessages: [Int: String] = [:],
        finishMessage: String? = nil,
        timerName: String? = nil
    ) async throws {
        // 권한 OK
        guard await requestAuthorization() else {
            throw TimerAlarmError.notAuthorized
        }

        // 기존 알람 Cancel
        try await cancelAll()

        print("⚠️ AlarmKit Timer 스케줄은 현재 비활성화되어 있습니다")
        print("   기본 Timer 엔진만 사용합니다")

        // AlarmKit API 구조가 변경되어 임시로 비활성화
        // 기본 Timer 기능(TimerEngine)은 정상 작동합니다
    }

    // MARK: - Control Methods

    func pause() async throws {
        print("⏸️ AlarmKit Pause (비활성화됨)")
    }

    func resume() async throws {
        print("▶️ AlarmKit Resume (비활성화됨)")
    }

    func stop() async throws {
        currentAlarmID = nil
        print("⏹️ AlarmKit Stop (비활성화됨)")
    }

    // MARK: - Cancel

    func cancelAll() async throws {
        currentAlarmID = nil
        print("🗑️ AlarmKit Cancel (비활성화됨)")
    }
}

// MARK: - Errors

enum TimerAlarmError: Error {
    case notAuthorized
    case schedulingFailed
}

extension TimerAlarmError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notification permission is required"
        case .schedulingFailed:
            return "Failed to schedule alarm"
        }
    }
}

#else
// macOS용 더미 구현
@MainActor
class RereminderAlarmManager: ObservableObject {
    enum AuthorizationState {
        case notDetermined, denied, authorized
    }

    static let shared = RereminderAlarmManager()

    @Published var authorizationState: AuthorizationState = .notDetermined

    private init() {}

    func checkAuthorizationStatus() {
        print("⚠️ AlarmKit은 macOS에서 지원되지 않습니다")
    }

    func requestAuthorization() async -> Bool {
        print("⚠️ AlarmKit은 macOS에서 지원되지 않습니다")
        return false
    }

    func scheduleTimerAlarm(
        mainDuration: TimeInterval,
        prealertOffsets: [Int],
        prealertMessages: [Int: String] = [:],
        finishMessage: String? = nil,
        timerName: String? = nil
    ) async throws {
        print("⚠️ AlarmKit은 macOS에서 지원되지 않습니다")
    }

    func pause() async throws {}
    func resume() async throws {}
    func stop() async throws {}
    func cancelAll() async throws {}
}

enum TimerAlarmError: Error {
    case notAuthorized
    case schedulingFailed
}

extension TimerAlarmError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notification permission is required"
        case .schedulingFailed:
            return "Failed to schedule alarm"
        }
    }
}
#endif
