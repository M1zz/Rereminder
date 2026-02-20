//
//  NotificationMessageSettingView.swift
//  Toki
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
                    Text("Customize your timer notification messages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("Pre-alert Message")) {
                    ForEach(Array(screenVM.selectedOffsets.sorted()), id: \.self) { offset in
                        prealertMessageEditor(for: offset)
                    }

                    if screenVM.selectedOffsets.isEmpty {
                        Text("No pre-alerts set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func prealertMessageEditor(for offset: Int) -> some View {
        let minutes = offset / 60
        let defaultMessage = String(localized: "\(minutes) min remaining")

        VStack(alignment: .leading, spacing: 8) {
            Text("\(minutes) \(String(localized: "min before alert"))")
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
