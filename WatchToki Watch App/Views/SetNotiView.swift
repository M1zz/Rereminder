//
//  SetNotiView.swift
//  Toki
//
//  Created by 내꺼다 on 8/7/25.
//

import SwiftUI
import UserNotifications

struct SetNotiView: View {
    @ObservedObject var viewModel: SetNotiViewModel

    @Binding var path: [NavigationTarget]

    @State private var showingCustomSheet = false
    @State private var customMinutes = 1
    @State private var customPresets: [Int] = []

    var body: some View {
        let maxMinute = viewModel.maxSelectableTimeModel.minute

        VStack(spacing: 16) {
            // 타이틀
            Text("Pre-alerts", comment: "Pre-alerts")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            presetButtons(maxMinute: maxMinute)

            startButton
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .background(.clear)
        .sheet(isPresented: $showingCustomSheet) { customMinutesSheet(maxMinute: maxMinute) }
    }

    // MARK: - Subviews

    private var selectedMinutesText: String {
        let sorted = viewModel.selectedMinutes.sorted()
        let minText = String(localized: "min")
        let alertText = String(localized: "min before alert")
        if sorted.count == 1 {
            return "\(sorted[0]) \(alertText)"
        } else {
            let text = sorted.map { "\($0) \(minText)" }.joined(separator: ", ")
            return "\(text) \(String(localized: "before alert"))"
        }
    }

    private func presetButtons(maxMinute: Int) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        // iOS와 동일한 프리셋: 1, 3, 5, 10, 15, 30min
        let defaultPresets = [1, 3, 5, 10, 15, 30]
        return LazyVGrid(columns: columns, alignment: .center, spacing: 8) {
            ForEach(defaultPresets.filter { $0 <= maxMinute }, id: \.self) { minute in
                presetCircle(title: "\(minute)", minutes: minute, maxMinute: maxMinute)
            }
            ForEach(customPresets, id: \.self) { minute in
                presetCircle(title: "\(minute)", minutes: minute, maxMinute: maxMinute)
            }
            Button {
                if maxMinute >= 1 {
                    customMinutes = min(max(1, customMinutes), maxMinute)
                    showingCustomSheet = true
                }
            } label: {
                CircleButton(title: "+", subtitle: "", isSelected: false, isDisabled: maxMinute < 1, action: {})
                    .contentShape(Circle())
            }
            .disabled(maxMinute < 1)
            .opacity(maxMinute < 1 ? 0.4 : 1.0)
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
        .background(Color.clear)
    }

    private var startButton: some View {
        Button {
            guard !viewModel.selectedMinutes.isEmpty else { return }
            requestNotificationPermissionIfNeeded { _ in
                // 모든 선택된 알림 스케줄
                for minute in viewModel.selectedMinutes {
                    let seconds = TimeInterval(minute * 60)
                    schedulePreFinishNotification(after: seconds, minutes: minute)
                }
            }
            // selectedMinutes를 배열로 변환해서 전달
            let prealertOffsets = Array(viewModel.selectedMinutes)
            path.append(.timerViewMultiple(mainDuration: viewModel.maxTimeInSeconds, prealertOffsets: prealertOffsets))
        } label: {
            Text("Start Timer", comment: "Start Timer")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .disabled(viewModel.selectedMinutes.isEmpty)
    }

    private func presetCircle(title: String, minutes: Int, maxMinute: Int) -> some View {
        let disabled = maxMinute < minutes
        let isSelected = viewModel.selectedMinutes.contains(minutes)

        return Button {
            guard !disabled else { return }
            if isSelected {
                viewModel.selectedMinutes.remove(minutes)
            } else {
                viewModel.selectedMinutes.insert(minutes)
            }
        } label: {
            CircleButton(title: title, subtitle: "m", isSelected: isSelected, isDisabled: disabled) {
                // handled by outer Button
            }
            .contentShape(Circle())
        }
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
        .buttonStyle(.plain)
    }

    private func customMinutesSheet(maxMinute: Int) -> some View {
        VStack(spacing: 8) {
            Text("Custom Minutes", comment: "Custom Minutes")
                .font(.headline)

            Picker("", selection: $customMinutes) {
                ForEach(1...max(1, maxMinute), id: \.self) { minute in
                    Text("\(minute) \(String(localized: "min"))").tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 110)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showingCustomSheet = false
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)

                Button("Done") {
                    let clamped = min(max(1, customMinutes), maxMinute)
                    viewModel.selectedMinutes.insert(clamped)
                    let defaultPresets = [1, 3, 5, 10, 15, 30]
                    if !defaultPresets.contains(clamped) && !customPresets.contains(clamped) {
                        customPresets.append(clamped)
                        customPresets.sort()
                    }
                    showingCustomSheet = false
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)

            }
        }
        .padding(8)
        .presentationDetents([.height(220)])
    }
}

// MARK: - Circle Button View
private struct CircleButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 9, weight: .medium))
            }
        }
        .frame(width: 46, height: 46)
        .background(
            Circle()
                .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.12))
        )
        .overlay(
            Circle()
                .stroke(isSelected ? Color.accentColor.opacity(0.9) : Color.gray.opacity(0.35), lineWidth: 0.75)
        )
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .clipShape(Circle())
        .opacity(isDisabled ? 0.4 : 1.0)
    }
}

private struct SettingPrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background((isEnabled ? Color.accentColor : Color.gray.opacity(0.3)).opacity(configuration.isPressed ? 0.8 : 1.0))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Notification helpers
private func requestNotificationPermissionIfNeeded(completion: @escaping (Bool) -> Void) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            completion(true)
        case .denied:
            completion(false)
        case .notDetermined:
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }
}

private func schedulePreFinishNotification(after seconds: TimeInterval, minutes: Int) {
    let content = UNMutableNotificationContent()
    content.title = String(localized: "Toki Timer")
    content.body = String(localized: "\(minutes) min remaining")
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
    let request = UNNotificationRequest(
        identifier: "prealert-\(minutes)",
        content: content,
        trigger: trigger
    )

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Failed to schedule notification: \(error)")
        }
    }
}
