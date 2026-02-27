//
//  SettingView.swift
//  Rereminder
//
//  Created by 내꺼다 on 8/6/25.
//

import SwiftUI

enum NavigationTarget: Hashable {
    case setNotiView
    case timerView(mainDuration: Int, NotificationDuration: Int)
    case timerViewMultiple(mainDuration: Int, prealertOffsets: [Int])
}

struct SettingView: View {
    @StateObject private var settingViewModel = SettingViewModel()
    @State private var path: [NavigationTarget] = []
    @State private var isNavigating = false

    var totalTime: Int {
        settingViewModel.time.convertedSecond
    }

    private var minuteRange: ClosedRange<Int> { 1...60 }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 16) {
                // 타이틀
                Text("Timer Duration", comment: "Timer Duration")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                TimePicker()

                Spacer()

                NextButton()
                    .buttonStyle(.borderedProminent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
            }
            .onAppear {
                if !(minuteRange.contains(settingViewModel.time.minute)) || settingViewModel.time.minute == 0 {
                    settingViewModel.time.minute = 30
                }
            }
            .navigationDestination(for: NavigationTarget.self) { target in
                destination(for: target)
            }
        }
    }
    
    @ViewBuilder
    private func TimePicker() -> some View {
        HStack(alignment: .center, spacing: 8) {
            MinuteWheel(selectedMinute: $settingViewModel.time.minute, range: minuteRange, selectionOffset: 0)
                .frame(width: 90, height: 90)
            
            Text("min", comment: "min")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .accessibilityHidden(true)
        }
    }
    
    @ViewBuilder
    private func NextButton() -> some View {
        Button {
            isNavigating = true
            // 짧은 지연 후 네비게이션 (로딩 표시용)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                path.append(.setNotiView)
                isNavigating = false
            }
        } label: {
            if isNavigating {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Timer Settings", comment: "Timer Settings")
                    .frame(maxWidth: .infinity)
            }
        }
        .disabled(isNavigating)
    }
    
    @ViewBuilder
    private func destination(for target: NavigationTarget) -> some View {
        switch target {
        case .setNotiView:
            SetNotiView(
                viewModel: SetNotiViewModel(maxTimeInSeconds: totalTime),
                path: $path
            )
        case .timerView(let mainDuration, let notificationDuration):
            TimerView(
                timerViewModel: TimerViewModel(
                    mainDuration: mainDuration,
                    notificationDuration: notificationDuration
                ),
                path: $path
            )
        case .timerViewMultiple(let mainDuration, let prealertOffsets):
            TimerView(
                timerViewModel: TimerViewModel(
                    mainDuration: mainDuration,
                    prealertOffsets: prealertOffsets
                ),
                path: $path
            )
        }
    }
    
    private struct MinuteWheel: View {
        @Binding var selectedMinute: Int
        let range: ClosedRange<Int>
        let selectionOffset: CGFloat

        @State private var scrollID: Int?

        private let rowHeight: CGFloat = 45

        var body: some View {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(range), id: \.self) { minute in
                        MinuteRow(minute: minute, isSelected: minute == selectedMinute)
                            .frame(height: rowHeight)
                            .id(minute)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollTargetLayout()
            .contentMargins(.vertical, (90 - rowHeight) / 2, for: .scrollContent)
            .contentMargins(.vertical, selectionOffset, for: .scrollContent)
            .scrollPosition(id: $scrollID)
            .onChange(of: scrollID) { _, newID in
                if let m = newID, selectedMinute != m {
                    selectedMinute = m
                }
            }
            .onChange(of: selectedMinute) { _, newValue in
                if scrollID != newValue {
                    scrollID = newValue
                }
            }
            .sensoryFeedback(.alignment, trigger: selectedMinute)
            .onAppear {
                if !range.contains(selectedMinute) {
                    selectedMinute = range.lowerBound
                }
                scrollID = selectedMinute
            }
            .frame(width: 90, height: 90)
            .clipped()
            .contentShape(Rectangle())
        }
    }

    private struct MinuteRow: View {
        let minute: Int
        let isSelected: Bool

        var body: some View {
            Text("\(minute)")
                .font(.system(size: isSelected ? 40 : 34, weight: isSelected ? .semibold : .regular, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white : Color.gray.opacity(0.5))
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
    }
}

#Preview {
    SettingView()
}
