//
//  TimerEngine.swift
//  Rereminder
//
//  Created by POS on 8/24/25.
//
//  리팩토링:
//  - endDate 기반 remaining 계산 (Date 비교만으로 정확)
//  - Pre-alert/종료 알림을 UNNotificationRequest로 스케줄 (백그라운드 보장)
//  - UI tick은 포그라운드에서만 500ms 간격 (배터리 절약)
//  - 앱이 돌아올 때 endDate 기반으로 즉시 재계산
//

import Foundation
import UserNotifications

enum TimerState: Equatable { case idle, running, paused, finished, overtime }

final class TimerEngine {

    struct Configuration: Equatable {
        var mainDuration: TimeInterval
        var prealertOffsetsSec: [TimeInterval]
    }

    // MARK: - Callbacks (UI 업데이트용)
    var onTick: ((TimeInterval) -> Void)?
    var onPreAlert: ((Int) -> Void)?   // 포그라운드일 때 인앱 토스트용
    var onFinish: (() -> Void)?

    /// Test Mode용 Time Multiplier (기본값 1.0 = 실시간)
    var timeMultiplier: Double = 1.0

    // MARK: - State
    private(set) var config: Configuration?
    private(set) var endDate: Date?
    private(set) var state: TimerState = .idle

    private var startDate: Date?
    private var pausedElapsed: TimeInterval = 0
    private var remainingWhenPaused: TimeInterval?
    private var firedOffsets = Set<Int>()

    // MARK: - Timer (UI tick 전용)
    private let queue = DispatchQueue(label: "timer.engine.queue")
    private var timer: DispatchSourceTimer?

    // MARK: - Notification IDs
    private static let notificationPrefix = "rereminder.timer."

    // MARK: - Public API

    func configure(mainSeconds: Int, prealertOffsetsSec: [Int]) {
        let dur = TimeInterval(max(1, mainSeconds))
        let offsets = prealertOffsetsSec
            .filter { $0 > 0 && $0 < Int(dur) }
            .sorted(by: >)
            .map(TimeInterval.init)
        config = .init(mainDuration: dur, prealertOffsetsSec: offsets)
        state = .idle
    }

    func start() {
        guard let cfg = config else { return }
        firedOffsets.removeAll()
        pausedElapsed = 0
        startDate = Date()
        endDate = Date().addingTimeInterval(cfg.mainDuration)
        state = .running

        onTick?(cfg.mainDuration)

        // 백그라운드 알림 스케줄
        scheduleNotifications(duration: cfg.mainDuration, offsets: cfg.prealertOffsetsSec)

        // UI tick 시작
        startUITick()
    }

    func pause() {
        guard (state == .running || state == .overtime),
              let start = startDate,
              let cfg = config else { return }

        let actualElapsed = Date().timeIntervalSince(start)
        pausedElapsed += actualElapsed * timeMultiplier
        remainingWhenPaused = cfg.mainDuration - pausedElapsed

        stopUITick()
        cancelScheduledNotifications()
        state = .paused
    }

    func resume() {
        guard state == .paused,
              let r = remainingWhenPaused,
              let cfg = config else { return }

        startDate = Date()
        endDate = Date().addingTimeInterval(r)

        // 아직 발생하지 않은 알림만 다시 스케줄
        let remainingOffsets = cfg.prealertOffsetsSec.filter {
            !firedOffsets.contains(Int($0)) && $0 < r
        }
        scheduleNotifications(duration: r, offsets: remainingOffsets)

        startUITick()
        state = r > 0 ? .running : .overtime
    }

    func stop() {
        stopUITick()
        cancelScheduledNotifications()
        endDate = nil
        startDate = nil
        pausedElapsed = 0
        remainingWhenPaused = nil
        firedOffsets.removeAll()
        state = .idle
    }

    /// 앱이 포그라운드로 돌아왔을 때 호출 — endDate 기반 재계산
    func recalculateOnForeground() {
        guard state == .running || state == .overtime,
              let start = startDate,
              let cfg = config else { return }

        let actualElapsed = Date().timeIntervalSince(start)
        let acceleratedElapsed = actualElapsed * timeMultiplier + pausedElapsed
        let remain = cfg.mainDuration - acceleratedElapsed

        // 포그라운드에 없는 동안 지나간 pre-alert 처리
        for off in cfg.prealertOffsetsSec {
            let offInt = Int(off)
            if !firedOffsets.contains(offInt) && remain <= off {
                firedOffsets.insert(offInt)
            }
        }

        if remain <= 0 && state == .running {
            state = .overtime
            DispatchQueue.main.async { self.onFinish?() }
        }

        DispatchQueue.main.async { self.onTick?(remain) }
    }

    // MARK: - UI Tick (포그라운드 전용, 500ms)

    private func startUITick() {
        stopUITick()

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(
            deadline: .now(),
            repeating: .milliseconds(500),   // 100ms → 500ms (배터리 절약)
            leeway: .milliseconds(100)
        )
        t.setEventHandler { [weak self] in
            guard let self,
                  let start = self.startDate,
                  let cfg = self.config else { return }

            let actualElapsed = Date().timeIntervalSince(start)
            let acceleratedElapsed = actualElapsed * self.timeMultiplier + self.pausedElapsed
            let remain = cfg.mainDuration - acceleratedElapsed

            // 포그라운드 인앱 pre-alert (토스트 + 사운드)
            for off in cfg.prealertOffsetsSec {
                let offInt = Int(off)
                if !self.firedOffsets.contains(offInt), remain <= off, remain > 0 {
                    self.firedOffsets.insert(offInt)
                    DispatchQueue.main.async { self.onPreAlert?(offInt) }
                }
            }

            if remain <= 0 && self.state == .running {
                self.state = .overtime
                DispatchQueue.main.async { self.onFinish?() }
            }

            DispatchQueue.main.async { self.onTick?(remain) }
        }
        t.resume()
        timer = t
    }

    private func stopUITick() {
        guard let t = timer else { return }
        t.setEventHandler {}
        t.cancel()
        timer = nil
    }

    // MARK: - UNNotificationRequest 스케줄 (백그라운드 보장)

    private func scheduleNotifications(duration: TimeInterval, offsets: [TimeInterval]) {
        let center = UNUserNotificationCenter.current()

        // Pre-alert 알림
        for off in offsets {
            let offInt = Int(off)
            let fireAfter = duration - off  // 시작으로부터 N초 후 발생
            guard fireAfter > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = AppName.notification
            content.body = String(localized: "\(offInt / 60) min remaining")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: fireAfter / timeMultiplier,  // test mode 보정
                repeats: false
            )
            let id = "\(Self.notificationPrefix)prealert.\(offInt)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }

        // 종료 알림
        let finishFireAfter = duration / timeMultiplier
        if finishFireAfter > 0 {
            let content = UNMutableNotificationContent()
            content.title = AppName.notification
            content.body = String(localized: "Timer finished")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: finishFireAfter,
                repeats: false
            )
            let id = "\(Self.notificationPrefix)finish"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelScheduledNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.notificationPrefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }
}
