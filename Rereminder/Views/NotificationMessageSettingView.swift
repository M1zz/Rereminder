//
//  NotificationMessageSettingView.swift
//  Rereminder
//
//  Created for custom notification messages
//

import SwiftUI

struct NotificationMessageSettingView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Each alert can carry its own message. When that moment arrives, this is the text you see in the notification and on screen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // 발표 모드와 겹치는 지점 — 모르고 쓰면 "적었는데 왜 다른 게 뜨지"가 된다.
                    Text("In Session mode these messages are written for you from the section names, so what you type here is replaced.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(firingOffsets, id: \.self) { offset in
                        prealertMessageEditor(for: offset)
                    }

                    if firingOffsets.isEmpty {
                        Text("No pre-alerts set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Pre-alert Message")
                } footer: {
                    Text("Listed in the order they will ring. Alerts longer than the timer itself never ring, so they aren't shown here.")
                }

                Section(header: Text("End Alert Message")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Timer finished", text: $screenVM.finishMessage)
                            .textFieldStyle(.roundedBorder)

                        Text("Leave empty to use default message: \"Timer finished\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(action: resetAllMessages) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Messages")
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Notification Message Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// 지금 타이머 길이 안에 있어서 **실제로 울리는** 알림만, 울리는 순서(먼 것 → 가까운 것)로.
    ///
    /// ⚠️ 켜 둔 알림을 전부 보여주면 안 된다. 타이머보다 긴 알림(예전 설정이나 템플릿에서 남은 것)은
    ///    울리지 않는데 목록에만 있어서 "내가 설정한 건 15분·3분인데 20분 전 알림은 뭐지?" 가 된다.
    private var firingOffsets: [Int] {
        let mainSeconds = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        return screenVM.selectedOffsets
            .filter { $0 > 0 && $0 < mainSeconds }
            .sorted(by: >)
    }

    // MARK: - 편집 가능

    @ViewBuilder
    private func prealertMessageEditor(for offset: Int) -> some View {
        let label = offset < 60
            ? "\(offset) \(String(localized: "sec before alert"))"
            : "\(offset / 60) \(String(localized: "min before alert"))"
        let defaultMessage = offset < 60
            ? String(localized: "\(offset) sec remaining")
            : String(localized: "\(offset / 60) min remaining")

        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)

            TextField(defaultMessage, text: Binding(
                get: { screenVM.prealertMessages[offset] ?? "" },
                set: { screenVM.prealertMessages[offset] = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Text("Leave empty to use default message: \"\(defaultMessage)\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func resetAllMessages() {
        screenVM.prealertMessages.removeAll()
        screenVM.finishMessage = ""
        screenVM.showToast?(String(localized: "Messages have been reset"))
    }
}

#Preview {
    NotificationMessageSettingView()
        .environmentObject(TimerScreenViewModel())
}
