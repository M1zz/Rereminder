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
    /// 반복 중 지금 몇 번째 회인가(0부터). 반복이 없으면 늘 0.
    @Published private(set) var currentRound = 0
    /// 이번 실행의 회 수(`RoundSchedule`). 1 이면 반복 없음.
    var rounds: Int { engine.config?.rounds ?? 1 }

    let engine = TimerEngine()
    var showToast: ((String) -> Void)?
    var appStateManager: AppStateManager?
    var onTimerFinish: (() -> Void)?
    var modelContext: ModelContext?

    /// 이번 실행이 읽는 설정.
    ///
    /// ⚠️ **저장된 템플릿을 그대로 들고 있지 않는다.** 도는 중에 🔖 시트에서 그 템플릿을 지우면
    ///    지운 객체의 속성을 읽는 순간 SwiftData 가 앱을 죽인다("backing data was detached").
    ///    그 순간이 하필 다음 예비 알림·종료다. 그래서 시작할 때 사본을 떠 두고(`use`) 그것만 읽는다.
    private var currentTemplate: Timer?
    /// 사본의 원본(저장된 템플릿)의 id. 기록을 물릴 때 스토어에서 **다시 찾아** 쓴다(`saveTimerRecord`).
    /// ⚠️ 원본 객체를 들고 있지 않는다 — 도는 사이 다른 기기에서 지운 것이 iCloud 로 들어오면 그 객체는
    ///    `isDeleted` 가 거짓인 채로 비어 버려, 기록에 물리거나 `lastUsedAt` 을 적는 순간 SwiftData 가 앱을 죽인다.
    private var sourceTemplateID: UUID?
    private var timerStartTime: Date?

    /// 이번 실행의 설정을 정한다. 저장된 것이면 사본을 읽고 원본은 기록용으로만 둔다.
    private func use(_ template: Timer) {
        if template.modelContext != nil {
            sourceTemplateID = template.id
            currentTemplate = template.detachedCopy()
        } else {
            sourceTemplateID = nil
            currentTemplate = template
        }
    }

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
            HomeLightController.shared.bellRang(seconds: sec,
                                                offsets: template.prealertOffsetsSec)
        }

        engine.onRoundChange = { [weak self] round in
            guard let self else { return }
            self.currentRound = round
            ring()
            let message = String(localized: "Round \(round + 1) of \(self.rounds)")
            self.showToast?(message)
            self.appStateManager?.sendNotificationIfNeeded(message)
            HomeLightController.shared.roundBegan()
        }

        engine.onFinish = { [weak self] in
            guard let self else { return }
            ring()
            let message = self.currentTemplate?.getFinishMessage() ?? String(localized: "Timer finished")
            self.showToast?(message)
            self.appStateManager?.sendNotificationIfNeeded(message)
            HomeLightController.shared.finished()

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
        currentRound = engine.currentRound
        if state == .paused {
            remaining = max(0, RoundSchedule.roundRemaining(elapsed: (engine.config?.totalDuration ?? 0) - engine.totalRemaining,
                                                            roundSeconds: engine.config?.mainDuration ?? 0,
                                                            rounds: rounds))
        }

        // 실행 중이면 Live Activity도 복원
        if state == .running || state == .overtime {
            if let cfg = engine.config {
                let temp = Timer(
                    name: "",
                    mainSeconds: Int(cfg.mainDuration),
                    prealertOffsetsSec: cfg.prealertOffsetsSec.map { Int($0) },
                    rounds: cfg.rounds
                )
                use(temp)
                startLiveActivity(template: temp, endDate: engine.endDate, adoptExisting: true)
            }
        }

        return true
    }

    // MARK: - Configuration

    func configure(from template: Timer) {
        use(template)
        engine.configure(
            mainSeconds: template.mainSeconds,
            prealertOffsetsSec: template.prealertOffsetsSec,
            name: template.displayName,
            // 세션 모드는 구간을 한 번 지나가는 일이라 반복하지 않는다
            rounds: template.isPresentation ? 1 : template.rounds
        )
        currentRound = 0
        state = .idle
        remaining = TimeInterval(template.mainSeconds)
    }

    // MARK: - Timer Controls

    func start() {
        timerStartTime = Date()

        let testModeEnabled = UserDefaults.standard.bool(forKey: "testModeEnabled")
        let stored = testModeEnabled
            ? (UserDefaults.standard.object(forKey: "testModeMultiplier") as? Double ?? 1.0)
            : 1.0
        // 0·음수·NaN 배속은 끝나는 시각을 무한대로 만들어 알림 예약과 메뉴 막대 표시(`Int(...)`)에서 앱을 죽인다.
        let multiplier = stored.isFinite && stored > 0 ? stored : 1.0
        engine.timeMultiplier = multiplier

        engine.start()
        currentRound = 0
        state = .running
        // 조명을 켜 둔 사람이면 집 목록을 미리 읽어 둔다 — 첫 종에서 열면 그 종은 놓친다.
        HomeLightController.shared.activateIfEnabled()

        // 같은 설정을 여러 날 반복해서 거는지 남긴다 — 그 반복을 앱이 먼저 알아채고
        // "저장해 둘까요?"라고 묻는 근거다(`RepeatDetector`).
        if let template = currentTemplate {
            RepeatDetector.record(.init(mainSec: template.mainSeconds,
                                        offsets: template.prealertOffsetsSec))
        }

        // Live Activity
        if let template = currentTemplate {
            startLiveActivity(template: template)
        }

        // Watch 동기화 (전송만, 수신 콜백은 TimerScreenViewModel에서 관리)
        if let template = currentTemplate {
            let sync = syncShape
            WatchConnectivityManager.shared.sendTimerStart(
                duration: TimeInterval(sync.mainSeconds),
                prealertOffsets: sync.offsets
            )
        }

        pushCloudRunning()
    }

    func pause() {
        // ⚠️ 돌고 있지 않으면 아무것도 하지 않는다. 워치가 보낸 "일시정지"는 이 기기에 타이머가 없을 때도 온다
        //    (워치에서 건 타이머를 이 기기가 못 받았을 때). 예전에는 엔진은 그대로인데 화면만 "일시정지"가 되고,
        //    맥에까지 멈춘 타이머를 보내 아무것도 돌지 않는 "일시정지" 화면이 남았다.
        guard state == .running || state == .overtime else { return }
        engine.pause()
        state = .paused
        updateLiveActivity()
        WatchConnectivityManager.shared.sendTimerPause()

        // 테스트 모드(가속) 타이머는 endDate 의미가 달라 동기화 제외
        if engine.timeMultiplier == 1.0, let cfg = engine.config {
            let sync = syncShape
            CloudTimerSyncManager.shared.pushPaused(
                mainSeconds: sync.mainSeconds,
                prealertOffsets: sync.offsets,
                name: Timer.displayName(stored: cfg.name, mainSeconds: Int(cfg.mainDuration),
                                       offsets: cfg.prealertOffsetsSec.map { Int($0) }),
                remaining: max(0, rounds > 1 ? engine.totalRemaining : remaining)
            )
        }
    }

    func resume() {
        // 멈춰 있지 않으면 이을 것이 없다 — 엔진은 그대로인데 화면만 "도는 중"으로 바뀌어 멈춘 채 남는다.
        guard state == .paused else { return }
        engine.resume()
        state = .running
        updateLiveActivity()
        WatchConnectivityManager.shared.sendTimerResume(remainingDuration: rounds > 1 ? engine.totalRemaining : remaining)
        pushCloudRunning()
    }

    func stop() {
        let wasSyncable = engine.timeMultiplier == 1.0
        saveTimerRecord(finished: state == .overtime || state == .finished)
        engine.stop()
        currentRound = 0
        state = .idle
        endLiveActivity()
        HomeLightController.shared.timerStopped()
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
        let sync = syncShape
        CloudTimerSyncManager.shared.pushRunning(
            mainSeconds: sync.mainSeconds,
            prealertOffsets: sync.offsets,
            name: Timer.displayName(stored: cfg.name, mainSeconds: Int(cfg.mainDuration),
                                       offsets: cfg.prealertOffsetsSec.map { Int($0) }),
            endDate: end
        )
    }

    /// 다른 기기에 보내는 모양. 반복이면 **전체 길이 한 번**으로 보내고 회 안의 알림은 싣지 않는다 —
    /// 받는 쪽은 회를 모르므로 한 바퀴 길이를 보내면 첫 회가 끝날 때 끝난 줄 안다. 회 알림은 건 기기가 울린다.
    private var syncShape: (mainSeconds: Int, offsets: [Int]) {
        guard let cfg = engine.config else { return (0, []) }
        if cfg.rounds > 1 { return (Int(cfg.totalDuration), []) }
        return (Int(cfg.mainDuration), cfg.prealertOffsetsSec.map { Int($0) })
    }

    // MARK: - Cloud Sync 적용 (다른 기기에서 제어된 상태 반영, 재전송 없음)

    func applyCloudRunning(mainSeconds: Int, prealertOffsets: [Int], name: String, endDate: Date) {
        let template = Timer(
            name: name,
            mainSeconds: mainSeconds,
            prealertOffsetsSec: prealertOffsets
        )
        use(template)
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

    /// 워치에서 건 타이머를 받는다. 울리는 순서는 다른 기기에서 받은 타이머와 같고(`.secondary`),
    /// 사용자가 이번에 새로 건 것이므로 시작 기록을 남기고 맥에도 전한다.
    func applyWatchRunning(mainSeconds: Int, prealertOffsets: [Int], endDate: Date) {
        applyCloudRunning(mainSeconds: mainSeconds,
                          prealertOffsets: prealertOffsets,
                          name: "",
                          endDate: endDate)
        RepeatDetector.record(.init(mainSec: mainSeconds, offsets: prealertOffsets))
        AnalyticsManager.log(.timerStarted(durationSeconds: mainSeconds,
                                           alertCount: prealertOffsets.count,
                                           presetName: nil))
        pushCloudRunning()
    }

    func applyCloudPause(mainSeconds: Int, prealertOffsets: [Int], name: String, remaining r: TimeInterval) {
        if currentTemplate == nil {
            use(Timer(
                name: name,
                mainSeconds: mainSeconds,
                prealertOffsetsSec: prealertOffsets
            ))
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
        HomeLightController.shared.timerStopped()
        timerStartTime = nil
    }

    // MARK: - Timer Record

    /// 기록을 어느 템플릿에 물릴까.
    /// - 저장된 템플릿으로 시작했으면 그 원본. ⚠️ 도는 중에 지워졌으면 물리지 않는다 —
    ///   지운 객체를 물리면 저장하다 죽고, 사본을 물리면 지운 템플릿이 칩으로 되살아난다.
    /// - 저장한 적 없는 임시 설정은 물리면 함께 삽입되어 템플릿 칩으로 쌓인다.
    ///   새로 설치한 사람의 칩은 자기가 저장한 것만이다. 기존 사용자는 쓰던 그대로 둔다.
    private func linkedTemplate(for template: Timer, in context: ModelContext) -> Timer? {
        guard let sourceID = sourceTemplateID else {
            return Self.recordLink(source: nil, running: template, isNewInstall: BlankStart.isNewInstall)
        }
        // 저장된 템플릿으로 시작했다 — 지금 스토어에 살아 있는 것만 물린다. 없으면(지워졌으면) 물리지 않는다.
        // 사본을 대신 물리면 지운 템플릿이 칩으로 되살아난다.
        var descriptor = FetchDescriptor<Timer>(predicate: #Predicate { $0.id == sourceID })
        descriptor.fetchLimit = 1
        guard let source = (try? context.fetch(descriptor))?.first else { return nil }
        return Self.recordLink(source: source, running: template, isNewInstall: BlankStart.isNewInstall)
    }

    static func recordLink(source: Timer?, running: Timer, isNewInstall: Bool) -> Timer? {
        if let source {
            return source.modelContext != nil && !source.isDeleted ? source : nil
        }
        return isNewInstall ? nil : running
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
            template: linkedTemplate(for: template, in: context)
        )

        context.insert(record)
        record.template?.lastUsedAt = Date()
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
        // 반복이면 잠금화면은 전체를 센다 — 앱이 멈춰 있으면 회가 바뀔 때 고칠 수 없다(`TimerEngine.totalRemaining`).
        let duration = RoundSchedule.total(roundSeconds: TimeInterval(template.mainSeconds), rounds: rounds)
        let endDate = remoteEndDate ?? Date().addingTimeInterval(duration)
        let name = rounds > 1 ? "\(template.displayName) × \(rounds)" : template.displayName

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
        let left = rounds > 1 ? engine.totalRemaining : remaining
        LiveActivityController.update(
            remaining: left,
            isPaused: isPaused,
            endDate: isPaused ? nil : Date().addingTimeInterval(left)
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
