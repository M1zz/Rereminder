//
//  TimePresetButtons.swift
//  Rereminder
//
//  Created for usability improvements
//

import SwiftUI

struct TimePresetButtons: View {
    @ObservedObject var screenVM: TimerScreenViewModel
    var onShowTimeInput: () -> Void = {}

    private let presets = [5, 10, 15, 20, 30]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Quick Setup")
                .font(DSFont.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, DSSpacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    ForEach(presets, id: \.self) { minutes in
                        Button(action: {
                            screenVM.mainMinutes = minutes
                            screenVM.mainSeconds = 0
                        }) {
                            Text(String(localized: "\(minutes) min"))
                                .font(DSFont.callout.weight(.medium))
                                .padding(.horizontal, DSSpacing.md)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(isSelected(minutes) ? Color.accentColor : .gray)
                        .accessibilityLabel(String(localized: "\(minutes) minutes"))
                        .accessibilityAddTraits(isSelected(minutes) ? [.isSelected] : [])
                    }

                    // Custom 입력 버튼
                    Button(action: onShowTimeInput) {
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: "plus.circle.fill")
                            Text("Custom")
                                .font(DSFont.callout.weight(.medium))
                        }
                        .padding(.horizontal, DSSpacing.md)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                    .accessibilityLabel(String(localized: "Enter time manually"))
                }
                .padding(.horizontal, DSSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isSelected(_ minutes: Int) -> Bool {
        return screenVM.mainMinutes == minutes && screenVM.mainSeconds == 0
    }
}
