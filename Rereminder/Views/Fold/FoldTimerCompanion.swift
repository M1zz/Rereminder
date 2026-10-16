//
//  FoldTimerCompanion.swift
//  Rereminder
//
//  펼친 아이폰 듀오의 **결과 쪽 판** — 다이얼(고르는 쪽)이 정한 것을 크게 보여 준다.
//
//  - 대기 중: **계획.** 구간마다 시작 → 끝 시각, 길이, 그 사이 종마다 실제로 나갈 알림 문구.
//    종을 각도로 옮기는 다이얼은 "그래서 첫 구간이 몇 분이지?"에 답하지 못한다. 접혀 있을 때는
//    원 아래 칩 한 줄(`SectionLengthBar`)이 그 답이었는데, 펴면 판 하나를 통째로 준다.
//    세션 모드면 구간을 눌러 **그 자리에서 대본을 쓴다**(접혀 있을 때의 `SectionScriptSheet` 대신).
//  - 실행 중: **멀리서 읽는 남은 시간.** 반쯤 접어 발표대에 세워 두면 이 판이 선다.
//    지금 구간 이름 · 다음 알림 · 구간별 카운트다운(`SectionCountdownList`)이 함께 선다.
//
//  ⚠️ 계산은 하지 않는다 — 구간은 `TimerSections`, 알림 문구는 `Timer.prealertMessage` 하나만 본다.
//     다이얼·링·이 판이 다른 계산을 하면 보이는 구간과 울리는 구간이 갈라진다.
//  ⚠️ 이 판이 서 있는 동안 다이얼 쪽은 같은 것(구간 칩·카운트다운)을 그리지 않는다(`TimerMainView`).
//

import SwiftUI

struct FoldTimerCompanion: View {
    @EnvironmentObject private var screenVM: TimerScreenViewModel

    /// 대본을 펼쳐 쓰는 중인 구간. 세션 모드 대기 중에만.
    @State private var editingScript: Int?
    @FocusState private var scriptFocused: Bool

    private var isProgressMode: Bool {
        screenVM.state == .running || screenVM.state == .paused || screenVM.state == .overtime
    }

    private var isSessionMode: Bool { screenVM.currentMode == .presentation }

    private var mainSeconds: Int {
        isProgressMode ? screenVM.configuredMainSeconds : screenVM.mainMinutes * 60 + screenVM.mainSeconds
    }

    private var segments: [TimerSections.Segment] {
        TimerSections.derive(mainSeconds: mainSeconds, alertOffsets: screenVM.selectedOffsets)
    }

    private var elapsedSec: Int {
        max(0, screenVM.configuredMainSeconds - Int(screenVM.remaining.rounded()))
    }

    var body: some View {
        Group {
            if isProgressMode {
                runningBoard
            } else {
                plan
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.3), value: isProgressMode)
        .onChange(of: isProgressMode) { _, running in
            if running { editingScript = nil }
        }
    }

    // MARK: - 대기: 계획

    private var plan: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your plan")
                        .font(Font.title2.weight(.bold))
                    Spacer()
                    HStack(spacing: DSSpacing.xs) {
                        Text(verbatim: TimeMapper.mmss(mainSeconds))
                            .monospacedDigit()
                        if !screenVM.selectedOffsets.isEmpty {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(DSColor.marker)
                                .accessibilityHidden(true)
                            Text(verbatim: "\(screenVM.selectedOffsets.count)")
                        }
                    }
                    .font(DSFont.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                if segments.count > 1 {
                    proportionBar
                }

                VStack(spacing: DSSpacing.sm) {
                    ForEach(segments) { segment in
                        segmentRow(segment)
                        if segment.index < segments.count - 1 {
                            alertRow(offset: mainSeconds - segment.endSec)
                        }
                    }
                    endRow
                }
            }
            .padding(DSSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    /// 구간 길이를 폭으로 — 20분과 1분이 눈으로 20:1 로 보인다.
    private var proportionBar: some View {
        GeometryReader { proxy in
            let total = CGFloat(max(1, mainSeconds))
            HStack(spacing: 3) {
                ForEach(segments) { segment in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(SectionPalette.color(segment.index))
                        .frame(width: max(4, proxy.size.width * CGFloat(segment.durationSec) / total - 3))
                }
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }

    private func segmentRow(_ segment: TimerSections.Segment) -> some View {
        let color = SectionPalette.color(segment.index)
        let isEditing = editingScript == segment.index
        let script = (screenVM.sectionScripts[segment.index] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.md) {
                Circle()
                    .strokeBorder(color, lineWidth: 3)
                    .frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(sectionName(segment.index))
                        .font(DSFont.body.weight(.semibold))
                        .lineLimit(1)
                    Text(verbatim: "\(TimeMapper.mmss(segment.startSec)) → \(TimeMapper.mmss(segment.endSec))")
                        .font(DSFont.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DSSpacing.sm)
                Text(verbatim: TimeMapper.mmss(segment.durationSec))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }

            if isSessionMode {
                if isEditing {
                    scriptEditor(segment.index)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { editingScript = segment.index }
                        scriptFocused = true
                    } label: {
                        Text(script.isEmpty ? String(localized: "Add script") : script)
                            .font(DSFont.callout)
                            .foregroundStyle(script.isEmpty ? Color.accentColor : .secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16 + DSSpacing.md)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(isEditing ? color : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }

    private func scriptEditor(_ index: Int) -> some View {
        let binding = Binding<String>(
            get: { screenVM.sectionScripts[index] ?? "" },
            set: { screenVM.sectionScripts[index] = $0 }
        )
        return VStack(alignment: .trailing, spacing: DSSpacing.xs) {
            TextEditor(text: binding)
                .focused($scriptFocused)
                .font(DSFont.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(DSSpacing.xs)
                .background(RoundedRectangle(cornerRadius: DSRadius.sm).fill(Color(.tertiarySystemBackground)))
                .overlay(alignment: .topLeading) {
                    if binding.wrappedValue.isEmpty {
                        Text("What will you say in this section?")
                            .font(DSFont.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DSSpacing.xs + 5)
                            .padding(.top, DSSpacing.xs + 8)
                            .allowsHitTesting(false)
                    }
                }
            Button("Done") {
                scriptFocused = false
                withAnimation(.easeInOut(duration: 0.2)) { editingScript = nil }
            }
            .font(DSFont.callout.weight(.semibold))
        }
    }

    /// 구간 사이의 종 — 그 순간 실제로 나갈 문구를 미리 보여 준다.
    private func alertRow(offset: Int) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "bell.fill")
                .foregroundStyle(DSColor.marker)
                .accessibilityHidden(true)
            Text(verbatim: TimeMapper.mmss(offset))
                .font(DSFont.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(DSColor.marker)
            Text(verbatim: "“\(Timer.prealertMessage(for: offset, custom: screenVM.prealertMessages))”")
                .font(DSFont.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.md)
    }

    private var endRow: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "flag.checkered")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("End")
                .font(DSFont.callout.weight(.semibold))
            Text(verbatim: "“\(Timer.finishMessage(custom: screenVM.finishMessage))”")
                .font(DSFont.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.md)
    }

    // MARK: - 실행: 멀리서 읽는 남은 시간

    private var progress: TimerSections.Progress? {
        TimerSections.progress(mainSeconds: screenVM.configuredMainSeconds,
                               alertOffsets: screenVM.selectedOffsets,
                               elapsedSec: elapsedSec)
    }

    private var runningBoard: some View {
        let current = progress
        let tint = current.map { SectionPalette.color($0.index) } ?? DSColor.marker

        return VStack(spacing: DSSpacing.md) {
            HStack(spacing: DSSpacing.sm) {
                if let current, current.isDivided || isSessionMode {
                    Circle().fill(tint).frame(width: 12, height: 12)
                    Text(sectionName(current.index))
                        .font(Font.title3.weight(.bold))
                        .lineLimit(1)
                } else if screenVM.state == .overtime {
                    Text("Overtime")
                        .font(Font.title3.weight(.bold))
                        .foregroundStyle(DSColor.marker)
                }
                Spacer(minLength: DSSpacing.sm)
                if screenVM.state == .paused {
                    Text("Paused")
                        .font(DSFont.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else if let current, current.isDivided {
                    Text("Next: \(TimeMapper.mmss(current.remainingSec))")
                        .font(DSFont.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(DSColor.marker)
                }
            }

            Spacer(minLength: 0)

            // 판 폭을 다 쓰는 숫자 — 발표대 위에서 한 걸음 떨어져도 읽혀야 한다.
            Text(verbatim: screenVM.timeString(from: screenVM.timerVM.remaining))
                .font(.system(size: 400, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.05)
                .lineLimit(1)
                .foregroundStyle(screenVM.state == .overtime ? DSColor.marker : .primary)
                .opacity(screenVM.state == .paused ? 0.5 : 1)
                .accessibilityAddTraits(.updatesFrequently)

            Spacer(minLength: 0)

            if segments.count > 1 {
                SectionCountdownList(segments: segments, elapsedSec: elapsedSec, maxHeight: 180)
            }
        }
        .padding(DSSpacing.xl)
        // 구간이 바뀌면 판 바탕이 그 구간 색으로 물든다 — 멀리서도 넘어간 것을 안다.
        .background(tint.opacity(0.12).ignoresSafeArea())
        .animation(.easeInOut(duration: 0.6), value: current?.index)
    }

    // MARK: - 이름

    private func sectionName(_ index: Int) -> String {
        let custom = (screenVM.sectionNames[index] ?? "").trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? String(localized: "Section \(index + 1)") : custom
    }
}
