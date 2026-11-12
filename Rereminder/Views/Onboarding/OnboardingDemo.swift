//
//  OnboardingDemo.swift
//  Rereminder
//
//  온보딩의 **체험 모드** — 고른 상황의 타이머를 **10초 만에** 돌려 보여 준다.
//  (배속은 길이를 따라 정해진다: 10분이면 60배, 30분이면 180배)
//  알림이 있는 체험은 `Pacing.slowNearAlerts` 로 돌린다. 빈 구간만 빨리 감고 종이 울리는 앞뒤는 실제 속도다.
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

    /// 시간이 흐르는 빠르기.
    enum Pacing {
        /// 처음부터 끝까지 같은 배속
        case linear
        /// 아무 일도 없는 구간은 빨리 감고, **알림과 종료 앞뒤는 실제 속도로** 흐른다.
        /// 한 배속으로 쭉 줄이면 종이 울리는 순간이 숫자에 묻혀 지나가 버린다.
        case slowNearAlerts
    }

    let pacing: Pacing

    /// 실제 속도로 흐르는 몫(초): 울리기 전과 울린 뒤
    nonisolated static let slowLead: Double = 2.5
    nonisolated static let slowTail: Double = 1.5
    /// 실제 속도 구간에서 멀어질수록 빨라지는 정도. 클수록 빈 구간을 빨리 건넌다.
    nonisolated static let warpGain: Double = 6

    init(totalSeconds: Int, alerts: [Int], demoSeconds: Double = OnboardingDemoTimer.demoSeconds,
         pacing: Pacing = .linear) {
        self.totalSeconds = totalSeconds
        self.alerts = alerts.filter { $0 > 0 && $0 < totalSeconds }
        self.speed = max(1, Double(max(1, totalSeconds)) / max(1, demoSeconds))
        self.pacing = pacing
    }

    /// 남은 시간이 `remaining` 일 때의 배속. **순수 함수.**
    /// 알림(과 종료) 앞뒤는 1배속이고, 거기서 멀어질수록 빨라졌다가 다음 알림에 다가가며 다시 느려진다.
    /// 시작 지점도 느린 자리로 쳐서 처음에는 천천히 떠난다.
    nonisolated static func warpSpeed(remaining: Double, total: Double, alerts: [Int]) -> Double {
        // 울리는 지점들: 예비 알림과 종료(0). 종료 뒤에는 흐를 시간이 없다.
        var distance = total - remaining
        for mark in alerts.map(Double.init) + [0] {
            let zoneStart = mark + slowLead
            let zoneEnd = mark - slowTail
            if remaining <= zoneStart && remaining >= zoneEnd { return 1 }
            distance = min(distance, remaining > zoneStart ? remaining - zoneStart : zoneEnd - remaining)
        }
        return 1 + warpGain * max(0, distance)
    }

    var remaining: Double { max(0, Double(totalSeconds) - elapsed) }

    private var currentSpeed: Double {
        switch pacing {
        case .linear: return speed
        case .slowNearAlerts:
            return Self.warpSpeed(remaining: remaining, total: Double(totalSeconds), alerts: alerts)
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isFinished = false
        task = Task { [weak self] in
            let step = 1.0 / 30.0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(step))
                guard let self, self.isRunning else { return }
                self.advance(by: step * self.currentSpeed)
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
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        bannerTask?.cancel()
        // 실제 속도로 흐르는 동안은 배너가 떠 있다. 배너가 먼저 사라지면 느려진 이유가 안 보인다.
        let shown = pacing == .slowNearAlerts ? Self.slowTail : 1.1
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(shown))
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
    /// 저장한 설정 목록의 작은 다이얼은 숫자 없이 모양만 그린다
    var showsTime = true
    /// 첫 실행의 그림에서 빈 원이 차오르는 정도(0~1). 12시에서 시계 방향이다.
    var fill: CGFloat = 1

    private var lineWidth: CGFloat { size * 0.083 }
    private var elapsedSec: Int { Int(elapsed.rounded()) }

    private var segments: [TimerSections.Segment] {
        TimerSections.derive(mainSeconds: totalSeconds, alertOffsets: Set(alerts))
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
                    ZStack {
                        Circle()
                            .trim(from: start, to: visibleEnd)
                            .stroke(SectionPalette.color(segment.index),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                        // 호 전체의 양 끝만 둥글게(본 화면과 같다). 꽉 찬 원에는 끝이 없다.
                        if remainingRatio < 1 {
                            if start == 0 {
                                RingEndCap(fraction: 0, facesForward: false, lineWidth: lineWidth)
                                    .fill(SectionPalette.color(segment.index))
                            }
                            if visibleEnd == remainingRatio {
                                RingEndCap(fraction: visibleEnd, facesForward: true, lineWidth: lineWidth)
                                    .fill(SectionPalette.color(segment.index))
                            }
                        }
                    }
                        .mask {
                            Circle()
                                .trim(from: 0, to: fill)
                                .stroke(style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                }
            }

            // 알림 종 — 이 앱의 주인공이라 체험에서도 그대로 보인다
            ForEach(alerts, id: \.self) { alert in
                let fraction = Double(alert) / Double(totalSeconds)
                bell(at: fraction, isRung: remainingRatio <= CGFloat(fraction),
                     color: SectionPalette.color(AlertPresets.bellSectionIndex(of: alert, among: Set(alerts))))
            }

            if showsTime {
                centerTimes
            }
        }
        .frame(width: size, height: size)
        .animation(.linear(duration: 0.1), value: elapsed)
    }

    private func bell(at fraction: Double, isRung: Bool, color: Color) -> some View {
        ZStack {
            Circle().fill(color)
            Image(systemName: "bell.fill")
                .font(.system(size: lineWidth * 0.62, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
        // 링을 따라 돌려 자리를 잡아도 종 자체는 언제나 똑바로 선다(`TimerMainView` 의 노브와 같다)
        .rotationEffect(.degrees(90 - fraction * 360))
        // 울린 종은 물러난다 — 남은 종이 무엇인지가 보여야 한다
        .opacity(isRung ? 0.35 : 1)
        .offset(x: size / 2)
        .rotationEffect(.degrees(fraction * 360))
        .rotationEffect(.degrees(-90))
    }

    private var centerTimes: some View {
        Text(TimeMapper.mmss(Int(remaining.rounded())))
            .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
            .monospacedDigit()
            // 숫자는 그냥 바뀐다. 링의 애니메이션을 물려받으면 앞뒤 숫자가 겹쳐 보인다.
            .transaction { $0.animation = nil }
    }

    private var remaining: Double { max(0, Double(totalSeconds) - elapsed) }
}
