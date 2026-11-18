//
//  TimeInputSheet.swift
//  Rereminder
//
//  Created for usability improvements
//
//  가운데 시간을 누르면 열린다. 두 갈래:
//   • 전체 시간 — 휠로 총 시간만.
//   • 구간 목록 — 구간 길이를 위에서부터 적으면 총 시간과 알림이 저절로 선다(`IntervalList`).
//     원에서 종을 각도로 맞추는 대신, 길이를 이미 아는 사람이 숫자로 빠르게 만든다(2026-11-16 제보).
//     길이는 − 5:00 + (1분, 1분 아래는 10초) 와 숫자를 눌러 고르는 자주 쓰는 길이. 세션 모드면 줄마다 구간 이름을 적고,
//     이름·대본은 줄을 따라 다닌다(지우면 뒤 구간의 글이 앞으로 당겨진다).
//

import SwiftUI

struct TimeInputSheet: View {
    @ObservedObject var screenVM: TimerScreenViewModel
    @Binding var isPresented: Bool

    @State private var inputMinutes: Int
    @State private var inputSeconds: Int
    @State private var mode: Mode = .total
    /// 구간 길이(초), 위에서부터 먼저 지나가는 순서
    @State private var intervals: [Interval]
    /// 위 구간들을 몇 번 돌리나 — 운동 1:00 + 휴식 0:30 을 27번(`RoundSchedule`). 세션 모드에는 없다.
    @State private var rounds: Int

    private enum Mode: Hashable { case total, intervals }
    @State private var detent: PresentationDetent = .medium

    /// 구간 하나. 세션 모드의 이름·대본도 함께 들고 다닌다 — 줄을 지우거나 더해도 글이 제 구간을 따라간다.
    private struct Interval: Identifiable, Equatable {
        let id = UUID()
        var seconds: Int
        var name: String = ""
        var script: String = ""
    }

    private var isSession: Bool { screenVM.currentMode == .presentation }

    /// 숫자를 누르면 고르는 자주 쓰는 길이
    private static let presetSeconds = [60, 120, 180, 300, 600, 900, 1200, 1800]

    init(screenVM: TimerScreenViewModel, isPresented: Binding<Bool>) {
        self.screenVM = screenVM
        self._isPresented = isPresented
        // ⚠️ 목록에 없는 값으로 시작하면 휠이 아무 반응도 하지 않는다 — 범위 안으로 맞춰서 연다
        let current = TimeMapper.clampedInput(minutes: screenVM.mainMinutes, seconds: screenVM.mainSeconds)
        self._inputMinutes = State(initialValue: current.minutes)
        self._inputSeconds = State(initialValue: current.seconds)
        self._rounds = State(initialValue: screenVM.rounds)
        let lengths = IntervalList.lengths(total: screenVM.mainMinutes * 60 + screenVM.mainSeconds,
                                           offsets: screenVM.selectedOffsets)
        self._intervals = State(initialValue: lengths.enumerated().map { index, length in
            Interval(seconds: length,
                     name: screenVM.sectionNames[index] ?? "",
                     script: screenVM.sectionScripts[index] ?? "")
        })
        #if DEBUG
        if UserDefaults.standard.string(forKey: "screenshotTimeInput") == "intervals" {
            self._mode = State(initialValue: .intervals)
            self._detent = State(initialValue: .large)
        }
        #endif
    }

    var body: some View {
        NavigationView {
            VStack(spacing: DSSpacing.xl) {
                Picker(selection: $mode) {
                    Text("Total Time").tag(Mode.total)
                    Text("Intervals").tag(Mode.intervals)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch mode {
                case .total: totalPage
                case .intervals: intervalPage
                }
            }
            .padding(.vertical)
            // ⚠️ 두 칸은 **같은 설정**이다. 각자 열 때의 값을 들고 있으면, 구간을 고쳐도 총 시간 휠이 그대로였다.
            //    구간을 바꾸면 총 시간이 그 합으로, 총 시간을 바꾸면 **첫 구간**이 늘거나 준다 —
            //    다이얼에서 총 시간을 바꿀 때와 같다(알림은 끝에서 잰 자리라 그대로고, 앞 구간이 달라진다).
            .onChange(of: intervals.map(\.seconds)) { _, lengths in
                let total = min(TimeMapper.maxSeconds, lengths.reduce(0, +))
                let clamped = TimeMapper.clampedInput(minutes: total / 60, seconds: total % 60)
                if clamped.minutes != inputMinutes { inputMinutes = clamped.minutes }
                if clamped.seconds != inputSeconds { inputSeconds = clamped.seconds }
            }
            .onChange(of: inputMinutes * 60 + inputSeconds) { _, total in
                guard !intervals.isEmpty, total != intervalTotal else { return }
                let rest = intervals.dropFirst().map(\.seconds).reduce(0, +)
                // 첫 구간은 0 이 될 수 없다 — 그보다 줄이면 첫 알림이 사라진다(다이얼도 그렇게 막는다)
                intervals[0].seconds = max(5, total - rest)
            }
            .onChange(of: mode) { _, newMode in
                withAnimation { detent = newMode == .intervals ? .large : .medium }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - 전체 시간

    private var totalPage: some View {
        VStack(spacing: DSSpacing.xxl) {
                Text("Enter Time Manually")
                    .font(DSFont.sectionHeader)
                HStack(spacing: DSSpacing.lg) {
                    // min 입력
                    VStack {
                        Text("min")
                            .font(DSFont.callout)
                            .foregroundStyle(.secondary)
                        Picker("min", selection: $inputMinutes) {
                            // 다이얼과 같은 상한을 본다 (60분으로 굳혀 두면 110분 설정을 못 줄인다)
                            ForEach(0...TimeMapper.maxMinutes, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .numberWheelStyle(height: 140)
                        .accessibilityLabel(String(localized: "Minutes"))
                        .accessibilityValue(String(localized: "\(inputMinutes) minutes"))
                    }

                    Text(":")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    // sec 입력
                    VStack {
                        Text("sec")
                            .font(DSFont.callout)
                            .foregroundStyle(.secondary)
                        Picker("sec", selection: $inputSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .numberWheelStyle(height: 140)
                        .accessibilityLabel(String(localized: "Seconds"))
                        .accessibilityValue(String(localized: "\(inputSeconds) seconds"))
                    }
                }

                Button(action: {
                    // 상한(120:00)을 넘는 조합은 다이얼이 조용히 잘라 버리므로 여기서 맞춰 준다.
                    // 아래쪽(켜 둔 알림보다 짧게)은 setMainSeconds 가 막고 이유를 알려준다.
                    // 두 칸은 같은 설정이다 — 구간 칸에서 고친 것이 있으면 그것까지 함께 올린다
                    screenVM.rounds = isSession ? 1 : rounds
                    if let setup = intervalSetup, intervals.count > 1 {
                        screenVM.applyRepeatConfig(mainSec: setup.total, offsets: Array(setup.offsets), toast: false)
                        if isSession { applySectionText() }
                    } else {
                        let applied = TimeMapper.clampedInput(minutes: inputMinutes, seconds: inputSeconds)
                        screenVM.setMainSeconds(applied.minutes * 60 + applied.seconds)
                    }
                    isPresented = false
                }) {
                    Text("Apply")
                        .font(DSFont.sectionHeader)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(DSRadius.md)
                }
                .padding(.horizontal)
            if rounds > 1, !isSession {
                // 이 칸에는 반복 칸이 없다 — 걸려 있다는 것만 말한다(구간 칸에서 바꾼다)
                Text("Repeats \(rounds) times")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }

    // MARK: - 구간 목록

    private var intervalSetup: (total: Int, offsets: Set<Int>)? {
        IntervalList.setup(from: intervals.map(\.seconds))
    }

    private var intervalTotal: Int { intervals.map(\.seconds).reduce(0, +) }

    private var intervalPage: some View {
        VStack(spacing: DSSpacing.lg) {
            // 합계·안내는 목록 꼬리말이다. 목록 밖에 두면 가로 화면에서 목록이 한 줄로 눌렸다.
            List {
                Section {
                    ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                        intervalRow(index: index, interval: interval)
                    }
                    .onDelete { intervals.remove(atOffsets: $0) }

                    Button {
                        // 같은 길이를 되풀이하는 경우가 많다(5분씩 네 번). 마지막 길이를 그대로 하나 더.
                        withAnimation { intervals.append(Interval(seconds: intervals.last?.seconds ?? 300)) }
                    } label: {
                        Label("Add interval", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    .disabled(intervalTotal >= TimeMapper.maxSeconds)
                } footer: {
                    VStack(spacing: DSSpacing.xs) {
                        Text("Total: \(TimeMapper.clockText(intervalTotal))")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        if intervalTotal > TimeMapper.maxSeconds {
                            Text("Up to \(TimeMapper.maxMinutes) min in total")
                                .font(.body)
                                .foregroundStyle(DSColor.negativeSoft)
                        } else {
                            Text("An alert rings where each interval ends.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, DSSpacing.sm)
                }

                if !isSession {
                    Section {
                        repeatRow
                    } footer: {
                        repeatFooter
                    }
                }
            }
            .listStyle(.insetGrouped)

            Button {
                guard let setup = intervalSetup else { return }
                screenVM.rounds = isSession ? 1 : rounds
                screenVM.applyRepeatConfig(mainSec: setup.total, offsets: Array(setup.offsets), toast: false)
                if isSession { applySectionText() }
                isPresented = false
            } label: {
                Text("Apply")
                    .font(DSFont.sectionHeader)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(intervalSetup == nil ? Color.secondary.opacity(0.4) : Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(DSRadius.md)
            }
            .disabled(intervalSetup == nil)
            .padding(.horizontal)
        }
    }

    // MARK: - 반복

    /// 반복 − 27 + . 1 이면 한 번만 돈다.
    private var repeatRow: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: "repeat")
                .foregroundStyle(.secondary)
            Text("Repeat")
                .font(.body)
            Spacer(minLength: DSSpacing.sm)
            HStack(spacing: 2) {
                stepButton("minus", enabled: rounds > 1) { rounds -= 1 }
                Text(rounds > 1 ? "× \(rounds)" : String(localized: "Once"))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 56)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                stepButton("plus", enabled: rounds < Self.maxRounds) { rounds += 1 }
            }
            .sensoryFeedback(.selection, trigger: rounds)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Repeat"))
        .accessibilityValue(Text(rounds > 1 ? String(localized: "\(rounds) times") : String(localized: "Once")))
        .accessibilityAdjustableAction { direction in
            rounds = min(Self.maxRounds, max(1, rounds + (direction == .increment ? 1 : -1)))
        }
    }

    private static let maxRounds = 99

    /// 다 합친 시간과, 앱을 열지 않으면 몇 회째까지 울리는지.
    @ViewBuilder private var repeatFooter: some View {
        if rounds > 1 {
            VStack(spacing: DSSpacing.xs) {
                Text("All rounds: \(TimeMapper.clockText(intervalTotal * rounds))")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                if let covered = coveredRound {
                    Text("With the app closed, alerts ring through round \(covered). Open the app to keep them going.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, DSSpacing.sm)
        } else {
            Text("Run the whole ring again, e.g. 1:00 work and 0:30 rest, 27 times.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, DSSpacing.sm)
        }
    }

    /// 예약 몫(64개)에 다 들어가지 않으면 앱을 열지 않고 울리는 마지막 회
    private var coveredRound: Int? {
        guard let setup = intervalSetup else { return nil }
        return RoundSchedule.lastCoveredRound(
            roundSeconds: TimeInterval(setup.total), rounds: rounds,
            offsets: setup.offsets.map(TimeInterval.init),
            budget: RoundSchedule.budget(escalationCount:
                EscalationSchedule.offsets(policy: EscalationPolicy.current(), role: .primary).count))
    }

    /// 줄을 옮기거나 지운 뒤에도 이름·대본이 제 구간에 남게 번호를 다시 매겨 적는다.
    private func applySectionText() {
        var names: [Int: String] = [:]
        var scripts: [Int: String] = [:]
        for (index, interval) in intervals.enumerated() {
            let name = interval.name.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { names[index] = name }
            if !interval.script.isEmpty { scripts[index] = interval.script }
        }
        screenVM.sectionNames = names
        screenVM.sectionScripts = scripts
    }

    /// 1분 아래는 10초씩, 그 위는 1분씩 — 짧은 구간도 맞출 수 있고 긴 구간은 몇 번이면 닿는다.
    private static func step(from seconds: Int, up: Bool) -> Int {
        if up { return seconds < 60 ? seconds + 10 : (seconds / 60 + 1) * 60 }
        if seconds <= 60 { return max(10, seconds - 10) }
        return seconds % 60 == 0 ? seconds - 60 : seconds / 60 * 60
    }

    private func intervalRow(index: Int, interval: Interval) -> some View {
        let binding = Binding<Int>(
            get: { intervals.first { $0.id == interval.id }?.seconds ?? interval.seconds },
            set: { newValue in
                if let i = intervals.firstIndex(where: { $0.id == interval.id }) { intervals[i].seconds = newValue }
            }
        )
        let name = Binding<String>(
            get: { intervals.first { $0.id == interval.id }?.name ?? "" },
            set: { newValue in
                if let i = intervals.firstIndex(where: { $0.id == interval.id }) { intervals[i].name = newValue }
            }
        )
        return HStack(spacing: DSSpacing.md) {
            Circle()
                .fill(SectionPalette.color(index))
                .frame(width: 12, height: 12)
            // 세션 모드는 그 자리에서 구간 이름을 적는다. 비워 두면 번호로 남는다.
            if isSession {
                TextField(String(localized: "Interval \(index + 1)"), text: name)
                    .font(.body)
                    .submitLabel(.next)
            } else {
                Text("Interval \(index + 1)")
                    .font(.body)
            }
            Spacer(minLength: DSSpacing.sm)
            lengthStepper(binding, index: index)
        }
        .accessibilityElement(children: .contain)
    }

    /// − 5:00 + . 숫자를 누르면 자주 쓰는 길이를 바로 고른다.
    private func lengthStepper(_ seconds: Binding<Int>, index: Int) -> some View {
        HStack(spacing: 2) {
            stepButton("minus", enabled: seconds.wrappedValue > 10) {
                seconds.wrappedValue = Self.step(from: seconds.wrappedValue, up: false)
            }
            Menu {
                ForEach(Self.presetSeconds, id: \.self) { preset in
                    Button(TimeMapper.durationText(preset)) { seconds.wrappedValue = preset }
                }
            } label: {
                Text(TimeMapper.clockText(seconds.wrappedValue))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 56)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            stepButton("plus", enabled: intervalTotal < TimeMapper.maxSeconds) {
                seconds.wrappedValue = Self.step(from: seconds.wrappedValue, up: true)
            }
        }
        .sensoryFeedback(.selection, trigger: seconds.wrappedValue)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Interval \(index + 1)"))
        .accessibilityValue(Text(TimeMapper.durationText(seconds.wrappedValue)))
        .accessibilityAdjustableAction { direction in
            seconds.wrappedValue = Self.step(from: seconds.wrappedValue, up: direction == .increment)
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .buttonRepeatBehavior(.enabled)
        .disabled(!enabled)
    }
}
