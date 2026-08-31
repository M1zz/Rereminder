//
//  PersistentAlertSection.swift
//  Rereminder
//
//  설정 > 알림 의 **타이머가 끝나면** 구역 — "확인할 때까지 알림".
//
//  설계 배경은 `Shared/Modules/EscalatingAlert.swift` 와 CLAUDE.md 의 같은 이름 절을 볼 것.
//  ⚠️ 기본값은 **꺼짐**이다. 이 앱은 잔소리가 되는 순간 지워진다 — 켠 사람에게만 간다.
//

import SwiftUI

struct PersistentAlertSection: View {

    // ⚠️ 키 이름은 `EscalationPolicy` 의 저장 키와 **같아야** 한다 — 워치도 같은 키를 읽는다.
    @AppStorage("alertRepeatInterval") private var repeatInterval: AlertRepeatInterval = .off
    @AppStorage("alertRepeatDuration") private var repeatDuration: AlertRepeatDuration = .twoMinutes
    @AppStorage("alertEscalateAcrossDevices") private var escalatesAcrossDevices: Bool = false

    var body: some View {
        Section {
            Picker(String(localized: "Repeat the end alert"), selection: $repeatInterval) {
                ForEach(AlertRepeatInterval.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .onChange(of: repeatInterval) { _, _ in syncToWatch() }

            if repeatInterval != .off {
                Picker(String(localized: "Keep repeating"), selection: $repeatDuration) {
                    ForEach(AlertRepeatDuration.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .onChange(of: repeatDuration) { _, _ in syncToWatch() }
            }

            Toggle(String(localized: "Also alert my other devices"), isOn: $escalatesAcrossDevices)
                .onChange(of: escalatesAcrossDevices) { _, _ in syncToWatch() }
        } header: {
            Text("When the timer ends")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Keeps alerting until you tap Stop or Snooze on the notification.")
                if escalatesAcrossDevices {
                    Text("If your Apple Watch alerts first and you don't respond, this iPhone joins in after 30 seconds. Stopping on either device stops both.")
                }
            }
        }
    }

    /// 워치도 같은 설정을 봐야 한다 — 한쪽만 바뀌면 손목과 주머니가 다르게 운다.
    private func syncToWatch() {
        WatchConnectivityManager.shared.sendEscalationPolicy(EscalationPolicy.current())
    }
}
