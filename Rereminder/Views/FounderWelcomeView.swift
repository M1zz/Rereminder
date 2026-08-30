//
//  FounderWelcomeView.swift
//  Rereminder
//
//  **창단 후원자에게 혜택 변경을 알리는 화면.**
//
//  왜 알림 한 줄이 아니라 화면인가: 먼저 산 사람이 가장 두려워하는 건 "내가 산 게 값이
//  떨어졌나"다. 그 불안은 한 문장으로 안 풀린다 — *무엇이 어떻게 바뀌는지*를 앞뒤로
//  보여 주고, 그중 무엇도 당신에게서 빼앗기지 않는다고 눈으로 확인시켜야 풀린다.
//
//  화면은 두 겹이다:
//  1. **약속** — 릴리즈가 바뀌어도 변하지 않는다. 앞으로 생기는 유료 기능은 전부 무료.
//  2. **이번에 달라지는 것** — `FounderChange.current` 를 갈아 끼운다.
//
//  ⚠️ `FounderChange.current` 의 문구는 **실제로 그 변경이 나가는 릴리즈에 맞춰** 고칠 것.
//     아직 안 바뀐 것을 바뀐다고 적으면 이 화면은 신뢰를 얻는 대신 잃는다.
//  ⚠️ 한 번 보고 나면 다시 뜨지 않는다(`FoundingSupporter.markAnnounced`). 다시 보고
//     싶은 사람을 위해 설정 > Pro 줄에서 같은 화면을 연다.
//

import SwiftUI

/// 한 줄의 변경 — 무엇이, 어떻게 달라지나.
struct FounderChange: Identifiable {
    let id: String
    /// SF Symbol
    let symbol: String
    /// 무엇에 대한 이야기인가 (예: 알림, Pro, 가격)
    let subject: String
    let before: String
    let after: String

    /// 이번 릴리즈에서 알릴 변경들.
    ///
    /// ⚠️ 게이트를 실제로 바꾸는 릴리즈에서 이 배열과 `ProGate` 를 **함께** 고칠 것.
    static let current: [FounderChange] = [
        FounderChange(
            id: "prealerts",
            symbol: "bell.badge.fill",
            subject: String(localized: "Pre-alerts"),
            before: String(localized: "Limited on the free plan"),
            after: String(localized: "Unlimited for everyone")
        ),
        FounderChange(
            id: "pro",
            symbol: "person.wave.2.fill",
            subject: String(localized: "What Pro unlocks"),
            before: String(localized: "More pre-alerts"),
            after: String(localized: "Session tools — section names, scripts, templates and history")
        ),
        FounderChange(
            id: "price",
            symbol: "tag.fill",
            subject: String(localized: "Price"),
            before: String(localized: "What you paid"),
            after: String(localized: "Higher for new buyers")
        )
    ]
}

struct FounderWelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    /// 처음 뜬 안내인지(=닫으면 다시 안 뜬다), 설정에서 다시 열어 본 것인지.
    var isFirstShowing: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                    header
                    promise
                    changes
                    closing
                }
                .padding(DSSpacing.xl)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.lg)
                }
                .buttonStyle(.borderedProminent)
                .padding(DSSpacing.xl)
                .background(.bar)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
        }
        .onDisappear {
            if isFirstShowing { FoundingSupporter.markAnnounced() }
        }
    }

    // MARK: - 조각들

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            FounderBadge()
            Text("Thank you for backing this early")
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("Pro is changing shape. Here's what that means for you — and what it doesn't.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 변하지 않는 부분. 화면에서 가장 먼저, 가장 크게 보여야 한다.
    private var promise: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "gift.fill")
                    .foregroundStyle(DSColor.marker)
                Text("Every future Pro feature, included")
                    .font(.headline)
            }
            Text("You backed this app early. Anything we add to Pro from now on unlocks for you automatically — no extra purchase, ever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .fill(DSColor.marker.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(DSColor.marker.opacity(0.3), lineWidth: 0.5)
        )
    }

    private var changes: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text("What's changing")
                .font(.headline)
            ForEach(FounderChange.current) { change in
                changeRow(change)
            }
        }
    }

    private func changeRow(_ change: FounderChange) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: change.symbol)
                .font(.body)
                .foregroundStyle(DSColor.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(change.subject)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: DSSpacing.sm) {
                    Text(change.before)
                        .strikethrough()
                        .foregroundStyle(.tertiary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(change.after)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var closing: some View {
        Text("Nothing you already have is going away.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    FounderWelcomeView()
}
