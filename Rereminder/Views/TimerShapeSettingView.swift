//
//  TimerShapeSettingView.swift
//  Rereminder
//
//  설정 > 타이머 모양 — **실루엣을 보고 고른다.**
//  이름만 늘어놓으면("이중 링", "접은 줄") 무엇을 고르는 건지 알 수 없어서, 같은 예시 타이머를
//  네 모양으로 그려 나란히 세운다(`TimerShapeSilhouette`).
//
//  ⚠️ 여기서 고른 모양은 **타이머가 도는 동안**의 표시에만 적용된다. 시간·알림을 정할 때는
//     흰 핸들과 종 노브를 끄는 조작이 원에 묶여 있어 언제나 다이얼(원)이다 — 화면 아래 설명도
//     그 이야기다.
//

import SwiftUI

struct TimerShapeSettingView: View {
    @AppStorage(TimerShape.storageKey) private var shapeRaw = TimerShape.fallback.rawValue

    private var selected: TimerShape { TimerShape.resolve(shapeRaw) }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TimerShapeSilhouette(shape: selected, size: 168, showsMarkers: true)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.25), value: selected)

                    Text("A 10-minute timer with two alerts, about halfway through.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                ForEach(TimerShape.allCases) { shape in
                    Button {
                        shapeRaw = shape.rawValue
                    } label: {
                        row(for: shape)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Timer Shape")
            } footer: {
                Text("This is how a running timer looks. While you set the time, the dial stays a ring — that is what you drag the handle and bells on.")
            }
        }
        .navigationTitle(Text("Timer Shape"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for shape: TimerShape) -> some View {
        HStack(spacing: 14) {
            TimerShapeSilhouette(shape: shape, size: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(shape.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(shape.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: selected == shape ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(selected == shape ? Color.accentColor : Color.secondary.opacity(0.4))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected == shape ? [.isButton, .isSelected] : .isButton)
    }
}
