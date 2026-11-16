//
//  PhoneSetupListView.swift
//  RereminderWatch
//
//  아이폰에서 맞춘 설정 목록(`PhoneSetups`). 고르면 알림 화면이 그 값으로 채워진 채 열리고,
//  거기서 종을 더하거나 빼고 시작한다. 맨 위는 아이폰 다이얼에 지금 맞춰 둔 설정이다.
//

import SwiftUI

struct PhoneSetupListView: View {
    let setups: [PhoneSetup]
    @Binding var path: [NavigationTarget]

    var body: some View {
        List(setups) { setup in
            Button {
                if let rounds = setup.rounds, rounds > 1 {
                    // 반복은 아이폰에서 맞춘 그대로 건다 — 알림 화면에서 고칠 수 없는 값이다
                    path.append(.timerViewRounds(mainDuration: setup.mainSeconds,
                                                 prealertOffsets: setup.offsets, rounds: rounds))
                } else {
                    path.append(.phoneSetup(setup))
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(setup))
                        .font(.headline)
                        .lineLimit(2)
                    Text(detail(setup))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, DSSpacing.xs)
            }
        }
        .navigationTitle(Text("From iPhone"))
    }

    private func title(_ setup: PhoneSetup) -> String {
        if setup.isCurrentDial { return String(localized: "iPhone dial") }
        return setup.name.isEmpty ? TimeModel.clock(setup.mainSeconds) : setup.name
    }

    private func detail(_ setup: PhoneSetup) -> String {
        var clock = TimeModel.clock(setup.mainSeconds)
        if let rounds = setup.rounds, rounds > 1 { clock += " × \(rounds)" }
        guard !setup.offsets.isEmpty else { return clock }
        return "\(clock) \(String(localized: "· \(setup.offsets.count) alerts"))"
    }
}

private extension TimeModel {
    /// 25:00, 1:30:00
    static func clock(_ seconds: Int) -> String {
        let t = TimeModel.fromSecond(seconds)
        if t.hour > 0 { return String(format: "%d:%02d:%02d", t.hour, t.minute, t.second) }
        return String(format: "%d:%02d", t.minute, t.second)
    }
}
