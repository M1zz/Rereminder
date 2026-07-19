//
//  FeedbackInboxView.swift
//  Rereminder
//
//  개발자 전용 피드백 인박스 (마스터 모드) — CloudKit Public DB의 Feedback 레코드를
//  앱 안에서 바로 확인한다. 설정 > Info의 버전 행을 7번 탭하면 진입점이 나타난다.
//
//  ⚠️ 다른 사용자의 레코드를 읽으려면 CloudKit Dashboard에서 admin 역할을 만들어
//  read 권한과 본인 userRecordName을 등록해야 한다 (docs/FEEDBACK_CLOUDKIT.md).
//

import SwiftUI

struct FeedbackInboxView: View {
    @State private var records: [FeedbackService.FeedbackRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var userRecordName: String?
    @State private var didCopyId = false
    @State private var pendingDelete: FeedbackService.FeedbackRecord?
    // 새 피드백 푸시 알림 (CKQuerySubscription — 서버 기준 상태)
    @State private var notifyEnabled = false
    @State private var notifyLoaded = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yyMMdjmm")
        return f
    }

    var body: some View {
        List {
            notifySection

            if isLoading && records.isEmpty {
                Section {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(String(localized: "Loading…"))
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                } footer: {
                    Text(String(localized: "If this is a permission error, register the admin role with read access and your user ID below in CloudKit Dashboard."))
                }
            } else if records.isEmpty {
                Section {
                    Text(String(localized: "No feedback yet"))
                        .foregroundStyle(.secondary)
                }
            } else {
                recordsSection
            }

            userIdSection
        }
        .navigationTitle(String(localized: "Feedback Inbox"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .alert(
            String(localized: "Delete this feedback?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                if let record = pendingDelete { deleteRecord(record) }
                pendingDelete = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { pendingDelete = nil }
        } message: {
            Text(String(localized: "It will be permanently removed from the server."))
        }
    }

    // MARK: - Sections

    private var notifySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { notifyEnabled },
                set: { setNotify($0) }
            )) {
                Label(String(localized: "New Feedback Alerts"), systemImage: "bell.badge")
            }
            .disabled(!notifyLoaded)
        } footer: {
            Text(String(localized: "Pushes a notification to this device when new feedback arrives. Requires read access for the CloudKit admin role."))
        }
    }

    private var recordsSection: some View {
        Section {
            ForEach(records) { record in
                recordRow(record)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            toggleDone(record)
                        } label: {
                            Label(record.isDone
                                  ? String(localized: "Mark as Open")
                                  : String(localized: "Mark as Done"),
                                  systemImage: record.isDone ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(record.isDone ? .orange : .green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDelete = record
                        } label: {
                            Label(String(localized: "Delete"), systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text(String(localized: "\(records.count) received · \(records.filter(\.isDone).count) done"))
        } footer: {
            Text(String(localized: "Swipe right to mark done, left to delete. Requires write access for the CloudKit admin role."))
        }
    }

    @ViewBuilder
    private var userIdSection: some View {
        // Dashboard admin 역할 등록용 내 사용자 ID
        if let userRecordName {
            Section {
                Button {
                    UIPasteboard.general.string = userRecordName
                    withAnimation { didCopyId = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { didCopyId = false }
                    }
                } label: {
                    HStack {
                        Text(userRecordName)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: didCopyId ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(didCopyId ? .green : .accentColor)
                    }
                }
            } header: {
                Text(String(localized: "My User ID"))
            } footer: {
                Text(String(localized: "Add this ID to the admin role in CloudKit Dashboard to read all feedback in the app. Tap to copy."))
            }
        }
    }

    private func recordRow(_ record: FeedbackService.FeedbackRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let type = FeedbackType(rawValue: record.type)
                Image(systemName: record.isDone ? "checkmark.circle.fill" : (type?.icon ?? "ellipsis.bubble"))
                    .font(.caption)
                    .foregroundStyle(record.isDone ? .green : .accentColor)
                    .accessibilityHidden(true)
                Text(type?.localizedName ?? record.type)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(record.isDone ? Color.secondary : Color.accentColor)
                if record.isDone {
                    Text(String(localized: "Done"))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                Spacer()
                if let createdAt = record.createdAt {
                    Text(dateFormatter.string(from: createdAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(record.message)
                .font(DSFont.body)
                .foregroundStyle(record.isDone ? Color.secondary : Color.primary)
                .textSelection(.enabled)

            Text(record.deviceInfo.isEmpty
                 ? "\(record.appVersion) · \(record.platform) · \(record.locale)"
                 : "\(record.deviceInfo) · \(record.locale)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if userRecordName == nil {
            userRecordName = await FeedbackService.shared.currentUserRecordName()
        }
        if !notifyLoaded {
            notifyEnabled = await FeedbackService.shared.isNewFeedbackNotificationEnabled()
            notifyLoaded = true
        }
        do {
            records = try await FeedbackService.shared.fetchAll()
        } catch {
            print("❌ [FeedbackInboxView.load] \(error)")
            errorMessage = error.localizedDescription
        }
    }

    /// 새 피드백 푸시 알림 켜기/끄기 — CKQuerySubscription 등록/해제.
    private func setNotify(_ enabled: Bool) {
        Task {
            do {
                if enabled {
                    try await FeedbackService.shared.enableNewFeedbackNotifications()
                } else {
                    try await FeedbackService.shared.disableNewFeedbackNotifications()
                }
                notifyEnabled = enabled
            } catch {
                print("❌ [FeedbackInboxView.setNotify] \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 완료/미완료 토글 — 서버 반영 후 로컬 목록 갱신.
    private func toggleDone(_ record: FeedbackService.FeedbackRecord) {
        Task {
            do {
                try await FeedbackService.shared.setDone(recordName: record.id, done: !record.isDone)
                if let index = records.firstIndex(where: { $0.id == record.id }) {
                    records[index].status = record.isDone ? nil : "done"
                }
            } catch {
                print("❌ [FeedbackInboxView.toggleDone] \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 서버에서 레코드 삭제 후 로컬 목록에서 제거.
    private func deleteRecord(_ record: FeedbackService.FeedbackRecord) {
        Task {
            do {
                try await FeedbackService.shared.delete(recordName: record.id)
                records.removeAll { $0.id == record.id }
            } catch {
                print("❌ [FeedbackInboxView.deleteRecord] \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackInboxView()
    }
}
