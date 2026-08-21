//
//  PresentationSectionList.swift
//  Rereminder
//
//  발표 모드에서 원 아래에 놓이는 구간 카드 목록 — 이름을 고치는 곳이다.
//  (TimerMainView 에 섞여 있던 것을 떼어냈다. 다이얼 렌더링과 이 목록은 서로 모른다.)
//
//  들어오는 것: 구간 목록·편집 포커스·높이. 스스로 구간을 계산하지 않는다 —
//  링과 목록이 각자 계산하면 어긋나기 때문에 계산은 TimerSections 한 곳이 한다.
//

import SwiftUI

struct PresentationSectionList: View {
    @ObservedObject var screenVM: TimerScreenViewModel

    /// 지금 이름을 고치고 있는 구간 — 부모(TimerMainView)의 포커스 상태를 그대로 쓴다.
    /// 링 강조와 이 목록이 같은 값을 봐야 "저 호가 이 카드"가 유지된다.
    @FocusState.Binding var focusedSectionIndex: Int?

    let segments: [TimerSections.Segment]
    /// 편집 중인지에 따라 부모가 정해서 넘긴다(키보드가 올라오면 목록 몫이 커진다).
    let maxHeight: CGFloat
    /// 실행 중에는 이름을 고칠 수 없다.
    let isEditable: Bool

    /// 대본을 열어 둔 구간 (시트). `Int` 는 Identifiable 이 아니라 감싸서 쓴다.
    @State private var scriptTarget: ScriptTarget?

    private struct ScriptTarget: Identifiable { let id: Int }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: DSSpacing.sm) {
                    ForEach(segments) { segment in
                        row(segment)
                            .id(segment.index)
                    }
                }
                .padding(.horizontal, 16)
                // 알림 토글로 구간이 나뉘거나 합쳐질 때 부드럽게
                .animation(.easeInOut(duration: 0.25), value: screenVM.sortedOffsetsDesc)
                // 편집 포커스 이동 시 하이라이트 전환
                .animation(.easeInOut(duration: 0.2), value: focusedSectionIndex)
            }
            .frame(maxHeight: maxHeight)
            // 리스트를 끌면 키보드가 따라 내려감
            .scrollDismissesKeyboard(.interactively)
            // 편집을 시작하면 그 카드를 보이는 자리로 끌어온다.
            // 두 번 스크롤하는 이유: 누른 즉시 한 번(반응이 바로 보이게), 키보드가 다 올라와
            // 리스트 높이가 줄어든 뒤에 또 한 번(줄어든 창 기준으로 다시 맞춰야 실제로 보인다).
            .onChange(of: focusedSectionIndex) { _, index in
                guard let index else { return }
                scrollTo(index, using: proxy)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard focusedSectionIndex == index else { return }
                    scrollTo(index, using: proxy)
                }
            }
        }
        .sheet(item: $scriptTarget) { target in
            let index = target.id
            let segment = segments.first { $0.index == index }
            SectionScriptSheet(
                sectionName: sectionTitle(index),
                durationText: TimeMapper.mmss(segment?.durationSec ?? 0),
                color: SectionPalette.color(index),
                text: scriptBinding(index)
            )
            .presentationDetents([.medium, .large])
        }
    }

    /// 시트 제목에 쓸 구간 이름 — 이름을 안 지었으면 "Section N".
    private func sectionTitle(_ index: Int) -> String {
        let custom = (screenVM.sectionNames[index] ?? "").trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? String(localized: "Section \(index + 1)") : custom
    }

    // MARK: - 대본 한 줄

    /// 카드 맨 아래 **대본 미리보기**. 눌러서 시트로 고친다.
    /// 발표가 도는 중에는 고칠 수 없지만 **읽히기는 해야 한다** — 그때가 정작 볼 때다.
    @ViewBuilder
    private func scriptRow(_ segment: TimerSections.Segment, color: Color) -> some View {
        let script = (screenVM.sectionScripts[segment.index] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if isEditable {
            Button {
                scriptTarget = ScriptTarget(id: segment.index)
            } label: {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: script.isEmpty ? "square.and.pencil" : "text.quote")
                        .font(.caption)
                    Text(script.isEmpty ? String(localized: "Add script") : script)
                        .font(DSFont.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(script.isEmpty ? Color.secondary : color)
            }
            .buttonStyle(.plain)
            .padding(.top, DSSpacing.xxs)
        } else if !script.isEmpty {
            HStack(alignment: .top, spacing: DSSpacing.xs) {
                Image(systemName: "text.quote")
                    .font(.caption)
                Text(script)
                    .font(DSFont.caption)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .padding(.top, DSSpacing.xxs)
        }
    }

    private func scriptBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { screenVM.sectionScripts[index] ?? "" },
            set: { screenVM.sectionScripts[index] = $0 }
        )
    }

    private func scrollTo(_ index: Int, using proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(index, anchor: .center)
        }
    }

    // MARK: - 카드 한 장

    /// 2단 구성(이름 + 길이 배지 / 시간 범위)으로 빼곡함을 덜어 한눈에 들어오게
    @ViewBuilder
    private func row(_ segment: TimerSections.Segment) -> some View {
        let isEditingThis = focusedSectionIndex == segment.index
        let color = SectionPalette.color(segment.index)

        HStack(alignment: .top, spacing: DSSpacing.md) {
            // 링의 해당 구간과 같은 색 + 같은 번호 — 어느 호가 이 카드인지 두 가지로 잇는다
            // (이름을 바꾸고 나면 "Section 3" 이라는 순서 단서가 사라지기 때문에 번호를 따로 둔다)
            ZStack {
                Circle().fill(color)
                Text(verbatim: "\(segment.index + 1)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 20, height: 20)
            .padding(.top, 2)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                    TextField(
                        String(localized: "Section \(segment.index + 1)"),
                        text: nameBinding(segment.index)
                    )
                    .font(DSFont.body.weight(.semibold))
                    .disabled(!isEditable)
                    .focused($focusedSectionIndex, equals: segment.index)
                    .submitLabel(.done)
                    .accessibilityLabel(String(localized: "Section name"))

                    Spacer(minLength: DSSpacing.sm)

                    Text(TimeMapper.mmss(segment.durationSec))
                        .font(DSFont.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(DSColor.marker)
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xxs)
                        .background(Capsule().fill(DSColor.marker.opacity(DSOpacity.subtle)))
                }

                Text("\(rangeStartText(segment.startSec)) – \(rangeEndText(segment.endSec))")
                    .font(DSFont.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                scriptRow(segment, color: color)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(isEditingThis ? color.opacity(DSOpacity.subtle) : Color(.systemGray6))
        )
        .overlay(
            // 편집 중인 구간은 구간색 테두리로 포커싱
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(isEditingThis ? color : .clear, lineWidth: 1.5)
        )
        // 다른 구간을 편집 중이면 이 행은 한 발 물러남
        .opacity(focusedSectionIndex == nil || isEditingThis ? 1.0 : 0.55)
        .accessibilityElement(children: .combine)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - 표기

    /// 구간 이름 바인딩 — 빈 값이면 저장하지 않고 placeholder("Section N")로 돌아간다
    private func nameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { screenVM.sectionNames[index] ?? "" },
            set: { screenVM.sectionNames[index] = $0.isEmpty ? nil : $0 }
        )
    }

    /// 구간 시작 표기 — 타이머의 처음이면 "시작", 아니면 알림 칩과 같은 "종료 기준 N 전"
    private func rangeStartText(_ elapsedSec: Int) -> String {
        elapsedSec == 0 ? String(localized: "Start") : boundaryText(elapsedSec)
    }

    /// 구간 끝 표기 — 타이머의 끝이면 "종료", 아니면 경계 시각
    private func rangeEndText(_ elapsedSec: Int) -> String {
        elapsedSec == segments.last?.endSec ? String(localized: "End") : boundaryText(elapsedSec)
    }

    /// 경계 시각을 알림 칩과 같은 좌표(종료까지 남은 시간)로 표기 — "5:00 전"
    private func boundaryText(_ elapsedSec: Int) -> String {
        let total = segments.last?.endSec ?? 0
        let remaining = max(0, total - elapsedSec)
        return String(localized: "\(TimeMapper.formatTime(minutes: remaining / 60, seconds: remaining % 60)) left")
    }
}
