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
    var onTimerFinish: (() -> Void)?  // 타이머 종료 시 전체 화면 알림 콜백

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
            guard let self else { return }
            self.state = .overtime  // 오버타임 상태로 전환 (타이머는 계속 진행)
            ring()
            let message = "타이머 종료되었습니다"
            self.showToast?(message)

            // 전체 화면 알림 표시
            self.onTimerFinish?()

            // AlarmKit 미사용 시에만 푸시 알림
            if self.useAlarmKit == false {
                self.appStateManager?.sendNotificationIfNeeded(message)
            }

            // Live Activity를 alert 모드로 전환
            if self.useAlarmKit == true {
                Task {
                    await TokiAlarmManager.shared.endLiveActivity()
                }
            }
        }

        // Live Activity 인텐트 옵저버
        setupLiveActivityObservers()

        // Watch Connectivity 옵저버
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        let watchManager = WatchConnectivityManager.shared

        // Watch에서 타이머 시작 요청 수신
        watchManager.onTimerStart = { [weak self] syncData in
            guard let self else { return }

            let mainSeconds = Int(syncData.duration)
            let temp = Timer(
                name: "Watch에서 시작",
                mainSeconds: mainSeconds,
                prealertOffsetsSec: syncData.prealertOffsets
            )
            self.configure(from: temp)
            self.start()
            print("⌚ Watch에서 타이머 시작: \(mainSeconds)초")
        }

        // Watch에서 일시정지 요청 수신
        watchManager.onTimerPause = { [weak self] in
            self?.pause()
            print("⌚ Watch에서 일시정지")
        }

        // Watch에서 재개 요청 수신
        watchManager.onTimerResume = { [weak self] in
            self?.resume()
            print("⌚ Watch에서 재개")
        }

        // Watch에서 중지 요청 수신
        watchManager.onTimerStop = { [weak self] in
            self?.stop()
            print("⌚ Watch에서 중지")
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
        engine.start()
        state = .running

        // AlarmKit 스케줄 + Live Activity 시작
        if useAlarmKit, let template = currentTemplate {
            Task {
                do {
                    try await TokiAlarmManager.shared.startTimerWithLiveActivity(
                        mainDuration: TimeInterval(template.mainSeconds),
                        prealertOffsets: template.prealertOffsetsSec
                    )
                    print("✅ Live Activity 시작 성공")
                } catch {
                    print("❌ Live Activity 시작 실패: \(error.localizedDescription)")
                }
            }
        }

        // Watch로 타이머 시작 전송
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

        // Live Activity를 일시정지 상태로 업데이트
        if useAlarmKit, let template = currentTemplate {
            Task {
                let totalDuration = TimeInterval(template.mainSeconds)
                let elapsed = totalDuration - remaining
                await TokiAlarmManager.shared.pauseTimerWithLiveActivity(
                    totalDuration: totalDuration,
                    elapsedDuration: elapsed
                )
                print("✅ Live Activity 일시정지 업데이트")
            }
        }

        // Watch로 일시정지 전송
        WatchConnectivityManager.shared.sendTimerPause()
    }

    func resume() {
        engine.resume()
        state = .running

        // Live Activity를 카운트다운 상태로 업데이트
        if useAlarmKit, remaining > 0 {
            Task {
                await TokiAlarmManager.shared.resumeTimerWithLiveActivity(
                    remainingDuration: remaining
                )
                print("✅ Live Activity 재개 업데이트")
            }
        }

        // Watch로 재개 전송
        WatchConnectivityManager.shared.sendTimerResume(remainingDuration: remaining)
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

        // Watch로 중지 전송
        WatchConnectivityManager.shared.sendTimerStop()
    }
}
