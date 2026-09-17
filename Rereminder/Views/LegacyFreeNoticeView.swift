//
//  LegacyFreeNoticeView.swift
//  Rereminder
//
//  **Pro 가 바뀌기 전부터 무료로 쓰던 사람에게 무엇이 달라졌는지 보여 주는 화면.**
//  판정은 `LegacyFreeNotice`.
//
//  `FounderWelcomeView` 와 같은 문법(앞 → 뒤)을 쓰되 말하는 것이 다르다. 창단 후원자에게는
//  "빼앗기는 것이 없다"고 말할 수 있었지만 이 사람들에게는 **그 말을 할 수 없다.**
//  그래서 순서가 이렇다:
//  1. **모두에게 열린 것** — 얻은 것부터 (예비 알림 무제한)
//  2. **Pro 로 옮긴 것** — 잃은 것을 숨기지 않고 앞뒤로 적는다
//  3. **그대로 둔 것** — 개편 전에 저장한 템플릿은 무료에서도 계속 불러온다(`isPreChangeTemplate`).
//     템플릿이 없던 사람에게는 마지막 설정이 지워지지 않았다고 말한다
//  4. **왜** — 한 문장
//
//  ⚠️ 문구는 **사실만** 적는다. 사과하는 척하며 파는 화면이 되면 화를 더 키운다 —
//     Pro 로 가는 길은 아래 보조 버튼 하나뿐이고, 주 버튼은 "확인"이다.
//  ⚠️ 이 화면의 말은 세 가지가 지켜질 때만 참이다 — 개편 전 템플릿을 무료에서 불러오는 것
//     (`TemplateQuickBar.canLoad`), 무료에서도 `persistLastUsedConfig` 가 저장하는 것,
//     `TimerConfigService` 가 템플릿을 지우지 않는 것. 하나라도 바꾸면 문구도 함께 고칠 것.
//

import SwiftData
import SwiftUI

struct LegacyFreeNoticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var templates: [Timer]

    /// 처음 뜬 안내인지(=닫으면 다시 안 뜬다), 설정에서 다시 열어 본 것인지.
    var isFirstShowing: Bool = true
    /// "Pro 알아보기"를 눌렀을 때. 시트가 닫힌 뒤에 페이월을 여는 건 부르는 쪽이 한다.
    var onSeePro: () -> Void = {}

    /// 개편 전에 사용자가 직접 저장한 템플릿 수 (시드 제외) — 무료에서도 계속 불러오는 것들.
    private var userTemplateCount: Int {
        templates.filter {
            !LegacyFreeNotice.seedTemplateNames.contains($0.name)
                && LegacyFreeNotice.isPreChangeTemplate(createdAt: $0.createdAt)
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                    header
                    changeGroup(title: String(localized: "Now free for everyone"), rows: gained)
                    changeGroup(title: String(localized: "Moved to Pro"), rows: movedToPro)
                    keptCard
                    why
                }
                .padding(DSSpacing.xl)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DSSpacing.sm) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Got it")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.lg)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        AnalyticsManager.log(.rememberPitchTapped(kind: "legacy"))
                        ProMention.markTapped()
                        dismiss()
                        onSeePro()
                    } label: {
                        Text("Let the app remember your setups")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                }
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
            if isFirstShowing { LegacyFreeNotice.markAnnounced() }
        }
    }

    // MARK: - 내용

    private var gained: [FounderChange] {
        [
            FounderChange(
                id: "prealerts",
                symbol: "bell.badge.fill",
                subject: String(localized: "Pre-alerts"),
                before: String(localized: "Limited on the free plan"),
                after: String(localized: "Unlimited for everyone")
            )
        ]
    }

    private var movedToPro: [FounderChange] {
        [
            FounderChange(
                id: "templates",
                symbol: "bookmark.fill",
                subject: String(localized: "Saved templates"),
                before: String(localized: "Up to 3 on the free plan"),
                after: String(localized: "Saving new ones is Pro")
            ),
            FounderChange(
                id: "lastSetup",
                symbol: "arrow.counterclockwise",
                subject: String(localized: "Reopening the app"),
                before: String(localized: "Your last setup came back"),
                after: String(localized: "Starts from the default on the free plan")
            )
        ]
    }

    // MARK: - 조각들

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("What changed for you")
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("You've been using this app since before Pro changed. Here is exactly what is different now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func changeGroup(title: String, rows: [FounderChange]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text(title)
                .font(.headline)
            ForEach(rows) { change in
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

    /// 잃은 것 바로 뒤에 "원래 쓰던 것은 그대로 두었다"를 둔다 — 화가 나는 지점은 "빼앗겼다"다.
    private var keptCard: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(DSColor.accent)
                Text(userTemplateCount > 0
                     ? String(localized: "Your \(userTemplateCount) saved templates still work")
                     : String(localized: "Your last setup is still saved"))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(userTemplateCount > 0
                 ? String(localized: "Templates you saved before the change keep loading on the free plan. Only saving new ones is Pro.")
                 : String(localized: "Nothing was deleted. If you upgrade, everything comes back exactly as you left it."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .fill(DSColor.accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(DSColor.accent.opacity(0.3), lineWidth: 0.5)
        )
    }

    private var why: some View {
        Text("Getting several alerts before time runs out is why this app exists, so it is now free for everyone. Pro does one thing instead: it remembers your setups.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LegacyFreeNoticeView()
}
