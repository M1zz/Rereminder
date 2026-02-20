//
//  TimerViewModel.swift
//  Toki
//
//  Created by POS on 8/25/25.
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
    var onTimerFinish: (() -> Void)?  // Timer Finished 시 전체 화면 알림 콜백
    var modelContext: ModelContext?  // 기록 Save용

    private var currentTemplate: Timer?
    private var timerStartTime: Date?  // Start Timer 시간

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    private var currentActivity: Activity<TimerActivityAttributes>?  // Live Activity
    #endif

    init() {
        // NotificationCenter observers for Live Activity button actions
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PauseTimerIntent"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pause()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResumeTimerIntent"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resume()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("StopTimerIntent"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }

        engine.onTick = { [weak self] r in
            self?.remaining = r
            // Live Activity는 Text.timer로 자동 카운트다운되므로
            // 매번 업데이트할 필요 없음 (상태 변경 시에만 업데이트)
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

            print("🔔 Timer Finished! onFinish 호출됨")

            self.state = .overtime  // 오버타임 상태로 전환 (Timer는 계속 진행)
            ring()
            let message = self.currentTemplate?.getFinishMessage() ?? "Timer finished"
            self.showToast?(message)

            // 전체 화면 알림 표시
            DispatchQueue.main.async {
                print("🔔 전체 화면 알림 표시 시도")
                self.onTimerFinish?()
            }

            // 푸시 알림 전송
            self.appStateManager?.sendNotificationIfNeeded(message)
        }

        // Live Activity 인텐트 옵저버
        setupLiveActivityObservers()

        // Watch Connectivity 옵저버
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        let watchManager = WatchConnectivityManager.shared

        // Watch에서 Start Timer 요청 수신
        watchManager.onTimerStart = { [weak self] syncData in
            guard let self else { return }

            let mainSeconds = Int(syncData.duration)
            let temp = Timer(
                name: "Started from Watch",
                mainSeconds: mainSeconds,
                prealertOffsetsSec: syncData.prealertOffsets
            )
            self.configure(from: temp)
            self.start()
            print("⌚ Watch에서 Start Timer: \(mainSeconds)sec")
        }

        // Watch에서 Pause 요청 수신
        watchManager.onTimerPause = { [weak self] in
            self?.pause()
            print("⌚ Watch에서 Pause")
        }

        // Watch에서 Resume 요청 수신
        watchManager.onTimerResume = { [weak self] in
            self?.resume()
            print("⌚ Watch에서 Resume")
        }

        // Watch에서 Stop 요청 수신
        watchManager.onTimerStop = { [weak self] in
            self?.stop()
            print("⌚ Watch에서 Stop")
        }
    }

    private func setupLiveActivityObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TimerShouldPause"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pause()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TimerShouldResume"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resume()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TimerShouldStop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
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
        // Start Timer 시간 기록
        timerStartTime = Date()

        // Test Mode가 켜져 있을 때만 배수 Apply
        let testModeEnabled = UserDefaults.standard.bool(forKey: "testModeEnabled")
        let multiplier = testModeEnabled
            ? (UserDefaults.standard.object(forKey: "testModeMultiplier") as? Double ?? 1.0)
            : 1.0
        engine.timeMultiplier = multiplier

        engine.start()
        state = .running

        // Live Activity Start
        if let template = currentTemplate {
            startLiveActivity(template: template)
        }

        // Watch로 Start Timer 전송
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

        // Live Activity 업데이트
        updateLiveActivity()

        // Watch로 Pause 전송
        WatchConnectivityManager.shared.sendTimerPause()
    }

    func resume() {
        engine.resume()
        state = .running

        // Live Activity 업데이트
        updateLiveActivity()

        // Watch로 Resume 전송
        WatchConnectivityManager.shared.sendTimerResume(remainingDuration: remaining)
    }

    func stop() {
        // Timer 기록 Save
        saveTimerRecord(finished: state == .overtime)

        engine.stop()
        state = .idle

        // Live Activity 종료
        endLiveActivity()

        // Watch로 Stop 전송
        WatchConnectivityManager.shared.sendTimerStop()

        // Start 시간 sec기화
        timerStartTime = nil
    }

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

        // 템플릿의 마지막 사용 시간 업데이트
        template.lastUsedAt = Date()

        try? context.save()
        print("✅ Timer 기록 Save: \(finished ? "Done" : "중단"), 경과 시간: \(elapsedSeconds)sec")

        // Timer를 Done한 경우 리뷰 요청 체크
        if finished {
            ReviewRequestManager.shared.recordTimerCompletion()
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity(template: Timer) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities가 비활성화되어 있습니다")
            return
        }

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
            print("✅ Live Activity Start: \(template.name), 종료 시각: \(endDate)")
        } catch {
            print("❌ Live Activity Start 실패: \(error)")
        }
        #else
        print("⚠️ Live Activities는 iOS에서만 지원됩니다")
        #endif
    }

    private func updateLiveActivity() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = currentActivity else { return }

        // Pause 상태가 아닐 때만 endDate 계산
        let endDate = state == .paused ? nil : Date().addingTimeInterval(remaining)

        let newState = TimerActivityAttributes.ContentState(
            remainingTime: remaining,
            isPaused: state == .paused,
            timestamp: Date(),
            endDate: endDate
        )

        Task {
            await activity.update(
                .init(state: newState, staleDate: nil)
            )
        }
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
