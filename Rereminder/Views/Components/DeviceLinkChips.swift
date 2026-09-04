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
//   • **글자 없이 심볼만.** 연결됨은 초록 심볼, 안 됨은 빗금(slash) 심볼 + 회색.
//     "Not connected" 라는 문장은 화면 아래 절반에서 가장 눈에 띄는 실패 문구가 됐고,
//     빗금 심볼이 이미 같은 말을 한다. 무엇을 하면 되는지는 눌러서 여는 안내가 답한다.
//     ⚠️ 글자를 다시 붙이지 말 것 — 접근성 라벨(VoiceOver)에는 그대로 남아 있다.
//   • ⚠️ **채운 캡슐을 다시 씌우지 말 것.** 예전에는 회색 캡슐 두 개가 각각 "연결 안 됨"을
//     외쳐서, 화면 아래 절반에서 **가장 눈에 띄는 것이 실패 문구**였다. 이 줄은 상태 표시지
//     행동을 부르는 버튼이 아니다 — 심볼만, 배경은 없다.
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

    /// 칩 안쪽 높이 — 두 칩의 키를 같게 맞춘다.
    /// (글자 크기 설정을 키우면 이 값도 같이 커지되, 아래 심볼 상한만큼만 커진다)
    @ScaledMetric(relativeTo: .caption) private var chipContentHeight: CGFloat = 16

    /// ⚠️ 심볼도 **상한을 둔다.** 접근성 크기에서 끝없이 커지면 두 칩이 서로 겹친다.
    ///    칩은 보조 정보다 — 주인공은 원 안의 시간이다.
    private let symbolBase: CGFloat = 13
    private let symbolMax: CGFloat = 21

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
            // 심볼만 서므로 폭 걱정이 없다 — 예전의 `ViewThatFits`(글자가 잘릴 때 세로로 쌓기)는
            // 더 이상 필요하지 않다.
            HStack(spacing: DSSpacing.lg) {
                chips
            }
            .sheet(item: $helpDevice) { device in
                DeviceConnectionHelpView(device: device)
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
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
        Image(systemName: symbol)
            .dsScaledFont(symbolBase, weight: .semibold,
                          relativeTo: .footnote, maxSize: symbolMax)
            // ⚠️ 고정 높이(frame(height:))로 두면 심볼이 커질 때 잘린다.
            //    최소 높이로 두어야 두 칩의 키를 맞추면서도 자랄 수 있다.
            .frame(minHeight: chipContentHeight)
            .foregroundStyle(isConnected ? Color.green : Color.secondary)
            .contentShape(Rectangle())
            // 글자가 없어도 VoiceOver 는 기기 이름과 연결 여부를 그대로 읽는다.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(deviceName))
            .accessibilityValue(Text(isConnected ? "Connected" : "Not connected"))
            .accessibilityHint(Text("Shows how to connect this device"))
            .accessibilityAddTraits(.isButton)
    }
}
