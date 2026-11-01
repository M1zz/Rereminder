//
//  BlankStartPractice.swift
//  Rereminder
//
//  **첫 실행의 해 보기.** 그림을 본 뒤 종을 직접 옮기고 시작을 눌러, 자기가 고른 자리에서 우는 것을 본다.
//
//  ⚠️ 진짜 타이머가 아니다(`OnboardingDemoTimer`). 끝나면 고른 자리만 진짜 다이얼에 올린다.
//  ⚠️ 드래그 산술은 `DialDragTracker` 하나만 쓴다. 다이얼을 새로 계산하지 말 것.
//  ⚠️ VoiceOver 는 끌 수 없으므로 조절 동작(위아래 쓸기)으로 같은 일을 한다.
//

import SwiftUI

struct BlankStartPractice: View {
    /// 고른 알림 지점(초)을 넘긴다. 건너뛰면 nil.
    let onFinish: (Int?) -> Void

    private enum Step { case drag, start, watch, done }
    private static let total = 600
    private static let ringSize: CGFloat = 260
    private static let coordinateName = "blankStart.practice"

    @State private var step: Step = .drag
    @State private var alert = 60
    @State private var tracker = DialDragTracker()
    @State private var demo: OnboardingDemoTimer?

    private var line: String {
        switch step {
        case .drag: return String(localized: "Drag the bell to when you want a heads-up")
        case .start: return String(localized: "Now press start")
        case .watch: return String(localized: "It's sped up. Watch for the bell")
        case .done: return String(localized: "The real timer is set up the same way")
        }
    }

    var body: some View {
        LessonShell(line: line, isDone: step == .drag || step == .done,
                    doneTitle: step == .done ? String(localized: "Get Started") : String(localized: "Next"),
                    alwaysSkippable: step == .drag,
                    onDone: advance, onSkip: { onFinish(nil) }) {
            VStack(spacing: DSSpacing.xl) {
                if let demo {
                    DemoStage(demo: demo, size: Self.ringSize) { step = .done }
                } else {
                    // 무대의 배너 자리(`DemoStage`)와 같은 몫을 비워, 시작해도 원이 움직이지 않게 한다
                    dial.padding(.top, DemoStage.bannerSpace)
                }
                Text(String(localized: "You'll get a heads-up with \(TimeMapper.durationText(alert)) left"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                LessonPlayButton(action: run)
                    .opacity(step == .start ? 1 : 0)
                    .disabled(step != .start)
                    .accessibilityHidden(step != .start)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var dial: some View {
        OnboardingDemoRing(totalSeconds: Self.total, alerts: [alert], elapsed: 0, size: Self.ringSize)
            .coordinateSpace(name: Self.coordinateName)
            .contentShape(Circle().inset(by: -24))
            .gesture(drag)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(line)
            .accessibilityValue(TimeMapper.durationText(alert))
            .accessibilityAdjustableAction { direction in
                move(to: alert + (direction == .increment ? 60 : -60))
            }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateName))
            .onChanged { value in
                let center = CGPoint(x: Self.ringSize / 2, y: Self.ringSize / 2)
                if !tracker.isActive {
                    tracker.begin(at: value.startLocation, center: center,
                                  knobAngle: Double(alert) / Double(Self.total) * 360)
                }
                let angle = tracker.update(to: value.location, center: center, maxAngle: 360)
                move(to: Int((angle / 360 * Double(Self.total) / 60).rounded()) * 60)
            }
            .onEnded { _ in tracker.end() }
    }

    /// 화면은 사람이 눌러야 넘어간다. 종을 옮겼다고 저절로 다음 단계로 가지 않는다.
    private func advance() {
        if step == .done {
            onFinish(alert)
        } else {
            step = .start
        }
    }

    private func move(to seconds: Int) {
        let snapped = max(60, min(Self.total - 60, seconds))
        guard snapped != alert else { return }
        alert = snapped
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func run() {
        step = .watch
        let timer = OnboardingDemoTimer(totalSeconds: Self.total, alerts: [alert], demoSeconds: 6)
        demo = timer
        timer.start()
    }
}

// MARK: - 수업들이 함께 쓰는 조각

/// 하얀 화면 + 위의 한 줄 + 가운데 무대 + 끝나면 나오는 버튼. 첫 실행과 수업이 같은 모양이다.
struct LessonShell<Stage: View>: View {
    let line: String
    let isDone: Bool
    let doneTitle: String
    /// 버튼이 떠 있어도 건너뛰기를 함께 둔다(아직 끝난 단계가 아닐 때).
    var alwaysSkippable = false
    let onDone: () -> Void
    let onSkip: () -> Void
    @ViewBuilder let stage: Stage

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                // ⚠️ 위에서부터 고정이다. 가운데 정렬이면 아래에 버튼 하나만 생겨도 원이 움직인다.
                VStack(spacing: DSSpacing.xxl) {
                    Text(line)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 96)
                        .id(line)
                        .transition(.opacity)
                    stage
                }
                .padding(.top, 72)
                Spacer(minLength: 0)
                Button(action: onDone) {
                    Text(doneTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.lg)
                        .background(Capsule().fill(Color.accentColor))
                }
                .opacity(isDone ? 1 : 0)
                .disabled(!isDone)
                .accessibilityHidden(!isDone)
            }
            .padding(.horizontal, DSSpacing.xl)
            .padding(.bottom, DSSpacing.xxl)

            if !isDone || alwaysSkippable {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(DSSpacing.xl)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: line)
        .animation(.easeOut(duration: 0.3), value: isDone)
    }
}

struct LessonPlayButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.accentColor))
        }
        .accessibilityLabel(String(localized: "Start"))
    }
}

/// 장난감 타이머를 보는 무대: 링과 울릴 때 뜨는 배너.
/// ⚠️ 관찰은 이 서브뷰의 `@ObservedObject` 가 맡는다. 부모가 들고 있기만 하면 숫자가 멈춘 채로 보인다.
struct DemoStage: View {
    /// 링 위에 비워 두는 배너 자리
    static let bannerSpace: CGFloat = 52

    @ObservedObject var demo: OnboardingDemoTimer
    var size: CGFloat = 230
    var fill: CGFloat = 1
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            OnboardingDemoRing(totalSeconds: demo.totalSeconds, alerts: demo.alerts,
                               elapsed: demo.elapsed, size: size, fill: fill)
                .padding(.top, Self.bannerSpace)
            if let label = demo.ringingLabel {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "bell.fill")
                    Text(label).font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.sm)
                .background(Capsule().fill(DSColor.marker))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: demo.ringingLabel)
        .onChange(of: demo.isFinished) { _, finished in
            if finished { onFinished() }
        }
        .onDisappear { demo.stop() }
    }
}
