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
    
    @State private var selectedMinutes: Int?
    @State private var showingCustomSheet = false
    @State private var customMinutes = 1
    @State private var customPresets: [Int] = []
    
    var body: some View {
        let maxMinute = viewModel.maxSelectableTimeModel.minute

        VStack(spacing: 16) {
            // 타이틀
            Text("예비 알림")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            presetButtons(maxMinute: maxMinute)

            if let selected = selectedMinutes {
                Text("\(selected)분 전 알림")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            startButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.clear)
        .sheet(isPresented: $showingCustomSheet) { customMinutesSheet(maxMinute: maxMinute) }
    }
    
    // MARK: - Subviews
    
    private func presetButtons(maxMinute: Int) -> some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        // iOS와 동일한 프리셋: 1, 3, 5, 10, 15, 30분
        let defaultPresets = [1, 3, 5, 10, 15, 30]
        return LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
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
        .padding(.top, 4)
        .background(Color.clear)
    }
    
    private var selectionHint: some View {
        Group {
            if let selected = selectedMinutes {
                Text("타이머 완료 \(selected)분 전에 알림이 울립니다.")
            } else {
                Text("원하는 알림 시점을 선택하세요.")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    
    private var startButton: some View {
        Button {
            guard let _ = selectedMinutes, viewModel.notiTime.minute > 0 else { return }
            requestNotificationPermissionIfNeeded { _ in
                schedulePreFinishNotification(after: TimeInterval(viewModel.notiTime.convertedSecond))
            }
            path.append(.timerView(mainDuration: viewModel.maxTimeInSeconds, NotificationDuration: viewModel.notiTime.convertedSecond))
        } label: {
            Text("타이머 시작")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 4)
        .disabled(selectedMinutes == nil)
    }
    
    private func presetCircle(title: String, minutes: Int, maxMinute: Int) -> some View {
        let disabled = maxMinute < minutes
        return Button {
            guard !disabled else { return }
            selectedMinutes = minutes
            viewModel.notiTime.minute = minutes
        } label: {
            CircleButton(title: title, subtitle: "분", isSelected: selectedMinutes == minutes, isDisabled: disabled) {
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
            Text("사용자 지정 분")
                .font(.headline)

            Picker("", selection: $customMinutes) {
                ForEach(1...max(1, maxMinute), id: \.self) { minute in
                    Text("\(minute)분").tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 110)

            HStack(spacing: 12) {
                Button("취소") {
                    showingCustomSheet = false
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .buttonStyle(.plain)

                Button("완료") {
                    let clamped = min(max(1, customMinutes), maxMinute)
                    selectedMinutes = clamped
                    viewModel.notiTime.minute = clamped
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
        VStack(spacing: 2) {
            Text(title)
                .font(.headline).bold()
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption2)
            }
        }
        .frame(width: 56, height: 56)
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

private func schedulePreFinishNotification(after seconds: TimeInterval) {
    let content = UNMutableNotificationContent()
    content.title = "완료 전 알림"
    if seconds >= 60 {
        let minutes = Int(seconds) / 60
        content.body = "\(minutes)분 뒤에 타이머가 완료됩니다."
    } else {
        content.body = "\(Int(seconds))초 뒤에 타이머가 완료됩니다."
    }
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
    let request = UNNotificationRequest(
        identifier: "preFinish-\(UUID().uuidString)",
        content: content,
        trigger: trigger
    )

    UNUserNotificationCenter.current().add(request) { error in
        if let error = error {
            print("Failed to schedule notification: \(error)")
        }
    }
}
















