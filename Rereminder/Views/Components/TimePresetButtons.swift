//
//  TimePresetButtons.swift
//  Rereminder
//
//  Created for usability improvements
//

import SwiftUI

struct TimePresetButtons: View {
    @ObservedObject var screenVM: TimerScreenViewModel
    @ObservedObject private var store = PresetStore.shared

    /// 길게 눌러 편집 중인 슬롯
    private struct EditTarget: Identifiable { let id: Int }
    @State private var editTarget: EditTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text("Quick Setup")
                    .font(DSFont.callout.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Touch and hold to edit")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DSSpacing.md)

            HStack(spacing: DSSpacing.sm) {
                ForEach(Array(store.quickMinutes.enumerated()), id: \.offset) { index, minutes in
                    Button {
                        screenVM.mainMinutes = minutes
                        screenVM.mainSeconds = 0
                    } label: {
                        Text(String(localized: "\(minutes) min"))
                            .font(DSFont.callout.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected(minutes) ? Color.accentColor : .gray)
                    .accessibilityLabel(String(localized: "\(minutes) minutes"))
                    .accessibilityHint(String(localized: "Double tap to set. Touch and hold to edit this preset."))
                    .accessibilityAddTraits(isSelected(minutes) ? [.isSelected] : [])
                    .onLongPressGesture {
                        editTarget = EditTarget(id: index)
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(item: $editTarget) { target in
            TimePresetEditorSheet(
                title: "Edit Quick Setup",
                showSeconds: false,
                initialSeconds: store.quickMinutes[target.id] * 60
            ) { totalSeconds in
                store.setQuickMinutes(totalSeconds / 60, at: target.id)
            }
            .presentationDetents([.height(320)])
        }
    }

    private func isSelected(_ minutes: Int) -> Bool {
        return screenVM.mainMinutes == minutes && screenVM.mainSeconds == 0
    }
}
