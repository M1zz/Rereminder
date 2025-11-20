//
//  TimeInputSheet.swift
//  Toki
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
                Text("시간 직접 입력")
                    .font(.headline)

                HStack(spacing: 16) {
                    // 분 입력
                    VStack {
                        Text("분")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("분", selection: $inputMinutes) {
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

                    // 초 입력
                    VStack {
                        Text("초")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Picker("초", selection: $inputSeconds) {
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
                    Text("적용")
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
                    Button("취소") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
