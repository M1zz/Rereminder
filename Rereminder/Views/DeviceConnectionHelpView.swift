//
//  DeviceConnectionHelpView.swift
//  Rereminder
//
//  "연결 안 됨"을 눌렀을 때 나오는 **무엇을 하면 되는지** 안내.
//
//  상태만 보여주고 끝내면 사용자는 "그래서 어쩌라고"에서 막힌다. 이 화면은 세 가지를 한다:
//   ① 지금 상태를 그대로 말해 주고 ② 순서대로 할 일을 알려 주고 ③ 그 자리에서 다시 확인한다.
//
//  ⚠️ 상태 판정은 여기서 하지 않는다 — 워치는 `WatchConnectivityManager.linkStatus`,
//     맥은 `DevicePresence`가 답한다. 화면은 받은 것만 그린다.
//  ⚠️ 맥의 "연결됨"은 실시간 연결이 아니라 **최근에 그 맥에서 앱이 켜져 있었다**는 뜻이다.
//     그래서 안내 아래에 그 뜻을 반드시 적어 둔다 — 안 그러면 "켜 뒀는데 왜 안 뜨지"가 된다.
//

import SwiftUI

struct DeviceConnectionHelpView: View {
    let device: DeviceOwnership.Device

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var watchLink = WatchConnectivityManager.shared
    @State private var macStatus: DevicePresence.Status = .away(lastSeen: nil)

    var body: some View {
        NavigationStack {
            List {
                statusSection
                stepsSection
                moreSection
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: refresh)
        }
    }

    // MARK: - 지금 상태

    private var statusSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isConnected ? Color.green : Color.secondary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.body.weight(.semibold))
                    if let detail = statusDetail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)

            Button {
                refresh()
            } label: {
                Label("Check again", systemImage: "arrow.clockwise")
            }
        } header: {
            Text("Status")
        }
    }

    // MARK: - 할 일

    private var stepsSection: some View {
        Section {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(verbatim: "\(index + 1)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.accentColor))
                    Text(step)
                        .font(.callout)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Try this")
        } footer: {
            if device == .mac {
                Text("\"Connected\" here means Rereminder was open on that Mac within the last 10 minutes — it isn't a live link.")
            }
        }
    }

    private var moreSection: some View {
        Section {
            NavigationLink {
                MultiDeviceGuideView()
            } label: {
                Label("Use on All Your Devices", systemImage: "square.stack.3d.up.fill")
            }
        }
    }

    // MARK: - 기기별 내용

    private var title: LocalizedStringKey {
        device == .watch ? "Connect your Apple Watch" : "Connect your Mac"
    }

    private var symbol: String {
        switch device {
        case .watch: return isConnected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash"
        case .mac:   return isConnected ? "laptopcomputer" : "laptopcomputer.slash"
        }
    }

    private var isConnected: Bool {
        switch device {
        case .watch:
            return watchLink.linkStatus == .connected
        case .mac:
            if case .connected = macStatus { return true }
            return false
        }
    }

    private var statusText: LocalizedStringKey {
        guard device == .watch else { return isConnected ? "Connected" : "Not connected" }
        switch watchLink.linkStatus {
        case .connected:       return "Connected"
        case .appNotInstalled: return "The app isn't installed on your Apple Watch"
        case .notPaired:       return "No Apple Watch is paired with this iPhone"
        case .notReachable,
             .unavailable:     return "Not connected"
        }
    }

    /// 맥은 마지막으로 켜져 있던 때를, 워치는 연결된 기기 이름을 보조로 보여준다.
    private var statusDetail: String? {
        switch macStatus {
        case .connected(let name):
            return device == .mac && !name.isEmpty ? name : nil
        case .away(let lastSeen):
            guard device == .mac, let lastSeen else { return nil }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return String(format: String(localized: "Last active %@"),
                          formatter.localizedString(for: lastSeen, relativeTo: Date()))
        }
    }

    /// 순서대로 하면 되는 일. **하나라도 빠지면 연결이 안 되는 것들만** 적는다.
    private var steps: [LocalizedStringKey] {
        switch device {
        case .watch:
            return [
                "Wear your Apple Watch and keep it near this iPhone.",
                "On iPhone, open the Watch app → My Watch, and install Rereminder if it isn't there.",
                "Open Rereminder on your Apple Watch — the remaining time appears while a timer runs.",
                "If it still doesn't connect, check that Bluetooth and Wi-Fi are on for both devices.",
            ]
        case .mac:
            return [
                "Install Rereminder on your Mac from the App Store.",
                "Sign in to the same Apple Account on both devices and turn on iCloud Drive.",
                "Open Rereminder on your Mac — the remaining time appears in the menu bar.",
            ]
        }
    }

    private func refresh() {
        watchLink.refreshLinkStatus()
        NSUbiquitousKeyValueStore.default.synchronize()
        macStatus = DevicePresence.status(of: .mac)
    }
}
