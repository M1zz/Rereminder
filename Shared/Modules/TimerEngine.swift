//
//  TimerEngine.swift
//  Toki
//
//  Created by POS on 8/24/25.
//  actual timer logic. handling 'time'

import Foundation

enum TimerState: Equatable { case idle, running, paused, finished, overtime }

final class TimerEngine {

    struct Configuration: Equatable {
        var mainDuration: TimeInterval  // entire time
        var prealertOffsetsSec: [TimeInterval]
    }

    var onTick: ((TimeInterval) -> Void)?  // remaining time
    var onPreAlert: ((Int) -> Void)?
    var onFinish: (() -> Void)?

    private var config: Configuration?
    private var endDate: Date?
    private var remainingWhenPaused: TimeInterval?
    private var firedOffsets = Set<Int>()  // prevent prealert duplication
    private var state: TimerState = .idle

    private let queue = DispatchQueue(label: "timer.engine.queue")
    private var timer: DispatchSourceTimer?

    func configure(mainSeconds: Int, prealertOffsetsSec: [Int]) {
        let dur = TimeInterval(max(1, mainSeconds))
        let offsets =
            prealertOffsetsSec
            .filter { $0 > 0 && $0 < Int(dur) }
            .sorted(by: >)
            .map(TimeInterval.init)
        config = .init(mainDuration: dur, prealertOffsetsSec: offsets)
        state = .idle
    }

    func start() {
        guard let cfg = config else { return }
        firedOffsets.removeAll()
        endDate = Date().addingTimeInterval(cfg.mainDuration)
        startTimer()
        state = .running
        onTick?(cfg.mainDuration)
    }

    func pause() {
        guard (state == .running || state == .overtime), let end = endDate else { return }
        remainingWhenPaused = end.timeIntervalSinceNow  // 음수 시간도 허용
        stopTimer()
        state = .paused
    }

    func resume() {
        guard state == .paused, let r = remainingWhenPaused else { return }
        endDate = Date().addingTimeInterval(r)
        startTimer()
        state = r > 0 ? .running : .overtime  // 남은 시간에 따라 상태 결정
    }

    func stop() {
        stopTimer()
        endDate = nil
        remainingWhenPaused = nil
        firedOffsets.removeAll()
        state = .idle
    }

    private func startTimer() {
        stopTimer()

        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(
            deadline: .now(),
            repeating: .milliseconds(100),
            leeway: .milliseconds(50)
        )
        t.setEventHandler { [weak self] in
            guard let self, let end = self.endDate, let cfg = self.config else {
                return
            }
            let remain = end.timeIntervalSinceNow  // 음수 허용

            // trigger prealert
            for off in cfg.prealertOffsetsSec {
                let offInt = Int(off)
                if !self.firedOffsets.contains(offInt), remain <= off, remain > 0 {
                    self.firedOffsets.insert(offInt)
                    DispatchQueue.main.async { self.onPreAlert?(offInt) }
                }
            }

            // 0초 도달 시 알림만 보내고 타이머는 계속 진행 (오버타임)
            if remain <= 0 && self.state == .running {
                self.state = .overtime
                DispatchQueue.main.async {
                    self.onFinish?()
                }
            }

            DispatchQueue.main.async { self.onTick?(remain) }
        }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        guard let t = timer else { return }
        t.setEventHandler {}
        t.cancel()
        timer = nil
    }
}
