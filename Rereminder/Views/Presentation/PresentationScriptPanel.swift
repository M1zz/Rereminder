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
//   • **글은 구간 시간에 맞춰 저절로 흐른다**(프롬프터). 구간을 절반 썼으면 글도 절반쯤 와 있다 —
//     속도를 따로 정하지 않고, 글의 위치가 곧 "이 구간을 얼마나 썼나"다. 끝 10% 는 마지막 줄을 보여 준 채 머문다.
//     일시정지하면 시간이 멈추니 글도 멈춘다. 손으로 밀면 3초 쉬었다가 다시 시간을 따라간다.
//

import SwiftUI

struct PresentationScriptPanel: View {
    /// 지금 구간 번호(경과 순서) — 색·전환에 쓴다.
    let sectionIndex: Int
    let sectionName: String
    let script: String
    /// 다음 구간 이름. 마지막 구간이면 nil.
    let nextName: String?
    /// 이 구간을 쓴 비율(0 → 1). 글이 흐르는 위치다.
    let progress: Double
    let maxHeight: CGFloat

    @State private var position = ScrollPosition(edge: .top)
    /// 글 전체 높이 − 보이는 높이. 0 이면 다 보여서 흐를 필요가 없다.
    @State private var scrollableHeight: CGFloat = 0
    /// 손으로 민 뒤 시간을 다시 따라가기 시작하는 때.
    @State private var userHoldUntil: Date = .distantPast

    private var color: Color { SectionPalette.color(sectionIndex) }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                // 구간 이름은 사용자가 쓴 글이라 얼마든지 길어진다 — 한 줄에서 끝을 줄이고,
                // 조금 넘치는 정도는 글자 간격을 좁혀 다 보이게 한다.
                Text(sectionName)
                    .font(DSFont.callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .allowsTightening(true)
                Spacer(minLength: DSSpacing.sm)
                if let nextName {
                    Text("Next: \(nextName)")
                        .font(DSFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .allowsTightening(true)
                }
            }

            ScrollView {
                // 프롬프터로 읽는다 — 화면을 내려다보는 짧은 순간에 한 줄이 잡혀야 한다.
                Text(script)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .lineSpacing(6)
                    // 대본 속 링크·숫자·한 문장을 길게 눌러 복사해 채팅에 붙일 수 있게.
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: maxHeight)
            .scrollPosition($position)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                max(0, geo.contentSize.height - geo.containerSize.height)
            } action: { _, height in
                scrollableHeight = height
            }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting || phase == .decelerating {
                    userHoldUntil = Date().addingTimeInterval(3)
                }
            }
            .onChange(of: progress) { _, _ in follow(animated: true) }
            .onChange(of: scrollableHeight) { _, _ in follow(animated: false) }
        }
        // 글이 짧아도 상자는 남는 자리를 채운다 — 상자가 글 길이마다 늘었다 줄었다 하면 읽던 자리가 흔들린다.
        .frame(maxHeight: .infinity, alignment: .top)
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

    /// 지금 시간에 맞는 자리로 글을 옮긴다. 남은 시간은 0.5초마다 바뀌므로 그 사이를 선형으로 잇는다.
    private func follow(animated: Bool) {
        guard scrollableHeight > 0, Date() >= userHoldUntil else { return }
        let y = scrollableHeight * min(1, progress / 0.9)
        if animated {
            withAnimation(.linear(duration: 0.5)) { position.scrollTo(y: y) }
        } else {
            position.scrollTo(y: y)
        }
    }
}
