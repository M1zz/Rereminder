//
//  TimeInputSheet.swift
//  Rereminder
//
//  Created for usability improvements
//

import SwiftUI

struct TimeInputSheet: View {
    @ObservedObject var screenVM: TimerScreenViewModel
    @Binding var isPresented: Bool

    @State private var inputMinutes: Int
    @State private var inputSeconds: Int

    init(screenVM: TimerScreenViewModel, isPresented: Binding<Bool>) {
        self.screenVM = screenVM
        self._isPresented = isPresented
        // ⚠️ 목록에 없는 값으로 시작하면 휠이 아무 반응도 하지 않는다 — 범위 안으로 맞춰서 연다
        let current = TimeMapper.clampedInput(minutes: screenVM.mainMinutes, seconds: screenVM.mainSeconds)
        self._inputMinutes = State(initialValue: current.minutes)
        self._inputSeconds = State(initialValue: current.seconds)
    }

    var body: some View {
        NavigationView {
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
                        .frame(width: 100)
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
                        .frame(width: 100)
                        .accessibilityLabel(String(localized: "Seconds"))
                        .accessibilityValue(String(localized: "\(inputSeconds) seconds"))
                    }
                }

                Button(action: {
                    // 상한(120:00)을 넘는 조합은 다이얼이 조용히 잘라 버리므로 여기서 맞춰 준다
                    let applied = TimeMapper.clampedInput(minutes: inputMinutes, seconds: inputSeconds)
                    screenVM.mainMinutes = applied.minutes
                    screenVM.mainSeconds = applied.seconds
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
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
