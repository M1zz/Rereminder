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
        self._inputMinutes = State(initialValue: screenVM.mainMinutes)
        self._inputSeconds = State(initialValue: screenVM.mainSeconds)
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
                            ForEach(0..<61) { minute in
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
                    screenVM.mainMinutes = inputMinutes
                    screenVM.mainSeconds = inputSeconds
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
