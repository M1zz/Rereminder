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

    private enum Mode: Hashable { case total, intervals }
    @State private var detent: PresentationDetent = .medium

    private struct Interval: Identifiable, Equatable {
        let id = UUID()
        var seconds: Int
    }

    init(screenVM: TimerScreenViewModel, isPresented: Binding<Bool>) {
        self.screenVM = screenVM
        self._isPresented = isPresented
        // ⚠️ 목록에 없는 값으로 시작하면 휠이 아무 반응도 하지 않는다 — 범위 안으로 맞춰서 연다
        let current = TimeMapper.clampedInput(minutes: screenVM.mainMinutes, seconds: screenVM.mainSeconds)
        self._inputMinutes = State(initialValue: current.minutes)
        self._inputSeconds = State(initialValue: current.seconds)
        let lengths = IntervalList.lengths(total: screenVM.mainMinutes * 60 + screenVM.mainSeconds,
                                           offsets: screenVM.selectedOffsets)
        self._intervals = State(initialValue: lengths.map { Interval(seconds: $0) })
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
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 140)
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
                        .pickerStyle(.wheel)
                        .frame(width: 100, height: 140)
                        .accessibilityLabel(String(localized: "Seconds"))
                        .accessibilityValue(String(localized: "\(inputSeconds) seconds"))
                    }
                }

                Button(action: {
                    // 상한(120:00)을 넘는 조합은 다이얼이 조용히 잘라 버리므로 여기서 맞춰 준다.
                    // 아래쪽(켜 둔 알림보다 짧게)은 setMainSeconds 가 막고 이유를 알려준다.
                    // 두 칸은 같은 설정이다 — 구간 칸에서 고친 것이 있으면 그것까지 함께 올린다
                    if let setup = intervalSetup, intervals.count > 1 {
                        screenVM.applyRepeatConfig(mainSec: setup.total, offsets: Array(setup.offsets), toast: false)
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
            List {
                ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                    intervalRow(index: index, interval: interval)
                }
                .onDelete { intervals.remove(atOffsets: $0) }

                Button {
                    // 같은 길이를 되풀이하는 경우가 많다(5분씩 네 번). 마지막 길이를 그대로 하나 더.
                    intervals.append(Interval(seconds: intervals.last?.seconds ?? 300))
                } label: {
                    Label("Add interval", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .disabled(intervalTotal >= TimeMapper.maxSeconds)
            }
            .listStyle(.insetGrouped)

            VStack(spacing: DSSpacing.xs) {
                Text("Total: \(TimeMapper.clockText(intervalTotal))")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
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
            .padding(.horizontal)

            Button {
                guard let setup = intervalSetup else { return }
                screenVM.applyRepeatConfig(mainSec: setup.total, offsets: Array(setup.offsets), toast: false)
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

    private func intervalRow(index: Int, interval: Interval) -> some View {
        let binding = Binding<Int>(
            get: { intervals.first { $0.id == interval.id }?.seconds ?? interval.seconds },
            set: { newValue in
                if let i = intervals.firstIndex(where: { $0.id == interval.id }) { intervals[i].seconds = newValue }
            }
        )
        return HStack(spacing: DSSpacing.md) {
            Circle()
                .fill(SectionPalette.color(index))
                .frame(width: 12, height: 12)
            Text("Interval \(index + 1)")
                .font(.body)
            Spacer(minLength: DSSpacing.sm)
            Picker(selection: Binding(get: { binding.wrappedValue / 60 },
                                      set: { binding.wrappedValue = $0 * 60 + binding.wrappedValue % 60 })) {
                ForEach(0...TimeMapper.maxMinutes, id: \.self) { Text("\($0) min").tag($0) }
            } label: {
                Text("Minutes")
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Picker(selection: Binding(get: { binding.wrappedValue % 60 },
                                      set: { binding.wrappedValue = binding.wrappedValue / 60 * 60 + $0 })) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) sec").tag($0) }
            } label: {
                Text("Seconds")
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .accessibilityElement(children: .contain)
    }
}
