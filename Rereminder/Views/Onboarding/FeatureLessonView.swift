//
//  FeatureLessonView.swift
//  Rereminder
//
//  **기능 수업.** 그 기능을 처음 쓸 때 한 번, 가이드북에서는 언제든. 하얀 화면에서 직접 눌러 본다.
//
//  ⚠️ 전부 장난감이다. 진짜 타이머·템플릿·구간을 건드리지 않는다.
//  ⚠️ 언제 뜨는지는 `TimerUnifiedView.presentLessonIfDue` 한 곳에서 정한다. 새로 설치한 사람에게만 저절로 뜬다.
//

import SwiftUI

struct FeatureLessonView: View {
    let lesson: FeatureLesson
    let onClose: () -> Void

    @State private var line = ""
    @State private var isDone = false

    var body: some View {
        LessonShell(line: line, isDone: isDone, doneTitle: String(localized: "Got it"),
                    onDone: onClose, onSkip: onClose) {
            VStack(spacing: DSSpacing.lg) {
                Label(lesson.title, systemImage: lesson.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                switch lesson {
                case .moreAlerts: MoreAlertsStage(line: $line, isDone: $isDone)
                case .templates: TemplatesStage(line: $line, isDone: $isDone)
                case .session: SessionStage(line: $line, isDone: $isDone)
                case .overtime: OvertimeStage(line: $line, isDone: $isDone)
                }
            }
        }
    }
}

// MARK: - 알림 더하기

private struct MoreAlertsStage: View {
    @Binding var line: String
    @Binding var isDone: Bool
    @State private var alerts: Set<Int> = [60]

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            OnboardingDemoRing(totalSeconds: 600, alerts: Array(alerts), elapsed: 0, size: 230)
                .transaction { $0.animation = nil }
            HStack(spacing: DSSpacing.md) {
                ForEach([300, 180], id: \.self) { seconds in
                    Button {
                        alerts.insert(seconds)
                        line = String(localized: "Now you hear it more than once before the end")
                        isDone = true
                    } label: {
                        Label(TimeMapper.mmss(seconds), systemImage: "bell.fill")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(alerts.contains(seconds) ? DSColor.marker : Color.accentColor)
                }
            }
        }
        .onAppear { line = String(localized: "Tap a button to add an alert") }
    }
}

// MARK: - 저장하고 불러오기

private struct TemplatesStage: View {
    @Binding var line: String
    @Binding var isDone: Bool
    @State private var isSaved = false
    @State private var isLoaded = true

    private var seconds: Int { isLoaded ? 1500 : 600 }
    private var alerts: [Int] { isLoaded ? [300, 60] : [60] }

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            OnboardingDemoRing(totalSeconds: seconds, alerts: alerts, elapsed: 0, size: 230)
                .transaction { $0.animation = nil }
            if isSaved {
                Button {
                    withAnimation { isLoaded = true }
                    line = String(localized: "Back in one tap")
                    isDone = true
                } label: {
                    Label(TimeMapper.durationText(1500), systemImage: "bookmark.fill")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .transition(.scale.combined(with: .opacity))
            } else {
                Button {
                    withAnimation {
                        isSaved = true
                        isLoaded = false
                    }
                    line = String(localized: "The dial changed. Tap the button to bring it back")
                } label: {
                    Text("Save").font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { line = String(localized: "Tap Save to keep this setup") }
    }
}

// MARK: - 세션 모드

private struct SessionStage: View {
    @Binding var line: String
    @Binding var isDone: Bool

    @State private var named: Set<Int> = []
    @StateObject private var demo = OnboardingDemoTimer(totalSeconds: 600, alerts: [300, 60], demoSeconds: 6)
    @State private var isRunning = false

    private var names: [String] {
        [String(localized: "Opening"), String(localized: "Main"), String(localized: "Closing")]
    }

    var body: some View {
        // 원과 목록 사이는 넉넉히 — 6시의 종이 원 밖으로 나와 첫 줄에 얹혀 보였다.
        VStack(spacing: DSSpacing.xxl) {
            DemoStage(demo: demo, size: 170) {
                line = String(localized: "You can also write a script for each part")
                isDone = true
            }
            SessionRows(demo: demo, names: names, named: named, isRunning: isRunning) { index in
                named.insert(index)
                if named.count == names.count {
                    line = String(localized: "Press start when the parts are named")
                }
            }
            .padding(.top, DSSpacing.lg)
            if named.count == names.count, !isRunning {
                LessonPlayButton {
                    isRunning = true
                    line = String(localized: "Each part shows its name as time runs")
                    demo.start()
                }
            }
        }
        .onAppear { line = String(localized: "Tap each part to name it") }
    }
}

private struct SessionRows: View {
    @ObservedObject var demo: OnboardingDemoTimer
    let names: [String]
    let named: Set<Int>
    let isRunning: Bool
    let onName: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    /// 다음에 누를 줄. 무엇을 눌러야 하는지 보이게 이 줄만 테두리가 숨 쉰다.
    private var nextToName: Int? {
        guard !isRunning else { return nil }
        return names.indices.first { !named.contains($0) }
    }

    private var current: Int? {
        guard isRunning else { return nil }
        return TimerSections.progress(mainSeconds: demo.totalSeconds, alertOffsets: Set(demo.alerts),
                                      elapsedSec: Int(demo.elapsed))?.index
    }

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            ForEach(Array(names.enumerated()), id: \.offset) { index, name in
                Button {
                    onName(index)
                } label: {
                    HStack(spacing: DSSpacing.md) {
                        Circle()
                            .fill(SectionPalette.color(index))
                            .frame(width: 12, height: 12)
                        Text(named.contains(index) ? name : "\(index + 1)")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        if !named.contains(index) {
                            Image(systemName: "pencil")
                                .foregroundStyle(SectionPalette.color(index))
                        }
                    }
                    .padding(DSSpacing.md)
                    .background(RoundedRectangle(cornerRadius: DSRadius.md)
                        .fill(current == index ? SectionPalette.color(index).opacity(0.25) : Color(.systemGray6)))
                    .overlay {
                        if nextToName == index {
                            RoundedRectangle(cornerRadius: DSRadius.md)
                                .strokeBorder(SectionPalette.color(index), lineWidth: 2)
                                .opacity(reduceMotion ? 1 : (pulse ? 1 : 0.25))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

// MARK: - 오버타임

private struct OvertimeStage: View {
    @Binding var line: String
    @Binding var isDone: Bool

    @StateObject private var demo = OnboardingDemoTimer(totalSeconds: 600, alerts: [], demoSeconds: 3)
    @State private var isRunning = false
    @State private var over = 0

    var body: some View {
        VStack(spacing: DSSpacing.xl) {
            DemoStage(demo: demo, size: 230) {
                line = String(localized: "It keeps counting how far you went over")
                Task { await countOver() }
            }
            if over > 0 {
                Text(verbatim: "+\(TimeMapper.mmss(over))")
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .foregroundStyle(DSColor.negativeSoft)
            } else if !isRunning {
                LessonPlayButton {
                    isRunning = true
                    demo.start()
                }
            }
        }
        .onAppear { line = String(localized: "Press start and let it run out") }
    }

    private func countOver() async {
        for _ in 0..<3 {
            try? await Task.sleep(for: .seconds(1))
            over += 1
        }
        isDone = true
    }
}
