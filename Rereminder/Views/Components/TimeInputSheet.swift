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
            VStack(spacing: 24) {
                Text("Enter Time Manually")
                    .font(.headline)

                HStack(spacing: 16) {
                    // min 입력
                    VStack {
                        Text("min")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("min", selection: $inputMinutes) {
                            ForEach(0..<61) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }

                    Text(":")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    // sec 입력
                    VStack {
                        Text("sec")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("sec", selection: $inputSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }
                }

                Button(action: {
                    screenVM.mainMinutes = inputMinutes
                    screenVM.mainSeconds = inputSeconds
                    isPresented = false
                }) {
                    Text("Apply")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
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
