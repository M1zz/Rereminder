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
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Setup")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { minutes in
                        Button(action: {
                            screenVM.mainMinutes = minutes
                            screenVM.mainSeconds = 0
                        }) {
                            Text(String(localized: "\(minutes) min"))
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(isSelected(minutes) ? Color.accentColor : .gray)
                    }

                    // Custom 입력 버튼
                    Button(action: onShowTimeInput) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Custom")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.accentColor)
                }
                .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isSelected(_ minutes: Int) -> Bool {
        return screenVM.mainMinutes == minutes && screenVM.mainSeconds == 0
    }
}
