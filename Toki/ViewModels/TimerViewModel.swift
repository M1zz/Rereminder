//
//  TimerViewModel.swift
//  Toki
//
//  Created by POS on 8/25/25.
//
//  리팩토링: Watch 콜백은 TimerScreenViewModel에서만 관리
//  여기서는 순수 타이머 상태 + Live Activity만 담당
//

import SwiftUI
import SwiftData

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

@MainActor
final class TimerViewModel: ObservableObject {
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var remaining: TimeInterval = 0

    let engine = TimerEngine()
    var showToast: ((String) -> Void)?
    var appStateManager: AppStateManager?
    var onTimerFinish: (() -> Void)?
    var modelContext: ModelContext?

    private var currentTemplate: Timer?
    private var timerStartTime: Date?

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    private var currentActivity: Activity<TimerActivityAttributes>?
    #endif

    init() {
        // Live Activity 인텐트 옵저버
        setupLiveActivityObservers()

        engine.onTick = { [weak self] r in
            self?.remaining = r
        }

        engine.onPreAlert = { [weak self] sec in
            guard let self, let template = self.currentTemplate else { return }
            ring()
            let message = template.getPrealertMessage(for: sec)
            self.showToast?(message)
            self.appStateManager?.sendNotificationIfNeeded(message)
        }

        engine.onFinish = { [weak self] in
            guard let self else { return }
            self.state = .overtime
            ring()
            let message = self.currentTemplate?.getFinishMessage() ?? "Timer finished"
            self.showToast?(message)
            DispatchQueue.main.async { self.onTimerFinish?() }
            self.appStateManager?.sendNotificationIfNeeded(message)
        }
    }

    private func setupLiveActivityObservers() {
        let names = [
            ("PauseTimerIntent", #selector(handlePause)),
            ("ResumeTimerIntent", #selector(handleResume)),
            ("StopTimerIntent", #selector(handleStop)),
            ("TimerShouldPause", #selector(handlePause)),
            ("TimerShouldResume", #selector(handleResume)),
            ("TimerShouldStop", #selector(handleStop)),
        ]
        for (name, selector) in names {
            NotificationCenter.default.addObserver(
                self, selector: selector,
                name: NSNotification.Name(name), object: nil
            )
        }
    }

    @objc private func handlePause() { pause() }
    @objc private func handleResume() { resume() }
    @objc private func handleStop() { stop() }

    // MARK: - Configuration

    func configure(from template: Timer) {
        currentTemplate = template
        engine.configure(
            mainSeconds: template.mainSeconds,
            prealertOffsetsSec: template.prealertOffsetsSec
        )
        state = .idle
        remaining = TimeInterval(template.mainSeconds)
    }

    // MARK: - Timer Controls

    func start() {
        timerStartTime = Date()

        let testModeEnabled = UserDefaults.standard.bool(forKey: "testModeEnabled")
        let multiplier = testModeEnabled
            ? (UserDefaults.standard.object(forKey: "testModeMultiplier") as? Double ?? 1.0)
            : 1.0
        engine.timeMultiplier = multiplier

        engine.start()
        state = .running

        // Live Activity
        if let template = currentTemplate {
            startLiveActivity(template: template)
        }

        // Watch 동기화 (전송만, 수신 콜백은 TimerScreenViewModel에서 관리)
        if let template = currentTemplate {
            WatchConnectivityManager.shared.sendTimerStart(
                duration: TimeInterval(template.mainSeconds),
                prealertOffsets: template.prealertOffsetsSec
            )
        }
    }

    func pause() {
        engine.pause()
        state = .paused
        updateLiveActivity()
        WatchConnectivityManager.shared.sendTimerPause()
    }

    func resume() {
        engine.resume()
        state = .running
        updateLiveActivity()
        WatchConnectivityManager.shared.sendTimerResume(remainingDuration: remaining)
    }

    func stop() {
        saveTimerRecord(finished: state == .overtime)
        engine.stop()
        state = .idle
        endLiveActivity()
        WatchConnectivityManager.shared.sendTimerStop()
        timerStartTime = nil
    }

    // MARK: - Timer Record

    private func saveTimerRecord(finished: Bool) {
        guard let template = currentTemplate,
              let context = modelContext,
              let startTime = timerStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let elapsedSeconds = Int(elapsed)

        let record = TimerRecord(
            date: startTime,
            finished: finished,
            elapsedSeconds: elapsedSeconds,
            snapshotMainSeconds: template.mainSeconds,
            snapshotPrealertOffsetsSec: template.prealertOffsetsSec,
            template: template
        )

        context.insert(record)
        template.lastUsedAt = Date()
        try? context.save()

        if finished {
            ReviewRequestManager.shared.recordTimerCompletion()
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity(template: Timer) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TimerActivityAttributes(
            timerName: template.name,
            totalDuration: TimeInterval(template.mainSeconds),
            startTime: Date()
        )

        let endDate = Date().addingTimeInterval(TimeInterval(template.mainSeconds))
        let initialState = TimerActivityAttributes.ContentState(
            remainingTime: TimeInterval(template.mainSeconds),
            isPaused: false,
            timestamp: Date(),
            endDate: endDate
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            currentActivity = activity
        } catch {
            print("❌ Live Activity 시작 실패: \(error)")
        }
        #endif
    }

    private func updateLiveActivity() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = currentActivity else { return }

        let endDate = state == .paused ? nil : Date().addingTimeInterval(remaining)
        let newState = TimerActivityAttributes.ContentState(
            remainingTime: remaining,
            isPaused: state == .paused,
            timestamp: Date(),
            endDate: endDate
        )

        Task { await activity.update(.init(state: newState, staleDate: nil)) }
        #endif
    }

    private func endLiveActivity() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
        #endif
    }
}
