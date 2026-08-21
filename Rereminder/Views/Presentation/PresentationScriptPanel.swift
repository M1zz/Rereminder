//
//  PresentationScriptPanel.swift
//  Rereminder
//
//  발표가 도는 동안 원 아래에 서는 **지금 구간의 대본**.
//
//  준비 화면에서는 구간 카드 목록이 그 자리를 쓴다(구간을 고치는 곳이니까). 하지만 **발표가
//  시작되면 고칠 일은 없고 읽을 일만 남는다** — 그때 목록은 "지금 어디"를 다시 찾게 만들 뿐이라,
//  지금 구간 하나만 크게 펴 놓는다.
//
//  규칙
//   • 대본이 비어 있으면 이 패널은 뜨지 않는다(부르는 쪽에서 판단) — 안 쓰는 사람에게 빈 상자를
//     보여줄 이유가 없다.
//   • 글이 길면 **패널 안에서만** 스크롤한다. 화면이 밀리면 위쪽 시간이 가려진다.
//   • 구간이 바뀌면 글을 통째로 갈아 끼운다(`.id`) — 이어 붙이면 어디까지 읽었는지 잃는다.
//

import SwiftUI

struct PresentationScriptPanel: View {
    /// 지금 구간 번호(경과 순서) — 색·전환에 쓴다.
    let sectionIndex: Int
    let sectionName: String
    let script: String
    /// 다음 구간 이름. 마지막 구간이면 nil.
    let nextName: String?
    let maxHeight: CGFloat

    private var color: Color { SectionPalette.color(sectionIndex) }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(sectionName)
                    .font(DSFont.callout.weight(.semibold))
                Spacer(minLength: DSSpacing.sm)
                if let nextName {
                    Text("Next: \(nextName)")
                        .font(DSFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            ScrollView {
                Text(script)
                    .font(DSFont.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: maxHeight)
        }
        .padding(DSSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .stroke(color.opacity(DSOpacity.subtle), lineWidth: 1)
        )
        .padding(.horizontal, DSSpacing.lg)
        .id(sectionIndex)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Script"))
        .accessibilityValue(Text(verbatim: script))
    }
}
