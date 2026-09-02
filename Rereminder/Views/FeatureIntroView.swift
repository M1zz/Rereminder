//
//  FeatureIntroView.swift
//  Rereminder
//
//  **"이런 것도 있어요"** — 사용자가 요청한 기능이 이미 있는데 못 찾는 문제를 푸는 화면.
//
//  왜 필요한가: 들어온 제보 셋이 전부 "이런 게 있으면 좋겠다"였는데, 그중 둘은 **이미 있는
//  기능**이었다("끝날 때까지 반복해서 알려 줬으면", "다이얼 돌릴 때 진동이 있으면").
//  설정 > 알림 깊숙한 곳에 스위치로 놓여 있으면, 그게 필요하다고 느끼는 사람조차 있는 줄 모른다.
//
//  그래서 이 화면은 **안내이면서 동시에 설정**이다. 각 항목이 무엇을 해 주는지 한 문장으로
//  말하고, 켜는 스위치를 바로 그 자리에 둔다 — 읽고 나서 설정을 다시 찾아 들어가게 만들면
//  거기서 절반이 떨어진다.
//
//  ⚠️ **자동으로 띄우지 않는다.** 이 앱에는 이미 양보 순서를 지키는 안내가 여럿 있고
//     (기기 질문·피드백 넛지·반복 감지·창단 후원자·다음 자리 예약), 거기에 하나를 더 얹으면
//     앱을 열자마자 무언가가 뜨는 앱이 된다. 여기는 **찾아오면 있는 자리**다.
//

import SwiftUI

struct FeatureIntroView: View {

    @AppStorage(Haptics.enabledKey) private var hapticsEnabled: Bool = true
    @AppStorage(RereminderAlarmManager.enabledKey) private var useAlarmKit: Bool = false
    @AppStorage("alertRepeatInterval") private var repeatInterval: AlertRepeatInterval = .off
    @AppStorage("alertRepeatDuration") private var repeatDuration: AlertRepeatDuration = .twoMinutes
    @AppStorage("alertEscalateAcrossDevices") private var escalatesAcrossDevices: Bool = false

    @State private var showAlarmPermissionDenied = false

    var body: some View {
        List {
            Section {
                Text("Rereminder can do a few things most people never find. Turn on what you need — it all takes effect right here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: DSSpacing.sm,
                                              leading: DSSpacing.xs,
                                              bottom: DSSpacing.lg,
                                              trailing: DSSpacing.xs))
            }

            // ── 끝까지 알린다 (되풀이)
            Section {
                FeatureHeader(symbol: "bell.and.waves.left.and.right.fill",
                              title: String(localized: "Keep alerting until I answer"),
                              detail: String(localized: "One buzz is easy to miss. Rereminder repeats the end alert until you tap Stop or Snooze."))

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
            }

            // ── 알람으로 깨운다
            Section {
                // ⚠️ 제목과 토글 문구가 같으면 같은 줄이 두 번 있는 것처럼 보인다 —
                //    제목은 **"언제 나에게 필요한가"**, 토글은 기능 이름으로 갈라 둔다
                //    (다른 두 카드도 같은 규칙이다).
                FeatureHeader(symbol: "alarm.waves.left.and.right.fill",
                              title: String(localized: "Impossible to ignore"),
                              detail: String(localized: "For breaks you keep skipping. Your iPhone rings at alarm volume - through Silent Mode and Focus - and does not stop until you get up and press Stop."))

                Toggle(String(localized: "End with a full alarm"), isOn: $useAlarmKit)
                    .onChange(of: useAlarmKit) { _, isOn in
                        guard isOn else {
                            RereminderAlarmManager.shared.cancelFinishAlarm()
                            return
                        }
                        Task { @MainActor in
                            if await RereminderAlarmManager.shared.requestAuthorization() == false {
                                useAlarmKit = false
                                showAlarmPermissionDenied = true
                            }
                        }
                    }
            } footer: {
                if useAlarmKit {
                    Text("Leave this off in quiet places - it ignores Silent Mode on purpose.")
                }
            }

            // ── 손끝의 딸깍
            Section {
                FeatureHeader(symbol: "hand.draw.fill",
                              title: String(localized: "Feel the dial"),
                              detail: String(localized: "A small tick every time the dial passes a step, so you can set the time without watching your finger."))

                Toggle(String(localized: "Haptics while adjusting"), isOn: $hapticsEnabled)
            }
        }
        .navigationTitle(Text("Things you might not know"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Alarm permission needed", isPresented: $showAlarmPermissionDenied) {
            Button("Open Settings", action: openSettings)
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow alarms for Rereminder in Settings to use the full alarm.")
        }
    }

    /// 워치도 같은 설정을 봐야 한다 — 설정 화면(`PersistentAlertSection`)과 같은 규칙이다.
    private func syncToWatch() {
        WatchConnectivityManager.shared.sendEscalationPolicy(EscalationPolicy.current())
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - 한 항목의 머리글

/// 아이콘 + 이름 + **한 문장의 "그래서 뭐가 좋아지나"**.
/// ⚠️ 설명에 기능 이름을 되풀이하지 말 것 — 이 줄이 답해야 하는 것은 "언제 나에게 필요한가"다.
private struct FeatureHeader: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(DSColor.accent)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(verbatim: title)
                    .font(.headline)
                Text(verbatim: detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
