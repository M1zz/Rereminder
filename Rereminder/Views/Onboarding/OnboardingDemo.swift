//
//  OnboardingDemo.swift
//  Rereminder
//
//  온보딩의 **체험 모드** — 고른 상황의 타이머를 **10초 만에** 돌려 보여 준다.
//  (배속은 길이를 따라 정해진다: 10분이면 60배, 30분이면 180배)
//
//  왜 굴려 보여 주나: "끝나기 전에 여러 번 알려 드려요"는 글로 읽으면 그냥 문장이다.
//  10분 타이머가 10초 만에 도는 걸 보면, 5분 전에 한 번·1분 전에 한 번 **울리는 걸 눈으로**
//  보게 된다. 그게 이 앱을 쓸지 말지 정하는 순간이다.
//
//  ⚠️ 진짜 타이머가 아니다. `TimerEngine` 도, 알림도, Live Activity 도 건드리지 않는다 —
//     화면 안에서만 도는 장난감이라 온보딩을 껐다 켜도 아무 흔적이 남지 않는다.
//

import SwiftUI

// MARK: - 장난감 타이머

@MainActor
final class OnboardingDemoTimer: ObservableObject {
    /// 시작 후 경과(초, 실제 타이머 시간 기준).
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var isRunning = false
    /// 방금 울린 알림 — 화면 위 배너로 잠깐 떴다 사라진다.
    @Published private(set) var ringingLabel: String?
    /// 다 돌았나 (다시 보기 버튼을 띄우는 조건).
    @Published private(set) var isFinished = false

    let totalSeconds: Int
    /// 종료까지 남은 시간 기준 알림 지점.
    let alerts: [Int]
    /// 몇 배로 돌릴지 — **길이와 상관없이 체험은 늘 `demoSeconds` 안에 끝난다.**
    /// 배속을 60으로 고정했더니 30분짜리 회의 상황이 30초를 잡아먹었다. 온보딩에서 30초는
    /// 아무도 안 기다린다.
    let speed: Double

    /// 체험이 끝나기까지의 실제 시간(초).
    /// ⚠️ `nonisolated` — 아래 `init` 의 기본값으로 쓰이는데, 기본값은 메인 액터 밖에서도
    ///    평가될 수 있다(Swift 6 에서는 그대로 두면 오류).
    nonisolated static let demoSeconds: Double = 10

    private var task: Task<Void, Never>?
    private var ranAlerts: Set<Int> = []
    private var bannerTask: Task<Void, Never>?

    init(totalSeconds: Int, alerts: [Int], demoSeconds: Double = OnboardingDemoTimer.demoSeconds) {
        self.totalSeconds = totalSeconds
        self.alerts = alerts.filter { $0 > 0 && $0 < totalSeconds }
        self.speed = max(1, Double(max(1, totalSeconds)) / max(1, demoSeconds))
    }

    var remaining: Double { max(0, Double(totalSeconds) - elapsed) }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isFinished = false
        task = Task { [weak self] in
            let step = 1.0 / 30.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(step))
                guard let self, self.isRunning else { return }
                self.advance(by: step * self.speed)
                if self.remaining <= 0 { return }
            }
        }
    }

    func restart() {
        stop()
        elapsed = 0
        ranAlerts = []
        ringingLabel = nil
        isFinished = false
        start()
    }

    func stop() {
        isRunning = false
        task?.cancel()
        task = nil
    }

    private func advance(by seconds: Double) {
        elapsed = min(Double(totalSeconds), elapsed + seconds)
        let remainingNow = remaining

        // 지나친 알림을 울린다 — 배속이 빨라 한 틱에 두 개를 지나칠 수도 있다.
        for alert in alerts where !ranAlerts.contains(alert) && remainingNow <= Double(alert) {
            ranAlerts.insert(alert)
            ring(String(localized: "\(alert / 60) min left"))
        }

        if remainingNow <= 0 {
            isRunning = false
            isFinished = true
            ring(String(localized: "Time's up"))
        }
    }

    private func ring(_ label: String) {
        ringingLabel = label
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            self?.ringingLabel = nil
        }
    }
}

// MARK: - 체험용 링

/// 온보딩 전용 축소판 다이얼 — 앱의 기본 모양(이중 링)과 **같은 규칙**으로 그린다.
/// 바깥은 전체 남은 시간(구간 색), 안쪽은 지금 구간, 종은 알림 지점.
struct OnboardingDemoRing: View {
    let totalSeconds: Int
    let alerts: [Int]
    let elapsed: Double
    var size: CGFloat = 220

    private var lineWidth: CGFloat { size * 0.083 }
    private var elapsedSec: Int { Int(elapsed.rounded()) }

    private var segments: [TimerSections.Segment] {
        TimerSections.derive(mainSeconds: totalSeconds, alertOffsets: Set(alerts))
    }

    private var sectionProgress: TimerSections.Progress? {
        TimerSections.progress(mainSeconds: totalSeconds,
                               alertOffsets: Set(alerts),
                               elapsedSec: elapsedSec)
    }

    private var remainingRatio: CGFloat {
        CGFloat(max(0, min(1, (Double(totalSeconds) - elapsed) / Double(max(1, totalSeconds)))))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.plain.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // 남은 호를 구간 색으로 — 경계를 지날 때마다 색이 하나씩 없어진다(본 화면과 같다)
            ForEach(segments) { segment in
                let start = CGFloat(totalSeconds - segment.endSec) / CGFloat(totalSeconds)
                let end = CGFloat(totalSeconds - segment.startSec) / CGFloat(totalSeconds)
                let visibleEnd = min(end, remainingRatio)
                if visibleEnd > start {
                    Circle()
                        .trim(from: start, to: visibleEnd)
                        .stroke(SectionPalette.color(segment.index),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            }

            if let progress = sectionProgress, progress.isDivided {
                SectionInnerRing(progress: progress,
                                 diameter: SectionInnerRing.diameter(ringSize: size, lineWidth: lineWidth),
                                 lineWidth: SectionInnerRing.lineWidth(ringLineWidth: lineWidth))
            }

            // 알림 종 — 이 앱의 주인공이라 체험에서도 그대로 보인다
            ForEach(alerts, id: \.self) { alert in
                let fraction = Double(alert) / Double(totalSeconds)
                bell(at: fraction, isRung: remainingRatio <= CGFloat(fraction))
            }

            centerTimes
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: 0.1), value: elapsed)
    }

    private func bell(at fraction: Double, isRung: Bool) -> some View {
        ZStack {
            Circle().fill(DSColor.marker)
            Image(systemName: "bell.fill")
                .font(.system(size: lineWidth * 0.62, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
        // 울린 종은 물러난다 — 남은 종이 무엇인지가 보여야 한다
        .opacity(isRung ? 0.35 : 1)
        .offset(x: size / 2)
        .rotationEffect(.degrees(fraction * 360))
        .rotationEffect(.degrees(-90))
    }

    private var centerTimes: some View {
        let fontSize = size * 0.2
        return VStack(spacing: fontSize * 0.08) {
            Text(TimeMapper.mmss(Int(remaining.rounded())))
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()

            if let progress = sectionProgress, progress.isDivided {
                HStack(spacing: fontSize * 0.16) {
                    Circle()
                        .fill(SectionPalette.color(progress.index))
                        .frame(width: fontSize * 0.2, height: fontSize * 0.2)
                    Text(TimeMapper.mmss(progress.remainingSec))
                        .monospacedDigit()
                }
                .font(.system(size: fontSize * 0.62, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var remaining: Double { max(0, Double(totalSeconds) - elapsed) }
}
