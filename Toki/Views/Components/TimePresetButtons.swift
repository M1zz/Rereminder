//
//  TimePresetButtons.swift
//  Toki
//
//  Created for usability improvements
//

import SwiftUI

struct TimePresetButtons: View {
    @ObservedObject var screenVM: TimerScreenViewModel

    private let presets = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 설정")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { minutes in
                        Button(action: {
                            screenVM.mainMinutes = minutes
                            screenVM.mainSeconds = 0
                        }) {
                            Text("\(minutes)분")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(isSelected(minutes) ? Color.accentColor : .gray)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isSelected(_ minutes: Int) -> Bool {
        return screenVM.mainMinutes == minutes && screenVM.mainSeconds == 0
    }
}
