//
//  RememberRecallLine.swift
//  Rereminder
//
//  무료 사용자에게 다이얼 아래에 서는 한 줄. 두 순간에 쓴다(`ProMention` 예산 안에서 각 한 번):
//  - `.recall`  앱을 다시 열어 다이얼이 기본값일 때 — "지난번엔 25:00, 알림 3개였어요."
//  - `.reentry` 그 다이얼을 **손으로 지난번 설정에 다시 맞춘** 직후 — 불편을 방금 몸으로 겪은 순간이다.
//
//  왜: 무료에서는 콜드 런치에 다이얼이 **조용히** 기본값으로 돌아간다. 사용자는 "원래 그런 앱"이라고
//  생각하고 다시 맞출 뿐, 자기가 Pro 가 필요한 사람인 줄 모른다. 방금 겪은 불편에 이름을 붙여 준다.
//
//  ⚠️ **모달이 아니다.** 알림창으로 띄우면 앱을 열 때마다 무언가를 닫아야 하는 앱이 된다.
//  ⚠️ 띄울지는 `RememberPitch.recallLine` + `ProMention` 예산이 정하고, 여기서는
//     "지금도 말이 되는가"만 본다 — 다이얼을 이미 바꿨거나 결제했으면 조용히 물러난다.
//  ⚠️ 한 줄을 눌러도 설정을 올려 주지 **않는다.** 올려 주면 Pro 가 파는 일을 공짜로 하게 된다
//     (그 체험은 예약한 자리의 전날 한 번뿐이다 — `RememberPitch` ③).
//

import SwiftUI

struct RememberRecallLine: View {
    let config: RepeatDetector.Config
    var kind: ProMention.Kind = .recall
    let onDismiss: () -> Void

    private var message: String {
        let time = TimeMapper.clockText(config.mainSec)
        let alerts = config.offsets.count
        // 세션 모드를 써 본 사람의 절반에게는 세션을 앞세운 문구를 보인다(`ProMention.CopyVariant`).
        let session = ProMention.usesSessionCopy
        switch (kind, session) {
        case (.reentry, true):
            return String(localized: "You set \(time) with \(alerts) alerts again by hand. Pro saves it with your section names and scripts.")
        case (.reentry, false):
            return String(localized: "You set \(time) with \(alerts) alerts again by hand. Pro keeps it on the dial for you.")
        case (_, true):
            return String(localized: "Last time: \(time) with \(alerts) alerts. Pro saves it with your section names and scripts.")
        default:
            return String(localized: "Last time: \(time) with \(alerts) alerts. Pro remembers it for you.")
        }
    }

    @State private var showPaywall = false

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Button {
                AnalyticsManager.log(.rememberPitchTapped(kind: kind.rawValue))
                ProMention.markTapped()
                showPaywall = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DSColor.accent)
                    Text(message)
                        .font(DSFont.callout)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(String(localized: "Shows what Pro includes")))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Close"))
        }
        .padding(.leading, DSSpacing.md)
        .padding(.trailing, DSSpacing.xs)
        .padding(.vertical, DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DSColor.accent.opacity(0.10))
        )
        .paywallGate(isPresented: $showPaywall, feature: .unlimitedTemplates)
    }
}
