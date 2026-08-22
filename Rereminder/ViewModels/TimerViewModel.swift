//
//  TimerViewModel.swift
//  Rereminder
//
//  Created by POS on 8/25/25.
//
//  리팩토링: Watch 콜백은 TimerScreenViewModel에서만 관리
//  여기서는 순수 타이머 상태 + Live Activity만 담당
//

import SwiftUI
import SwiftData
import TipKit

#if os(iOS) && !targetEnvironment(macCatalyst)
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

    /// 현재 타이머의 라벨 (예: "Mentoring") — 없으면 빈 문자열
    var currentLabel: String { currentTemplate?.label ?? "" }

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
            ring()
            let message = self.currentTemplate?.getFinishMessage() ?? "Timer finished"
            self.showToast?(message)
            self.appStateManager?.sendNotificationIfNeeded(message)

            switch ProGate.evaluate(.overtimeTracking) {
            case .allowed, .allowedWithTrial:
                // Pro 또는 trial 가능: 오버타임 카운트 계속
                ProGate.recordUsage(.overtimeTracking)
                self.state = .overtime
            case .blocked:
                // Trial 소진: 00:00에서 정지
                self.state = .finished
                self.engine.pause()
                self.endLiveActivity()
            }
            DispatchQueue.main.async { self.onTimerFinish?() }
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

    // 다이나믹 아일랜드 버튼이 앱 프로세스에서 부르는 자리.
    //
    // ⚠️ **처리했으면 반드시 `LiveActivityCommandStore.clear()` 를 부른다.** 인텐트는 그 기록이
    //    지워졌는지로 "앱이 받았나"를 판정하고, 못 받았다고 보이면 표시를 앞질러 바꾼다
    //    (`LiveActivityCommand.dispatch`). 여기서 안 지우면 진짜 상태를 어림값이 덮는다.
    // ⚠️ 지금 상태에 맞지 않는 명령은 **처리하지 않고 기록도 남겨 둔다** — 앱이 아직 타이머를
    //    복원하기 전(cold launch)일 수 있고, 그때는 복원 뒤 `applyPendingLiveActivityCommand` 몫이다.
    @objc private func handlePause() {
        guard state == .running || state == .overtime else { return }
        pause()
        LiveActivityCommandStore.clear()
    }

    @objc private func handleResume() {
        guard state == .paused else { return }
        resume()
        LiveActivityCommandStore.clear()
    }

    @objc private func handleStop() {
        guard state != .idle else { return }
        stop()
        LiveActivityCommandStore.clear()
    }

    // MARK: - Cold Launch Restore

    /// App Group에서 타이머 상태를 복원 (cold launch 시)
    /// 복원 성공 시 true 반환
    @discardableResult
    func restoreIfNeeded() -> Bool {
        guard state == .idle else { return false }

        let restored = engine.restoreFromSharedState()
        guard restored else { return false }

        state = engine.state
        remaining = max(0, engine.endDate?.timeIntervalSinceNow ?? 0)

        // 실행 중이면 Live Activity도 복원
        if state == .running || state == .overtime {
            if let cfg = engine.config {
                let temp = Timer(
                    name: "",
                    mainSeconds: Int(cfg.mainDuration),
                    prealertOffsetsSec: cfg.prealertOffsetsSec.map { Int($0) }
                )
                currentTemplate = temp
                startLiveActivity(template: temp, adoptExisting: true)
            }
        }

        return true
    }

    // MARK: - Configuration

    func configure(from template: Timer) {
        currentTemplate = template
        engine.configure(
            mainSeconds: template.mainSeconds,
            prealertOffsetsSec: template.prealertOffsetsSec,
            name: template.name
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

        // 5+5 trial 카운트: 2개 이상의 예비 알림으로 시작 시
        if let template = currentTemplate,
           template.prealertOffsetsSec.count > ProGate.freePrealertLimit {
            ProGate.recordUsage(.unlimitedPrealerts)
        }

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

        pushCloudRunning()
    }

    func pause() {
        engine.pause()
        state = .paused
        updateLiveActivity()
        WatchConnectivityManager.shared.sendTimerPause()

        // 테스트 모드(가속) 타이머는 endDate 의미가 달라 동기화 제외
        if engine.timeMultiplier == 1.0, let cfg = engine.config {
            CloudTimerSyncManager.shared.pushPaused(
                mainSeconds: Int(cfg.mainDuration),
                prealertOffsets: cfg.prealertOffsetsSec.map { Int($0) },
                name: cfg.name,
                remaining: max(0, remaining)
            )
        }
    }

    func resume() {
        engine.resume()
        state = .running
        updateLiveActivity()
        WatchConnectivityManager.shared.sendTimerResume(remainingDuration: remaining)
        pushCloudRunning()
    }

    func stop() {
        let wasSyncable = engine.timeMultiplier == 1.0
        saveTimerRecord(finished: state == .overtime || state == .finished)
        engine.stop()
        state = .idle
        endLiveActivity()
        WatchConnectivityManager.shared.sendTimerStop()
        timerStartTime = nil

        if wasSyncable {
            CloudTimerSyncManager.shared.pushIdle()
        }
    }

    private func pushCloudRunning() {
        guard engine.timeMultiplier == 1.0,
              let cfg = engine.config,
              let end = engine.endDate else { return }
        CloudTimerSyncManager.shared.pushRunning(
            mainSeconds: Int(cfg.mainDuration),
            prealertOffsets: cfg.prealertOffsetsSec.map { Int($0) },
            name: cfg.name,
            endDate: end
        )
    }

    // MARK: - Cloud Sync 적용 (다른 기기에서 제어된 상태 반영, 재전송 없음)

    func applyCloudRunning(mainSeconds: Int, prealertOffsets: [Int], name: String, endDate: Date) {
        let template = Timer(
            name: name,
            mainSeconds: mainSeconds,
            prealertOffsetsSec: prealertOffsets
        )
        currentTemplate = template
        timerStartTime = endDate.addingTimeInterval(-TimeInterval(mainSeconds))

        engine.applyRemoteRunning(
            mainSeconds: mainSeconds,
            prealertOffsetsSec: prealertOffsets,
            name: name,
            endDate: endDate
        )
        state = engine.state
        remaining = endDate.timeIntervalSinceNow

        if state == .running || state == .overtime {
            startLiveActivity(template: template, endDate: endDate)
        }
    }

    func applyCloudPause(mainSeconds: Int, prealertOffsets: [Int], name: String, remaining r: TimeInterval) {
        if currentTemplate == nil {
            currentTemplate = Timer(
                name: name,
                mainSeconds: mainSeconds,
                prealertOffsetsSec: prealertOffsets
            )
        }
        engine.applyRemotePause(
            mainSeconds: mainSeconds,
            prealertOffsetsSec: prealertOffsets,
            name: name,
            remaining: r
        )
        state = .paused
        remaining = max(0, r)
        updateLiveActivity()
    }

    func applyCloudStop() {
        guard state != .idle else { return }
        engine.stop()
        state = .idle
        endLiveActivity()
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
        do {
            try context.save()
        } catch {
            print("❌ 타이머 기록 저장 실패: \(error)")
        }

        if finished {
            ReviewRequestManager.shared.recordTimerCompletion()
            // 익명 활동 이벤트 — 완료 카운트 + iCloud 이벤트 스트림
            ActivityReporter.recordSignificantEvent()
            ActivityReporter.log("timer_complete")
            // 여러 기기 활용 팁 노출 조건(완료 2회 이상)을 위한 이벤트 도너
            if #available(iOS 17.0, *) {
                Task { await MultiDeviceTip.timerCompleted.donate() }
            }
        }
    }

    // MARK: - Live Activity

    /// endDate를 넘기면 그 절대 시각 기준으로 표시 (다른 기기에서 시작된 타이머 반영용)
    /// - Parameter adoptExisting: 복원 경로에서 true — 이미 살아 있는 활동을 채택한다.
    ///   무조건 새로 요청하면 앱을 껐다 켤 때마다 다이나믹 아일랜드에 활동이 하나씩 늘어난다.
    private func startLiveActivity(template: Timer,
                                   endDate remoteEndDate: Date? = nil,
                                   adoptExisting: Bool = false) {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let duration = TimeInterval(template.mainSeconds)
        let endDate = remoteEndDate ?? Date().addingTimeInterval(duration)
        let name = template.name

        if adoptExisting {
            LiveActivityController.adoptOrStart(name: name, duration: duration, endDate: endDate)
        } else {
            LiveActivityController.start(name: name, duration: duration, endDate: endDate)
        }
        #endif
    }

    private func updateLiveActivity() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let isPaused = state == .paused
        LiveActivityController.update(
            remaining: remaining,
            isPaused: isPaused,
            endDate: isPaused ? nil : Date().addingTimeInterval(remaining)
        )
        #endif
    }

    /// 남아 있는 활동을 전부 끝낸다 — 앱이 죽었다 살아난 뒤에도 없앨 수 있어야 한다
    /// (예전에는 메모리 참조가 사라져 있으면 조용히 아무것도 하지 않았다).
    private func endLiveActivity() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        LiveActivityController.endAll()
        #endif
    }
}
