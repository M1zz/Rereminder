//
//  TroubleshootingView.swift
//  Rereminder
//
//  설정 ▸ 문제가 있나요? 증상을 고르면 해 볼 일이 순서대로 나온다.
//
//  ⚠️ 해 볼 일에는 사용자가 지금 바꿀 수 있는 것만 적는다.
//  ⚠️ 설정 이름은 그 화면의 실제 문구와 같아야 한다. 화면 이름을 바꾸면 여기도 고칠 것.
//

import SwiftUI

struct TroubleshootingView: View {
    let onSendFeedback: () -> Void

    private struct Problem: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let symbol: String
        let steps: [LocalizedStringKey]
        var opensNotificationSettings = false
    }

    private let problems = [
        Problem(id: "watch",
                title: "My Apple Watch doesn't vibrate",
                symbol: "applewatch",
                steps: [
                    "A timer started on iPhone reaches your wrist only while iPhone is locked. Press the side button after starting, or start the timer on your Apple Watch.",
                    "On iPhone, open the Watch app, go to Notifications, and check that Rereminder is allowed.",
                    "In Settings on your Apple Watch, check that haptic alerts are on.",
                ]),
        Problem(id: "notifications",
                title: "Alerts don't arrive when the screen is off",
                symbol: "bell.slash",
                steps: [
                    "Check that notifications are allowed for Rereminder.",
                    "If a Focus is on, add Rereminder to its allowed apps.",
                ],
                opensNotificationSettings: true),
        Problem(id: "sound",
                title: "I can't hear the alert",
                symbol: "speaker.slash",
                steps: [
                    "Silent Mode mutes alert sounds. Check the switch and the volume.",
                    "To ring through Silent Mode and Focus, turn on the full alarm in this app's Settings.",
                ]),
        Problem(id: "pro",
                title: "My purchase isn't showing",
                symbol: "creditcard",
                steps: [
                    "Open the Pro screen and restore your purchases, signed in to the Apple Account you bought with.",
                ]),
    ]

    var body: some View {
        List {
            ForEach(problems) { problem in
                DisclosureGroup {
                    ForEach(Array(problem.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(verbatim: "\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text(step)
                                .font(.callout)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if problem.opensNotificationSettings {
                        Button("Open Settings", action: openNotificationSettings)
                    }
                } label: {
                    Label(problem.title, systemImage: problem.symbol)
                }
            }

            Section(footer: Text("Still not working? Tell us which device you started the timer on and what you expected.")) {
                Button("Send Feedback", action: onSendFeedback)
            }
        }
        .navigationTitle("Having a problem?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
