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
    @State private var showPaywall = false
    @State private var paywallFeature: ProGate.Feature?

    private var isPro: Bool { StoreManager.isProUser }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Customize your timer notification messages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("Pre-alert Message")) {
                    if isPro {
                        ForEach(Array(screenVM.selectedOffsets.sorted()), id: \.self) { offset in
                            prealertMessageEditor(for: offset)
                        }
                    } else {
                        // 무료: 미리보기만 + 잠금
                        ForEach(Array(screenVM.selectedOffsets.sorted()), id: \.self) { offset in
                            prealertMessagePreview(for: offset)
                        }

                        proUpgradeRow(feature: .customPrealertMessage)
                    }

                    if screenVM.selectedOffsets.isEmpty {
                        Text("No pre-alerts set")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("End Alert Message")) {
                    if isPro {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Timer finished", text: $screenVM.finishMessage)
                                .textFieldStyle(.roundedBorder)

                            Text("Leave empty to use default message: \"Timer finished\"")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Timer finished")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Default message")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.orange)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            paywallFeature = .customFinishMessage
                            showPaywall = true
                        }
                    }
                }

                if isPro {
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
            }
            .navigationTitle("Notification Message Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .paywallGate(isPresented: $showPaywall, feature: paywallFeature)
        }
    }

    // MARK: - Pro: 편집 가능

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

    // MARK: - Free: 미리보기 + 잠금

    @ViewBuilder
    private func prealertMessagePreview(for offset: Int) -> some View {
        let minutes = offset / 60

        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(minutes) \(String(localized: "min before alert"))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(minutes) min remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            paywallFeature = .customPrealertMessage
            showPaywall = true
        }
    }

    // MARK: - Pro Upgrade Row

    @ViewBuilder
    private func proUpgradeRow(feature: ProGate.Feature) -> some View {
        Button {
            paywallFeature = feature
            showPaywall = true
        } label: {
            HStack(spacing: 10) {
                ProBadge(small: true)
                Text("Customize messages with Pro")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
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
