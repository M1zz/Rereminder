//
//  SectionScriptSheet.swift
//  Rereminder
//
//  구간에 **말할 것**을 적어 두는 자리 — 대본·메모.
//
//  왜 시트인가: 구간 카드 안에 여러 줄 입력을 넣으면 카드가 화면 절반을 먹고, 키보드가 올라올
//  때마다 목록이 출렁인다. 글은 길어질 수 있는 것이라 제 화면을 주는 편이 낫다.
//
//  이 글은 발표 중 화면(`PresentationDisplayView`)에 그 구간 차례가 되면 뜬다.
//

import SwiftUI

struct SectionScriptSheet: View {
    let sectionName: String
    let durationText: String
    /// 링·카드와 같은 구간 색 — "이 글이 저 구간"이 이어지게.
    let color: Color
    @Binding var text: String

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack(spacing: DSSpacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    Text(sectionName)
                        .font(DSFont.body.weight(.semibold))
                    Spacer()
                    Text(durationText)
                        .font(DSFont.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DSSpacing.lg)

                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(DSFont.body)
                    .scrollContentBackground(.hidden)
                    .padding(DSSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, DSSpacing.lg)
                    .overlay(alignment: .topLeading) {
                        // TextEditor 에는 placeholder 가 없다
                        if text.isEmpty {
                            Text("What will you say in this section?")
                                .font(DSFont.body)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, DSSpacing.lg + DSSpacing.sm + 5)
                                .padding(.top, DSSpacing.sm + 8)
                                .allowsHitTesting(false)
                        }
                    }

                Text("This shows on screen while you present, when this section's turn comes.")
                    .font(DSFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.bottom, DSSpacing.sm)
            }
            .padding(.top, DSSpacing.md)
            .navigationTitle(Text("Script"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }
}
