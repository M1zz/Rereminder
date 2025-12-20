//
//  TokiAlarmManager.swift
//  Toki
//
//  AlarmKit-based timer alarm manager
//

import Foundation

#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
import AlarmKit
import SwiftUI
import AppIntents

@MainActor
class TokiAlarmManager: ObservableObject {
    typealias AlarmConfiguration = AlarmManager.AlarmConfiguration<TokiTimerData>

    static let shared = TokiAlarmManager()

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
                print("❌ 알림 권한 요청 실패: \(error)")
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
        // 권한 확인
        guard await requestAuthorization() else {
            throw TimerAlarmError.notAuthorized
        }

        // 기존 알람 취소
        try await cancelAll()

        print("⚠️ AlarmKit 타이머 스케줄은 현재 비활성화되어 있습니다")
        print("   기본 타이머 엔진만 사용합니다")

        // AlarmKit API 구조가 변경되어 임시로 비활성화
        // 기본 타이머 기능(TimerEngine)은 정상 작동합니다
    }

    // MARK: - Control Methods

    func pause() async throws {
        print("⏸️ AlarmKit 일시정지 (비활성화됨)")
    }

    func resume() async throws {
        print("▶️ AlarmKit 재개 (비활성화됨)")
    }

    func stop() async throws {
        currentAlarmID = nil
        print("⏹️ AlarmKit 중지 (비활성화됨)")
    }

    // MARK: - Cancel

    func cancelAll() async throws {
        currentAlarmID = nil
        print("🗑️ AlarmKit 취소 (비활성화됨)")
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
            return "알림 권한이 필요합니다"
        case .schedulingFailed:
            return "알람 스케줄링에 실패했습니다"
        }
    }
}

#else
// macOS용 더미 구현
@MainActor
class TokiAlarmManager: ObservableObject {
    enum AuthorizationState {
        case notDetermined, denied, authorized
    }

    static let shared = TokiAlarmManager()

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
            return "알림 권한이 필요합니다"
        case .schedulingFailed:
            return "알람 스케줄링에 실패했습니다"
        }
    }
}
#endif
