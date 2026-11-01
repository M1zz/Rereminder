//
//  BlankStartIntro.swift
//  Rereminder
//
//  **첫 실행의 그림.** 하얀 화면에서 15초쯤 혼자 돈다.
//
//  끝에서야 울리는 타이머 → "그때는 이미 늦었어요" → 끝나기 전에 종이 울리는 타이머.
//  글로 설명하면 그냥 문장인 것을 눈으로 보게 한다. 설정에서 다시 볼 때도 이 화면이다.
//
//  ⚠️ 진짜 타이머가 아니다(`OnboardingDemoTimer`) — 알림도 Live Activity 도 건드리지 않는다.
//  ⚠️ 장면이 멈추면 버튼을 내고 기다린다. 저절로 다음 장면이나 해 보기(`BlankStartPractice`)로 넘어가지 않는다.
//  ⚠️ 동작 줄이기를 켠 사람에게는 움직임 없이 마지막 장면과 문장을 바로 보여 준다.
//

import SwiftUI

struct BlankStartIntro: View {
    /// 끝 버튼 제목. 첫 실행에서는 해 보기로 넘어가므로 "다음"이다.
    var buttonTitle = String(localized: "Next")
    let onFinish: () -> Void

    private static let total = 600

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var plain = OnboardingDemoTimer(totalSeconds: total, alerts: [], demoSeconds: 2.5)
    @StateObject private var alerted = OnboardingDemoTimer(totalSeconds: total, alerts: [300, 60], demoSeconds: 5.5)

    /// 첫 장면의 원은 비어 있다가 차오른다. 찬 길을 거꾸로 줄어드는 것을 바로 이어서 본다.
    @State private var ringFill: CGFloat = 0
    @State private var caption = ""
    @State private var showCaption = false
    @State private var showBells = false
    @State private var finished = false
    /// 앞 장면이 끝나 사람이 "다음"을 누르길 기다리는 중
    @State private var awaitingNext = false
    @State private var secondScene: Task<Void, Never>?

    private var captions: [String] {
        [String(localized: "Most timers only ring at the end"),
         String(localized: "By then, it's already too late"),
         String(localized: "This one tells you before the end"),
         String(localized: "So you can finish on time")]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: DSSpacing.xxl) {
                    Text(caption)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .opacity(showCaption ? 1 : 0)
                        .offset(y: showCaption ? 0 : 8)
                        .frame(minHeight: 96)
                    stage
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(captions.joined(separator: " "))
                Spacer()
                startButton
            }
            .padding(.horizontal, DSSpacing.xl)
            .padding(.bottom, DSSpacing.xxl)

            if !finished {
                Button(action: skip) {
                    Text("Skip")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(DSSpacing.xl)
            }
        }
        .task { await run() }
        .onDisappear {
            secondScene?.cancel()
            plain.stop()
            alerted.stop()
        }
    }

    private var stage: some View {
        // 같은 자리의 같은 원이다. 뷰를 갈아 끼우면 두 원이 겹쳐 녹으면서 깨져 보인다.
        DemoStage(demo: showBells ? alerted : plain, fill: ringFill)
            .frame(height: 300)
    }

    private var isButtonShown: Bool { awaitingNext || finished }

    private var startButton: some View {
        Button(action: awaitingNext ? showSecondScene : complete) {
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

    private func run() async {
        guard !reduceMotion else {
            caption = captions[2]
            showCaption = true
            ringFill = 1
            showBells = true
            finished = true
            return
        }
        await wait(300)
        withAnimation(.linear(duration: 0.8)) { ringFill = 1 }
        await wait(800)
        await say(captions[0])
        await wait(700)
        plain.start()
        await wait(2_700)
        await say(captions[1])
        await wait(600)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.35)) { awaitingNext = true }
    }

    private func showSecondScene() {
        withAnimation(.easeOut(duration: 0.2)) { awaitingNext = false }
        secondScene = Task { await runSecondScene() }
    }

    private func runSecondScene() async {
        await say(captions[2])
        showBells = true
        await wait(500)
        alerted.start()
        await wait(5_700)
        await say(captions[3])
        await wait(900)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.35)) { finished = true }
    }

    private func skip() {
        onFinish()
    }

    private func complete() {
        onFinish()
    }
}
