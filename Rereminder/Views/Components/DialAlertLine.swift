//
//  DialAlertLine.swift
//  Rereminder
//
//  다이얼 아래 전부 — 지금 설정을 말하는 문장 하나와 버튼 하나.
//
//  조작은 세 가지뿐이다: `+` 로 더하기, 링의 종을 끌어 옮기기, 종을 탭해 지우기(되돌리기가 잠깐 뜬다).
//  지우는 법은 화면에 보이지 않아서, 한 번 지워 보기 전까지는 종을 더하거나 옮길 때마다 4초 동안 한 줄로 말한다.
//  ⚠️ 칩을 다시 늘어놓지 말 것. 종이 이미 알림을 보여 주고 조작까지 받는데 같은 일을 하는 칩이 또 있어서 화면이 복잡했다.
//  ⚠️ 문장과 버튼 자리는 지우기 전후가 같다. 되돌리기가 떠도 원 아래가 흔들리면 안 된다.
//

import SwiftUI

struct DialAlertLine: View {
    @ObservedObject var screenVM: TimerScreenViewModel
    /// 끌고 있는 종까지 반영한 알림들. 문장은 손가락을 따라 바뀐다(`TimerMainView.liveOffsets`).
    let liveOffsets: Set<Int>

    @AppStorage(AlertPresets.storageKey) private var presetsRaw = AlertPresets.defaultRaw
    /// 종을 한 번이라도 탭해 지워 봤나. 그 뒤로는 지우는 법을 말하지 않는다.
    @AppStorage("dialAlert.hasRemovedBell") private var hasRemovedBell = false
    /// 종을 더하거나 옮긴 직후 잠깐 "탭하면 지워진다"를 말한다. 지우는 길이 화면에 보이지 않아 다들 막혔다.
    @State private var removeHintToken = 0

    private var totalSeconds: Int { screenVM.mainMinutes * 60 + screenVM.mainSeconds }

    private var summary: AttributedString {
        // 먼저 울리는 것부터 읽는다
        let offsets = liveOffsets.sorted(by: >)
        guard !offsets.isEmpty else { return AttributedString(String(localized: "No alerts")) }
        let shown = Array(offsets.prefix(3))
        let list = shown.map(Self.unbroken).joined(separator: ", ")
            + (offsets.count > 3 ? " +\(offsets.count - 3)" : "")
        return Self.emphasized(String(localized: "Alerts you \(list)"),
                               items: shown.enumerated().map { index, seconds in
                                   Emphasis(label: Self.unbroken(seconds), time: Self.unbrokenTime(seconds),
                                            color: SectionPalette.color(index))
                               })
    }

    struct Emphasis {
        let label: String
        let time: String
        let color: Color
    }

    /// 시간 하나가 두 줄로 갈리지 않게 안쪽 공백을 줄바꿈 없는 공백으로 쓴다
    private static func unbroken(_ seconds: Int) -> String {
        AlertPresets.label(seconds).replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    private static func unbrokenTime(_ seconds: Int) -> String {
        AlertPresets.timePart(seconds).replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    /// **시간만** 굵게, 그 종의 색으로. 번역마다 어순이 달라 문장 안에서 찾아 칠한다.
    /// ⚠️ 앞에서부터 이어서 찾는다. 처음부터 찾으면 "1분 전"이 "11분 전" 안에 걸린다.
    /// 시간 표기가 라벨 번역과 다르면 숫자만 칠한다.
    static func emphasized(_ sentence: String, items: [Emphasis]) -> AttributedString {
        var text = AttributedString(sentence)
        var searchStart = text.startIndex
        for item in items {
            guard let labelRange = text[searchStart...].range(of: item.label) else { continue }
            let digits = item.time.prefix { $0.isNumber || $0 == ":" }
            let timeRange = text[labelRange].range(of: item.time) ?? text[labelRange].range(of: String(digits))
            if let timeRange {
                text[timeRange].inlinePresentationIntent = .stronglyEmphasized
                text[timeRange].foregroundColor = item.color
            }
            searchStart = labelRange.upperBound
        }
        return text
    }

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            Text(screenVM.justRemovedAlert.map {
                let label = AlertPresets.label($0)
                return Self.emphasized(String(localized: "Removed: \(label)"),
                                       items: [Emphasis(label: label, time: AlertPresets.timePart($0), color: .primary)])
            } ?? summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                // ⚠️ 줄 수를 막지 않는다. 알림이 셋이면 기본 글자 크기에서도 두 줄이 차서, 글자를 키우면 뒤의 알림이 잘렸다.
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 48)
                .accessibilityAddTraits(.updatesFrequently)

            if removeHintToken > 0, screenVM.justRemovedAlert == nil {
                Text(String(localized: "Double-tap a bell to remove it."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            if let removed = screenVM.justRemovedAlert {
                actionButton(title: String(localized: "Undo"), symbol: "arrow.uturn.backward") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = screenVM.selectedOffsets.insert(removed)
                        screenVM.justRemovedAlert = nil
                    }
                }
            } else {
                actionButton(title: String(localized: "Add alert"), symbol: "plus", action: addNext)
                    .accessibilityHint(String(localized: "Adds the next suggested alert time."))
            }
        }
        .padding(.horizontal)
        // 원 아래 자리는 정해져 있다. 가장 큰 글자에서는 세 알림 문장이 버튼을 덮었다 —
        // 가운데 시간(`TimerMainView`)과 같은 상한을 두고, 그 안에서는 줄이 필요한 만큼 내려간다.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // 사람이 종을 끌 때만(끄는 동안은 `liveOffsets` 가 저장값과 다르다). 앱이 설정을 되살릴 때는 말하지 않는다.
        .onChange(of: liveOffsets) { _, live in
            if live != screenVM.selectedOffsets { showRemoveHint() }
        }
        .task(id: removeHintToken) {
            guard removeHintToken > 0 else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.3)) { removeHintToken = 0 }
        }
        .task(id: screenVM.justRemovedAlert) {
            guard screenVM.justRemovedAlert != nil else { return }
            hasRemovedBell = true
            removeHintToken = 0
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) { screenVM.justRemovedAlert = nil }
        }
    }

    private func actionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .frame(minHeight: 34)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(DSColor.marker)
    }

    /// **개수 한도는 없다** — 게이트를 다시 끼워 넣지 말 것(`ProGate` 머리말).
    private func addNext() {
        guard let next = AlertPresets.nextAlert(totalSeconds: totalSeconds, presetsRaw: presetsRaw,
                                                selected: screenVM.selectedOffsets) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            _ = screenVM.selectedOffsets.insert(next)
        }
        showRemoveHint()
    }

    private func showRemoveHint() {
        guard !hasRemovedBell else { return }
        withAnimation(.easeInOut(duration: 0.2)) { removeHintToken += 1 }
    }
}
