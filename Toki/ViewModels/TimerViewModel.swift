//
//  TimerViewModel.swift
//  Toki
//
//  Created by POS on 8/25/25.
//

import SwiftUI

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var remaining: TimeInterval = 0

    let engine = TimerEngine()
    var showToast: ((String) -> Void)?
    var appStateManager: AppStateManager?

    private var currentTemplate: Timer?
    private var useAlarmKit: Bool {
        UserDefaults.standard.bool(forKey: "useAlarmKit")
    }

    init() {
        // AlarmKit 기본값 true
        if UserDefaults.standard.object(forKey: "useAlarmKit") == nil {
            UserDefaults.standard.set(true, forKey: "useAlarmKit")
        }

        engine.onTick = { [weak self] r in self?.remaining = r }
        engine.onPreAlert = { [weak self] sec in
            let min = sec / 60
            ring()
            let message = "\(min)분 남았습니다"
            self?.showToast?(message)

            // AlarmKit 미사용 시에만 푸시 알림
            if self?.useAlarmKit == false {
                self?.appStateManager?.sendNotificationIfNeeded(message)
            }
        }
        engine.onFinish = { [weak self] in
            self?.state = .finished
            ring()
            let message = "타이머 종료되었습니다"
            self?.showToast?(message)

            // AlarmKit 미사용 시에만 푸시 알림
            if self?.useAlarmKit == false {
                self?.appStateManager?.sendNotificationIfNeeded(message)
            }

            // AlarmKit 알람 정리
            if self?.useAlarmKit == true {
                Task {
                    try? await TokiAlarmManager.shared.cancelAllAlarms()
                }
            }
        }
    }

    func configure(from template: Timer) {
        currentTemplate = template
        engine.configure(
            mainSeconds: template.mainSeconds,
            prealertOffsetsSec: template.prealertOffsetsSec
        )
        state = .idle
        remaining = TimeInterval(template.mainSeconds)
    }

    func start() {
        engine.start()
        state = .running

        // AlarmKit 스케줄
        if useAlarmKit, let template = currentTemplate {
            Task {
                do {
                    try await TokiAlarmManager.shared.scheduleTimer(
                        mainDuration: TimeInterval(template.mainSeconds),
                        prealertOffsets: template.prealertOffsetsSec
                    )
                    print("✅ AlarmKit 알람 스케줄 성공")
                } catch {
                    print("❌ AlarmKit 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    func pause() {
        engine.pause()
        state = .paused

        // AlarmKit 알람 취소
        if useAlarmKit {
            Task {
                try? await TokiAlarmManager.shared.cancelAllAlarms()
            }
        }
    }

    func resume() {
        engine.resume()
        state = .running

        // 남은 시간으로 재스케줄
        if useAlarmKit, remaining > 0 {
            Task {
                do {
                    let remainingPrealerts = currentTemplate?.prealertOffsetsSec.filter {
                        TimeInterval($0) < remaining
                    } ?? []
                    try await TokiAlarmManager.shared.scheduleTimer(
                        mainDuration: remaining,
                        prealertOffsets: remainingPrealerts
                    )
                    print("✅ AlarmKit 재스케줄 성공")
                } catch {
                    print("❌ AlarmKit 재스케줄 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    func stop() {
        engine.stop()
        state = .idle

        // AlarmKit 알람 취소
        if useAlarmKit {
            Task {
                try? await TokiAlarmManager.shared.cancelAllAlarms()
            }
        }
    }
}
