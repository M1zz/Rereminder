//
//  TokiAlarmManager.swift
//  Toki
//
//  AlarmKit-based timer alarm manager
//

import Foundation
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

        // AlarmPresentation 구성 (Apple 샘플과 동일한 패턴)
        let alertContent = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: finishMessage ?? "타이머 종료"),
            stopButton: .stopButton
        )

        let countdownContent = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: timerName ?? "타이머 진행 중"),
            pauseButton: .pauseButton
        )

        let pausedContent = AlarmPresentation.Paused(
            title: "일시정지됨",
            resumeButton: .resumeButton
        )

        let presentation = AlarmPresentation(
            alert: alertContent,
            countdown: countdownContent,
            paused: pausedContent
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: TokiTimerData(timerName: timerName),
            tintColor: .orange
        )

        // Alarm 스케줄
        let alarmID = UUID()
        currentAlarmID = alarmID

        // 타이머: 지금부터 mainDuration 초 후에 알람
        let fireDate = Date.now.addingTimeInterval(mainDuration)

        let alarmConfiguration = AlarmConfiguration(
            countdownDuration: .init(preAlert: mainDuration, postAlert: nil),
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: StopTimerIntent(alarmID: alarmID.uuidString)
        )

        do {
            let alarm = try await alarmManager.schedule(id: alarmID, configuration: alarmConfiguration)
            print("✅ AlarmKit 타이머 스케줄 성공: \(Int(mainDuration))초")
            print("   - Alarm ID: \(alarm.id)")
            print("   - Alarm State: \(alarm.state)")
            print("   - Schedule: \(String(describing: alarm.schedule))")
            print("   - Fire Date: \(fireDate)")
        } catch {
            print("❌ AlarmKit 타이머 스케줄 실패: \(error)")
            print("   - Error details: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Control Methods

    func pause() async throws {
        guard let alarmID = currentAlarmID else {
            print("⚠️ 일시정지할 알람 ID가 없습니다")
            return
        }

        try alarmManager.pause(id: alarmID)
        print("⏸️ AlarmKit 타이머 일시정지")
    }

    func resume() async throws {
        guard let alarmID = currentAlarmID else {
            print("⚠️ 재개할 알람 ID가 없습니다")
            return
        }

        try alarmManager.resume(id: alarmID)
        print("▶️ AlarmKit 타이머 재개")
    }

    func stop() async throws {
        guard let alarmID = currentAlarmID else {
            print("⚠️ 중지할 알람 ID가 없습니다")
            return
        }

        try alarmManager.stop(id: alarmID)
        currentAlarmID = nil
        print("⏹️ AlarmKit 타이머 중지")
    }

    // MARK: - Cancel

    func cancelAll() async throws {
        if let alarmID = currentAlarmID {
            try alarmManager.cancel(id: alarmID)
            currentAlarmID = nil
            print("🗑️ AlarmKit 타이머 취소")
        }
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

// MARK: - AlarmButton Extensions (Apple 샘플과 동일)

extension AlarmButton {
    static var pauseButton: Self {
        AlarmButton(text: "일시정지", textColor: .black, systemImageName: "pause.fill")
    }

    static var resumeButton: Self {
        AlarmButton(text: "재개", textColor: .black, systemImageName: "play.fill")
    }

    static var stopButton: Self {
        AlarmButton(text: "확인", textColor: .white, systemImageName: "checkmark.circle.fill")
    }
}
