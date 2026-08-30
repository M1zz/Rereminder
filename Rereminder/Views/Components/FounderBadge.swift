//
//  FounderBadge.swift
//  Rereminder
//
//  창단 후원자 표식 — 설정의 Pro 줄과 페이월에 붙는다.
//
//  왜 배지인가: 약속은 말로만 하면 잊힌다. 앱을 열 때마다 눈에 보이는 자리에 표식이
//  남아 있어야 "나는 대접받고 있다"가 유지된다. 그래서 안내는 한 번만 뜨지만
//  배지는 계속 남는다.
//

import SwiftUI

/// 이름표 하나 — 왕관 + "창단 후원자".
struct FounderBadge: View {
    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "crown.fill")
                .font(.caption2)
            Text("Founding Supporter")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(DSColor.marker)
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xxs + 1)
        .background(
            Capsule().fill(DSColor.marker.opacity(0.14))
        )
        .overlay(
            Capsule().stroke(DSColor.marker.opacity(0.35), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Founding Supporter"))
    }
}

/// 약속을 적어 두는 자리 — 설정에서 언제든 다시 읽을 수 있게.
/// 안내 알림은 한 번만 뜨므로, **약속의 원문은 여기가 유일한 상설 위치**다.
struct FounderPromiseRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: "gift.fill")
                .font(.body)
                .foregroundStyle(DSColor.marker)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("Every future Pro feature, included")
                    .font(.subheadline.weight(.semibold))
                Text("You backed this app early. Anything we add to Pro from now on unlocks for you automatically — no extra purchase, ever.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DSSpacing.xl) {
        FounderBadge()
        FounderPromiseRow()
    }
    .padding()
}
