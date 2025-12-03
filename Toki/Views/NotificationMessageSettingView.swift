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
                    Text("타이머 알림 메시지를 커스터마이징할 수 있습니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("예비 알림 메시지")) {
                    ForEach(Array(screenVM.selectedOffsets.sorted()), id: \.self) { offset in
                        prealertMessageEditor(for: offset)
                    }

                    if screenVM.selectedOffsets.isEmpty {
                        Text("예비 알림이 설정되지 않았습니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("종료 알림 메시지")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("타이머 종료되었습니다", text: $screenVM.finishMessage)
                            .textFieldStyle(.roundedBorder)

                        Text("비워두면 기본 메시지가 사용됩니다: \"타이머 종료되었습니다\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(action: resetAllMessages) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("모든 메시지 초기화")
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("알림 메시지 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func prealertMessageEditor(for offset: Int) -> some View {
        let minutes = offset / 60
        let defaultMessage = "\(minutes)분 남았습니다"

        VStack(alignment: .leading, spacing: 8) {
            Text("\(minutes)분 전 알림")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField(defaultMessage, text: Binding(
                get: { screenVM.prealertMessages[offset] ?? "" },
                set: { screenVM.prealertMessages[offset] = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Text("비워두면 기본 메시지가 사용됩니다: \"\(defaultMessage)\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func resetAllMessages() {
        screenVM.prealertMessages.removeAll()
        screenVM.finishMessage = ""
        screenVM.showToast?("메시지가 초기화되었습니다")
    }
}

#Preview {
    NotificationMessageSettingView()
        .environmentObject(TimerScreenViewModel())
}
