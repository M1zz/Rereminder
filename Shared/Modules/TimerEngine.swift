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

    /// 테스트 모드용 시간 배수 (기본값 1.0 = 실시간, 10.0 = 10배속)
    var timeMultiplier: Double = 1.0

    private var config: Configuration?
    private var endDate: Date?
    private var startDate: Date?  // 시작 시간 (테스트 모드용)
    private var pausedElapsed: TimeInterval = 0  // 일시정지 전까지 경과 시간
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
        pausedElapsed = 0
        // 시작 시간 기록
        startDate = Date()
        // endDate는 정상적으로 설정 (압축하지 않음)
        endDate = Date().addingTimeInterval(cfg.mainDuration)
        startTimer()
        state = .running
        onTick?(cfg.mainDuration)
    }

    func pause() {
        guard (state == .running || state == .overtime),
              let start = startDate,
              let cfg = config else { return }

        // 현재까지 경과한 시간을 계산 (multiplier 적용)
        let actualElapsed = Date().timeIntervalSince(start)
        pausedElapsed += actualElapsed * timeMultiplier

        // 남은 시간 계산
        remainingWhenPaused = cfg.mainDuration - pausedElapsed

        stopTimer()
        state = .paused
    }

    func resume() {
        guard state == .paused,
              let r = remainingWhenPaused else { return }

        // 재개 시 새로운 시작 시간 설정
        startDate = Date()

        // endDate는 남은 시간 기준으로 설정
        endDate = Date().addingTimeInterval(r)

        startTimer()
        state = r > 0 ? .running : .overtime
    }

    func stop() {
        stopTimer()
        endDate = nil
        startDate = nil
        pausedElapsed = 0
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
            guard let self,
                  let start = self.startDate,
                  let cfg = self.config else {
                return
            }

            // 실제 경과 시간 * multiplier = 가속된 경과 시간
            let actualElapsed = Date().timeIntervalSince(start)
            let acceleratedElapsed = actualElapsed * self.timeMultiplier + self.pausedElapsed

            // 남은 시간 = 전체 시간 - 가속된 경과 시간
            let remain = cfg.mainDuration - acceleratedElapsed

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
