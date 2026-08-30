//
//  DeviceLinkChips.swift
//  Rereminder
//
//  타이머가 도는 동안 원 아래에 서는 **기기 연결 상태 칩**.
//
//  왜 여기에도 두나: 설정 화면에만 있으면 아무도 안 본다. 정작 알아야 할 때는 타이머를 막 걸었을
//  때다 — "손목에서도 볼 수 있나?"가 그 순간의 질문이고, 안 되면 지금 연결해야 한다는 걸
//  깨달아야 한다.
//
//  규칙
//   • **있다고 답한 기기만** 나온다(설정 > 내 기기). 없는 기기의 연결 상태는 소음일 뿐이다.
//   • 안 될 때만 말을 건다 — 연결 안 됨은 심볼 + 글자, 연결됨은 초록 심볼만.
//     잘 되고 있을 때까지 문장으로 떠들면 다음부터 아무도 안 읽는다.
//   • ⚠️ **채운 캡슐을 다시 씌우지 말 것.** 예전에는 회색 캡슐 두 개가 각각 "연결 안 됨"을
//     외쳐서, 화면 아래 절반에서 **가장 눈에 띄는 것이 실패 문구**였다. 이 줄은 상태 표시지
//     행동을 부르는 버튼이 아니다 — 글자는 secondary, 배경은 없다.
//   • 워치 상태는 `WatchConnectivityManager.linkStatus`(실시간), 맥은 `DevicePresence`
//     (iCloud에 남긴 표시 — "최근에 켜져 있었다")가 답한다.
//   • **누르면 무엇을 하면 되는지 알려 준다**(`DeviceConnectionHelpView`).
//     "연결 안 됨"만 보여주고 끝내면 "그래서 어쩌라고"에서 막힌다.
//

import SwiftUI

struct DeviceLinkChips: View {
    let watchStatus: WatchLinkStatus
    let macStatus: DevicePresence.Status

    // ⚠️ 키 문자열은 DeviceOwnership.answerKey 와 같아야 한다(@AppStorage 는 리터럴만 받는다).
    @AppStorage("device.owns.watch") private var watchOwnershipRaw = DeviceOwnership.Answer.unknown.rawValue
    @AppStorage("device.owns.mac") private var macOwnershipRaw = DeviceOwnership.Answer.unknown.rawValue

    /// 눌러서 연 안내 화면의 대상 기기.
    @State private var helpDevice: DeviceOwnership.Device?

    /// 칩 안쪽 높이 — **심볼만 있는 칩과 글자까지 있는 칩의 높이를 같게 맞춘다.**
    /// 그냥 두면 글자가 있는 쪽만 커져서 나란히 선 두 칩의 키가 달라 보인다.
    /// (글자 크기 설정을 키우면 이 값도 같이 커진다)
    @ScaledMetric(relativeTo: .caption) private var chipContentHeight: CGFloat = 16

    private var showsWatch: Bool {
        watchOwnershipRaw == DeviceOwnership.Answer.yes.rawValue && watchStatus != .unavailable
    }
    /// ⚠️ 맥에서 돌 때는 맥 칩을 띄우지 않는다 — 맥 앞에 앉은 사람에게 "Mac 연결 안 됨"은 헛소리다.
    ///    (`DevicePresence`가 자기 자신을 세지 않기 때문에 그대로 두면 늘 "연결 안 됨"으로 보인다.)
    private var showsMac: Bool {
        macOwnershipRaw == DeviceOwnership.Answer.yes.rawValue
            && DevicePresence.currentPlatform != .mac
    }

    var body: some View {
        if showsWatch || showsMac {
            HStack(spacing: DSSpacing.lg) {
                if showsWatch {
                    chipButton(device: .watch,
                               symbol: watchSymbol,
                               isConnected: watchStatus == .connected,
                               deviceName: "Apple Watch")
                }
                if showsMac {
                    chipButton(device: .mac,
                               symbol: macSymbol,
                               isConnected: isMacConnected,
                               deviceName: "Mac")
                }
            }
            .sheet(item: $helpDevice) { device in
                DeviceConnectionHelpView(device: device)
            }
        }
    }

    private func chipButton(device: DeviceOwnership.Device,
                            symbol: String,
                            isConnected: Bool,
                            deviceName: LocalizedStringKey) -> some View {
        Button {
            helpDevice = device
        } label: {
            chip(symbol: symbol, isConnected: isConnected, deviceName: deviceName)
        }
        .buttonStyle(.plain)
    }

    private var isMacConnected: Bool {
        if case .connected = macStatus { return true }
        return false
    }

    private var watchSymbol: String {
        watchStatus == .connected ? "applewatch.radiowaves.left.and.right" : "applewatch.slash"
    }

    private var macSymbol: String {
        isMacConnected ? "laptopcomputer" : "laptopcomputer.slash"
    }

    private func chip(symbol: String, isConnected: Bool, deviceName: LocalizedStringKey) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: symbol)
                .font(.caption.weight(.medium))
            // 잘 되고 있으면 심볼만 — 안 될 때만 이유를 적는다.
            if !isConnected {
                Text("Not connected")
                    .font(.caption2)
            }
        }
        .frame(height: chipContentHeight)
        .foregroundStyle(isConnected ? Color.green : Color.secondary)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(deviceName))
        .accessibilityValue(Text(isConnected ? "Connected" : "Not connected"))
        .accessibilityHint(Text("Shows how to connect this device"))
        .accessibilityAddTraits(.isButton)
    }
}
