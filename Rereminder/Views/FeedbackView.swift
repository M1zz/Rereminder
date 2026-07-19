//
//  FeedbackView.swift
//  Rereminder
//
//  사용자 피드백 작성 시트 — CloudKit Public DB로 직접 제출하고,
//  실패하면 이메일(mailto)로 폴백한다.
//

import SwiftUI

// MARK: - Feedback Type

enum FeedbackType: String, CaseIterable {
    case bug      = "bug"
    case feature  = "feature"
    case question = "question"
    case other    = "other"

    var localizedName: String {
        switch self {
        case .bug:      return String(localized: "Bug Report")
        case .feature:  return String(localized: "Feature Request")
        case .question: return String(localized: "Question")
        case .other:    return String(localized: "Other")
        }
    }

    var icon: String {
        switch self {
        case .bug:      return "ladybug"
        case .feature:  return "lightbulb"
        case .question: return "questionmark.circle"
        case .other:    return "ellipsis.bubble"
        }
    }

    var placeholder: String {
        switch self {
        case .bug:      return String(localized: "Tell us what went wrong.\ne.g. The alert didn't fire in the background.")
        case .feature:  return String(localized: "What feature would you like?\ne.g. I'd like to repeat timers automatically.")
        case .question: return String(localized: "What would you like to know?\ne.g. How do I add more pre-alerts?")
        case .other:    return String(localized: "Share anything on your mind.")
        }
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: FeedbackType = .bug
    @State private var message: String = ""
    @State private var isSending = false
    @State private var didSend = false
    @State private var showMailFallback = false

    private static let developerEmail = "leeo@kakao.com"

    private let deviceInfo: String = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let device = UIDevice.current
        return "App \(version) | \(device.model) | \(device.systemName) \(device.systemVersion)"
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    typeSelector
                    messageEditor
                    deviceInfoCard
                    sendButton
                    Spacer(minLength: 40)
                }
                .padding(DSSpacing.lg)
            }
            .navigationTitle(String(localized: "Send Feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
            .alert(
                String(localized: "Couldn't send via iCloud"),
                isPresented: $showMailFallback
            ) {
                Button(String(localized: "Send by Email"), action: openMailtoURL)
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "Sign in to iCloud to send directly from the app, or send your feedback by email instead."))
            }
            .overlay(alignment: .center) {
                if didSend { sentConfirmation }
            }
        }
    }

    // MARK: - Type Selector

    private var typeSelector: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "Feedback Type"))
                .font(DSFont.callout.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DSSpacing.sm) {
                ForEach(FeedbackType.allCases, id: \.self) { type in
                    typeChip(type)
                }
            }
        }
    }

    private func typeChip(_ type: FeedbackType) -> some View {
        let selected = selectedType == type
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedType = type }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                Text(type.localizedName)
                    .multilineTextAlignment(.center)
            }
            .font(DSFont.callout.weight(selected ? .semibold : .regular))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(selected ? .accentColor : .gray)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(type.localizedName)
    }

    // MARK: - Message Editor

    private var messageEditor: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(String(localized: "Message"))
                .font(DSFont.callout.weight(.semibold))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .font(DSFont.body)
                    .frame(minHeight: 140)
                    .padding(DSSpacing.xs)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel(String(localized: "Feedback message"))
                    .accessibilityHint(String(localized: "Describe your issue or suggestion."))

                if message.isEmpty {
                    Text(selectedType.placeholder)
                        .font(DSFont.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DSSpacing.sm + 4)
                        .padding(.vertical, DSSpacing.sm + 8)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Auto-attached Info"))
                .font(DSFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(deviceInfo)
                .font(DSFont.caption)
                .foregroundStyle(.secondary)
                .padding(DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        let isDisabled = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
        return Button(action: sendFeedback) {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSending ? String(localized: "Sending…") : String(localized: "Send"))
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isDisabled)
        .accessibilityLabel(String(localized: "Send Feedback"))
        .accessibilityHint(isDisabled
            ? String(localized: "Enabled after you enter a message.")
            : String(localized: "Sends your feedback directly to the developer."))
    }

    // MARK: - Sent Confirmation Overlay

    private var sentConfirmation: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .dsScaledFont(56, relativeTo: .largeTitle, maxSize: 72)
                .foregroundStyle(.green)
            Text(String(localized: "Feedback sent!\nThank you for your input 🙏"))
                .font(DSFont.sectionHeader)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DSRadius.lg))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
        .padding(40)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Send Logic

    /// 1차: CloudKit Public DB로 직접 제출 (메일 앱 불필요, iCloud 로그인만 필요).
    /// 실패 시 폴백: 이메일 경로.
    private func sendFeedback() {
        isSending = true
        Task {
            do {
                try await FeedbackService.shared.submit(
                    type: selectedType.rawValue,
                    message: message,
                    deviceInfo: deviceInfo
                )
                await MainActor.run {
                    isSending = false
                    handleSent()
                }
            } catch {
                print("⚠️ [FeedbackView.sendFeedback] CloudKit 제출 실패 → 이메일 폴백: \(error)")
                await MainActor.run {
                    isSending = false
                    showMailFallback = true
                }
            }
        }
    }

    private func openMailtoURL() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let subject = "[\(selectedType.localizedName)] \(AppName.display) \(version)"
        let body = "\(message)\n\n---\n\(deviceInfo)"
        let raw = "mailto:\(Self.developerEmail)?subject=\(subject)&body=\(body)"
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encoded) else { return }
        UIApplication.shared.open(url)
        handleSent()
    }

    private func handleSent() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { didSend = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { dismiss() }
    }
}

#Preview {
    FeedbackView()
}
