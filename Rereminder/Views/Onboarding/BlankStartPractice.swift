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

    private enum Step { case drag, start, watch, remove, done }
    private static let total = 600
    private static let coordinateName = "blankStart.practice"

    /// 가로로 눕힌 아이폰에서는 원을 줄이고, 안내 한 줄과 시작 버튼을 원 옆에 둔다.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isCompactHeight: Bool { verticalSizeClass == .compact }
    /// 화면 높이(안전 영역 안쪽). 작은 아이폰에서는 원을 줄여야 아래 버튼이 화면 안에 선다.
    @State private var screenHeight: CGFloat = 800
    /// 세로에서 원 말고 쓰는 높이: 문장(96) + 배너 자리 + 안내 한 줄 + 시작 버튼 + 아래 버튼 + 간격들.
    private static let portraitChrome: CGFloat = 450
    private var ringSize: CGFloat {
        isCompactHeight ? 190 : max(170, min(260, screenHeight - Self.portraitChrome))
    }

    @State private var step: Step = .drag
    @State private var alert = 60
    @State private var tracker = DialDragTracker()
    @State private var demo: OnboardingDemoTimer?
    /// 지우기 단계에서 하나 더 얹어 두는 종. 두 번 눌러 지우면 nil 로 돌아온다.
    @State private var extraBell: Int?

    private var line: String {
        switch step {
        case .drag: return String(localized: "Drag the bell to when you want a heads-up")
        case .start: return String(localized: "Now press start")
        case .watch: return String(localized: "It's sped up. Watch for the bell")
        case .remove: return String(localized: "Double-tap a bell to remove it.")
        case .done: return String(localized: "The real timer is set up the same way")
        }
    }

    var body: some View {
        LessonShell(line: line, isDone: step == .drag || step == .done,
                    doneTitle: step == .done ? String(localized: "Get Started") : String(localized: "Next"),
                    alwaysSkippable: step == .drag || step == .remove, scrollsStageWhenCompact: false,
                    onDone: advance,
                    // 지우기까지 왔으면 종은 이미 골랐다. 여기서 건너뛰어도 고른 자리는 다이얼에 올린다.
                    onSkip: { onFinish(step == .remove ? alert : nil) }) {
            // 세로는 위아래로, 가로는 원 옆에 안내와 시작 버튼을 둔다(높이가 모자라다).
            let layout = isCompactHeight
                ? AnyLayout(HStackLayout(spacing: DSSpacing.xl))
                : AnyLayout(VStackLayout(spacing: DSSpacing.xl))
            layout {
                if let demo {
                    DemoStage(demo: demo, size: ringSize) { showRemoveStep() }
                } else {
                    // 무대의 배너 자리(`DemoStage`)와 같은 몫을 비워, 시작해도 원이 움직이지 않게 한다
                    dial.padding(.top, DemoStage.bannerSpace)
                }
                VStack(spacing: DSSpacing.xl) {
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
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { screenHeight = $0 }
    }

    private var dial: some View {
        OnboardingDemoRing(totalSeconds: Self.total, alerts: [alert] + (extraBell.map { [$0] } ?? []),
                           elapsed: 0, size: ringSize)
            .coordinateSpace(name: Self.coordinateName)
            .contentShape(Circle().inset(by: -24))
            // 끄는 단계에서만 끈다. 지우는 단계에 끌기까지 받으면 두 번 누르기가 끌기에 먹힌다.
            .gesture(drag, isEnabled: step == .drag)
            .simultaneousGesture(doubleTap, isEnabled: step == .remove)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(line)
            .accessibilityValue(TimeMapper.durationText(alert))
            .accessibilityAdjustableAction { direction in
                guard step == .drag else { return }
                move(to: alert + (direction == .increment ? 60 : -60))
            }
            // VoiceOver 는 종을 골라 두 번 누를 수 없다. 같은 일을 동작 하나로 한다.
            .accessibilityAction(named: Text("Remove the extra bell")) {
                if step == .remove { removeExtraBell() }
            }
            .animation(.easeOut(duration: 0.2), value: extraBell)
    }

    /// 본 화면과 같은 손짓: 종을 **두 번** 눌러 지운다. **어느 종이든** 지워진다.
    /// 얹은 종만 받으면, 자기가 고른 종을 두 번 눌렀는데 아무 일도 없는 것이 고장으로 읽힌다.
    private var doubleTap: some Gesture {
        SpatialTapGesture(count: 2, coordinateSpace: .named(Self.coordinateName))
            .onEnded { value in
                guard let extraBell else { return }
                let center = CGPoint(x: ringSize / 2, y: ringSize / 2)
                let tapped = TimeMapper.ringAngle(at: value.location, center: center)
                func distance(to bell: Int) -> Double {
                    let gap = abs(tapped - Double(bell) / Double(Self.total) * 360).truncatingRemainder(dividingBy: 360)
                    return min(gap, 360 - gap)
                }
                // 종 근처(±25°)를 눌러야 한다. 둘 다 닿으면 가까운 쪽이다.
                let nearest = [alert, extraBell].min { distance(to: $0) < distance(to: $1) } ?? extraBell
                guard distance(to: nearest) <= 25 else { return }
                // 고른 종을 지웠으면 남은 종이 다이얼에 올라갈 자리다
                if nearest == alert { alert = extraBell }
                removeExtraBell()
            }
    }

    /// 체험이 끝나면 종 하나를 더 얹어 지워 보게 한다. 고른 종에서 멀리 떨어진 자리에 둔다.
    private func showRemoveStep() {
        extraBell = alert <= Self.total / 2 ? alert + 240 : alert - 240
        demo = nil
        step = .remove
    }

    private func removeExtraBell() {
        extraBell = nil
        step = .done
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateName))
            .onChanged { value in
                let center = CGPoint(x: ringSize / 2, y: ringSize / 2)
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
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func run() {
        step = .watch
        let timer = OnboardingDemoTimer(totalSeconds: Self.total, alerts: [alert], pacing: .slowNearAlerts)
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
    /// 가로로 눕혔을 때 무대가 화면보다 길면 밀 수 있게 한다. 무대 안에서 끄는 조작이 있으면 끈다(해 보기의 종).
    var scrollsStageWhenCompact = true
    let onDone: () -> Void
    let onSkip: () -> Void
    @ViewBuilder let stage: Stage

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()
            Group {
                if isCompactHeight {
                    // 가로: 왼쪽에 문장과 버튼, 오른쪽에 무대. 위아래로 쌓으면 원이 화면 밖으로 나간다.
                    HStack(spacing: DSSpacing.xl) {
                        VStack(spacing: DSSpacing.lg) {
                            Spacer(minLength: 0)
                            lineText
                            Spacer(minLength: 0)
                            doneButton
                        }
                        .containerRelativeFrame(.horizontal) { width, _ in width * 0.38 }
                        Group {
                            if scrollsStageWhenCompact {
                                ScrollView { stage.frame(maxWidth: .infinity) }
                                    .scrollBounceBehavior(.basedOnSize)
                            } else {
                                stage
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, DSSpacing.lg)
                } else {
                    VStack(spacing: 0) {
                        // ⚠️ 위에서부터 고정이다. 가운데 정렬이면 아래에 버튼 하나만 생겨도 원이 움직인다.
                        // 위 여백은 남는 만큼만 쓴다(최대 72). 고정이면 작은 화면에서 아래 버튼이 화면 밖으로 밀린다.
                        // 아래 Spacer 보다 먼저 채워져, 자리가 넉넉한 화면에서는 예전과 같은 자리에 선다.
                        Spacer(minLength: DSSpacing.lg)
                            .frame(maxHeight: 72)
                            .layoutPriority(1)
                        VStack(spacing: DSSpacing.xxl) {
                            lineText.frame(minHeight: 96)
                            stage
                        }
                        Spacer(minLength: 0)
                        doneButton
                    }
                }
            }
            .padding(.horizontal, DSSpacing.xl)
            .padding(.bottom, isCompactHeight ? DSSpacing.lg : DSSpacing.xxl)

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

    private var lineText: some View {
        Text(line)
            .font(.title2.weight(.bold))
            .multilineTextAlignment(.center)
            .id(line)
            .transition(.opacity)
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text(doneTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isCompactHeight ? DSSpacing.md : DSSpacing.lg)
                .background(Capsule().fill(Color.accentColor))
        }
        .opacity(isDone ? 1 : 0)
        .disabled(!isDone)
        .accessibilityHidden(!isDone)
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
    /// 링 위에 비워 두는 배너 자리.
    /// ⚠️ 배너 높이(46쯤)에 링과의 틈을 더한 값이다. 링의 선과 12시의 종은 틀 밖으로 조금 나오므로,
    ///    딱 맞추면 배너가 링에 얹혀 답답해 보인다.
    static let bannerSpace: CGFloat = 80

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
                HStack(spacing: DSSpacing.md) {
                    Image(systemName: "bell.fill")
                    Text(label).font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DSSpacing.xxl)
                .padding(.vertical, DSSpacing.md)
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
