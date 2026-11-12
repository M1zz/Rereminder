//
//  BlankStartIntro.swift
//  Rereminder
//
//  **첫 실행의 그림.** 무엇에 쓸 타이머인지 먼저 묻고, 그 이름을 단 타이머가 하얀 화면에서 돈다.
//
//  무엇에 쓰나요 → 끝에서야 울리는 타이머 → "울리면 이미 실패한 거예요" → 예비 알림이 있는 타이머.
//  그냥 시계가 돌면 무슨 그림인지 모른다. 자기 일(발표·수업…)의 이름이 붙어야 남의 이야기가 아니게 된다.
//  설정에서 다시 볼 때도 이 화면이다.
//
//  ⚠️ 진짜 타이머가 아니다(`OnboardingDemoTimer`) — 알림도 Live Activity 도 건드리지 않는다.
//  ⚠️ 장면이 멈추면 버튼을 내고 기다린다. 저절로 다음 장면이나 해 보기(`BlankStartPractice`)로 넘어가지 않는다.
//  ⚠️ 둘째 장면은 `Pacing.slowNearAlerts` 다. 빈 구간만 빨리 감고 종이 울리는 앞뒤는 실제 속도로 보여 준다.
//     한 배속으로 줄이면 종 두 번이 숫자에 묻혀 정신없이 지나간다.
//  ⚠️ 고른 이름은 문장에 끼워 넣지 않고 제목으로 따로 세운다. 끼워 넣으면 조사·격·관사가 언어마다 틀어진다.
//  ⚠️ 동작 줄이기를 켠 사람에게는 움직임 없이 마지막 장면과 문장을 바로 보여 준다.
//

import SwiftUI

struct BlankStartIntro: View {
    /// 끝 버튼 제목. 첫 실행에서는 해 보기로 넘어가므로 "다음"이다.
    var buttonTitle = String(localized: "Next")
    let onFinish: () -> Void

    /// 15분에 5분 전·1분 전. 종 사이가 충분히 벌어져야 빨리 감기와 실제 속도가 번갈아 보인다.
    private static let total = 900
    private static let alerts = [300, 60]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 가로로 눕힌 아이폰은 높이가 400pt 남짓이다. 그때는 글과 원을 옆으로 나란히 둔다.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    @StateObject private var plain = OnboardingDemoTimer(totalSeconds: total, alerts: [], demoSeconds: 2.5)
    @StateObject private var alerted = OnboardingDemoTimer(totalSeconds: total, alerts: alerts,
                                                           pacing: .slowNearAlerts)

    /// 무엇에 쓸 타이머인가. 고르기 전에는 nil 이고 그동안은 질문만 보인다.
    @State private var occasion: String?
    /// 첫 장면의 원은 비어 있다가 차오른다. 찬 길을 거꾸로 줄어드는 것을 바로 이어서 본다.
    @State private var ringFill: CGFloat = 0
    @State private var caption = ""
    @State private var showCaption = false
    @State private var showBells = false
    @State private var finished = false
    /// 앞 장면이 끝나 사람이 "다음"을 누르길 기다리는 중
    @State private var awaitingNext = false
    @State private var scene: Task<Void, Never>?

    private enum Line {
        static var onlyAtEnd: String { String(localized: "Most timers only ring at the end") }
        static var alreadyFailed: String { String(localized: "When the timer rings, you've already failed to keep time") }
        static var needHeadsUp: String { String(localized: "To stay on time, you need a heads-up before the end") }
        static var wrapUp: String { String(localized: "Time to start wrapping up") }
        static var lastBit: String { String(localized: "Just finish what you're on") }
        static var onTime: String { String(localized: "So you can finish on time") }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            if let occasion {
                scenes(named: occasion)
                    .transition(.opacity)
            } else {
                OccasionQuestion { picked in
                    withAnimation(.easeInOut(duration: 0.3)) { occasion = picked }
                    scene = Task { await run() }
                }
                .transition(.opacity)
            }

            if !finished {
                Button(action: onFinish) {
                    Text("Skip")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(DSSpacing.xl)
            }
        }
        #if DEBUG
        // 화면 확인용: `-introOccasion 발표` 로 질문을 건너뛰고 두 장면을 이어서 돌린다(누를 손이 없는 시뮬레이터 캡처).
        .task {
            guard occasion == nil, let preset = UserDefaults.standard.string(forKey: "introOccasion") else { return }
            occasion = preset
            await run()
            guard awaitingNext else { return }
            await wait(1_500)
            showSecondScene()
        }
        #endif
        .onDisappear {
            scene?.cancel()
            plain.stop()
            alerted.stop()
        }
    }

    @ViewBuilder
    private func scenes(named occasion: String) -> some View {
        Group {
            if isCompactHeight {
                HStack(spacing: DSSpacing.xxl) {
                    VStack(spacing: DSSpacing.lg) {
                        Spacer(minLength: 0)
                        words(named: occasion)
                        Spacer(minLength: 0)
                        startButton
                    }
                    .frame(maxWidth: .infinity)
                    stage(size: 190)
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    Spacer()
                    VStack(spacing: DSSpacing.lg) {
                        words(named: occasion)
                        stage(size: 230)
                    }
                    Spacer()
                    startButton
                }
            }
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.bottom, isCompactHeight ? DSSpacing.lg : DSSpacing.xxl)
        .padding(.top, isCompactHeight ? DSSpacing.lg : 0)
    }

    /// 이름표와 문장
    private func words(named occasion: String) -> some View {
        VStack(spacing: DSSpacing.lg) {
            // 이 타이머가 무슨 타이머인지. 문장과 따로 서 있어 어느 언어에서도 문법이 깨지지 않는다.
            Label(occasion, systemImage: "timer")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.sm)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            Text(caption)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .opacity(showCaption ? 1 : 0)
                .offset(y: showCaption ? 0 : 8)
                .frame(minHeight: 96)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([occasion, Line.onlyAtEnd, Line.alreadyFailed, Line.needHeadsUp, Line.onTime]
            .joined(separator: " "))
    }

    private func stage(size: CGFloat) -> some View {
        // 같은 자리의 같은 원이다. 뷰를 갈아 끼우면 두 원이 겹쳐 녹으면서 깨져 보인다.
        DemoStage(demo: showBells ? alerted : plain, size: size, fill: ringFill)
            .frame(height: size + DemoStage.bannerSpace)
    }

    private var isButtonShown: Bool { awaitingNext || finished }

    private var startButton: some View {
        Button(action: awaitingNext ? showSecondScene : onFinish) {
            Text(awaitingNext ? String(localized: "Next") : buttonTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.lg)
                .background(Capsule().fill(Color.accentColor))
        }
        .opacity(isButtonShown ? 1 : 0)
        .offset(y: isButtonShown ? 0 : 8)
        .disabled(!isButtonShown)
        .accessibilityHidden(!isButtonShown)
    }

    // MARK: - 순서

    private func say(_ text: String) async {
        withAnimation(.easeOut(duration: 0.25)) { showCaption = false }
        await wait(250)
        caption = text
        withAnimation(.easeOut(duration: 0.4)) { showCaption = true }
    }

    private func wait(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }

    /// 남은 시간이 그 지점에 닿을 때까지 기다린다. 화면을 떠나 멈춘 타이머를 영영 기다리지 않는다.
    private func waitUntil(_ demo: OnboardingDemoTimer, reaches remaining: Double) async {
        while demo.remaining > remaining, !Task.isCancelled { await wait(40) }
    }

    private func run() async {
        guard !reduceMotion else {
            caption = Line.needHeadsUp
            showCaption = true
            ringFill = 1
            showBells = true
            finished = true
            return
        }
        await wait(300)
        withAnimation(.linear(duration: 0.8)) { ringFill = 1 }
        await wait(800)
        await say(Line.onlyAtEnd)
        await wait(700)
        plain.start()
        await waitUntil(plain, reaches: 0)
        await wait(200)
        await say(Line.alreadyFailed)
        await wait(600)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.35)) { awaitingNext = true }
    }

    private func showSecondScene() {
        withAnimation(.easeOut(duration: 0.2)) { awaitingNext = false }
        scene = Task { await runSecondScene() }
    }

    private func runSecondScene() async {
        await say(Line.needHeadsUp)
        showBells = true
        await wait(1_400)
        alerted.start()
        // 종이 울릴 때마다 그 알림으로 무엇을 하게 되는지 말한다. 울리기만 하면 쓸모가 안 보인다.
        await waitUntil(alerted, reaches: Double(Self.alerts[0]))
        await say(Line.wrapUp)
        await waitUntil(alerted, reaches: Double(Self.alerts[1]))
        await say(Line.lastBit)
        await waitUntil(alerted, reaches: 0)
        await say(Line.onTime)
        await wait(900)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.35)) { finished = true }
    }
}

// MARK: - 무엇에 쓰나요

/// 첫 질문. 흔한 자리 다섯에서 고르거나 직접 적는다. 고른 말이 그림 속 타이머의 이름이 된다.
private struct OccasionQuestion: View {
    let onPick: (String) -> Void

    @State private var selected: String?
    @State private var isWriting = false
    @State private var written = ""
    @FocusState private var isFieldFocused: Bool

    /// 돈을 낼 사람(발표자·강사·진행자)이 앞에 온다.
    private var presets: [(name: String, symbol: String)] {
        [(String(localized: "Presentation"), "person.wave.2.fill"),
         (String(localized: "Class"), "graduationcap.fill"),
         (String(localized: "Meeting"), "person.3.fill"),
         (String(localized: "Workout"), "figure.run"),
         (String(localized: "Study"), "book.fill")]
    }

    private var answer: String? {
        if isWriting {
            let trimmed = written.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return selected
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isCompactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            // 가로로 눕히거나 키보드가 올라오면 목록이 화면보다 길다. 그때는 민다.
            ScrollView {
                VStack(spacing: isCompactHeight ? DSSpacing.lg : DSSpacing.xxl) {
                    Text("What do you need a timer for?")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: isCompactHeight ? 0 : 96)

                    // 가로에서는 두 줄로 나눠 한 화면에 다 보이게 한다
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DSSpacing.md),
                                             count: isCompactHeight ? 2 : 1),
                              spacing: DSSpacing.md) {
                        ForEach(presets, id: \.name) { preset in
                            row(preset.name, symbol: preset.symbol, isOn: !isWriting && selected == preset.name) {
                                isWriting = false
                                isFieldFocused = false
                                selected = preset.name
                            }
                        }
                        if isWriting {
                            TextField(String(localized: "Type it here"), text: $written)
                                .font(.body)
                                .focused($isFieldFocused)
                                .submitLabel(.done)
                                .padding(.horizontal, DSSpacing.lg)
                                .padding(.vertical, DSSpacing.lg)
                                .background(RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.accentColor, lineWidth: 2))
                                .onChange(of: written) { _, new in
                                    // 제목 한 줄에 서는 이름이다. 길면 그림이 밀린다.
                                    if new.count > 20 { written = String(new.prefix(20)) }
                                }
                        } else {
                            row(String(localized: "Write my own"), symbol: "pencil", isOn: false) {
                                isWriting = true
                                isFieldFocused = true
                            }
                        }
                    }
                }
                .padding(.top, isCompactHeight ? DSSpacing.xxxl : 72)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)

            Button {
                if let answer { onPick(answer) }
            } label: {
                Text("Next")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isCompactHeight ? DSSpacing.md : DSSpacing.lg)
                    .background(Capsule().fill(Color.accentColor))
            }
            .opacity(answer == nil ? 0.35 : 1)
            .disabled(answer == nil)
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.bottom, isCompactHeight ? DSSpacing.lg : DSSpacing.xxl)
        .animation(.easeInOut(duration: 0.2), value: isWriting)
    }

    private func row(_ title: String, symbol: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: symbol)
                    .font(.body)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.lg)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(isOn ? Color.accentColor : Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
