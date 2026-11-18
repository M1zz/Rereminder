//
//  DialAlertLine.swift
//  Rereminder
//
//  다이얼 아래 전부 — 지금 설정을 말하는 문장 하나와 버튼 하나.
//
//  조작은 세 가지뿐이다: 링의 빈 자리를 두 번 눌러 더하기, 종을 끌어 옮기기, 종을 두 번 눌러 지우기(되돌리기가 잠깐 뜬다).
//  ⚠️ `+ 알림 추가` 버튼은 지웠다 — 되살리지 말 것. 누른 자리가 곧 시각이라 버튼이 고르는 "다음 시간"보다 빠르다.
//  두 손짓 모두 화면에 보이지 않아서, 버튼 자리에 한 줄로 말한다(더하기는 한 번 해 볼 때까지, 지우기는 종을 만진 직후 4초).
//  문장은 두 줄이다: "시작 9:40 이후에 알려 줘요" / "종료 19:20 전에 알려 줘요". 같은 종은 같은 색이다.
//  "시작"은 노랑, "종료"는 빨강이다(`tinted`). 강조색(파랑)은 첫 구간 색과 같아 종으로 읽혀서 쓰지 않는다.
//  ⚠️ 칩을 다시 늘어놓지 말 것. 종이 이미 알림을 보여 주고 조작까지 받는데 같은 일을 하는 칩이 또 있어서 화면이 복잡했다.
//  ⚠️ 문장과 버튼 자리는 지우기 전후가 같다. 되돌리기가 떠도 원 아래가 흔들리면 안 된다.
//

import SwiftUI

struct DialAlertLine: View {
    @ObservedObject var screenVM: TimerScreenViewModel
    /// 끌고 있는 종까지 반영한 알림들. 문장은 손가락을 따라 바뀐다(`TimerMainView.liveOffsets`).
    let liveOffsets: Set<Int>

    /// 종을 한 번이라도 탭해 지워 봤나. 그 뒤로는 지우는 법을 말하지 않는다.
    @AppStorage("dialAlert.hasRemovedBell") private var hasRemovedBell = false
    /// 링을 두 번 눌러 알림을 더해 봤나. 그 전까지는 버튼 자리에 더하는 법을 적어 둔다.
    @AppStorage("dialAlert.hasAddedBell") private var hasAddedBell = false
    /// 종을 더하거나 옮긴 직후 잠깐 "탭하면 지워진다"를 말한다. 지우는 길이 화면에 보이지 않아 다들 막혔다.
    @State private var removeHintToken = 0

    private var totalSeconds: Int { screenVM.mainMinutes * 60 + screenVM.mainSeconds }

    /// 먼저 울리는 것부터. 총 시간 밖의 종(끄는 중 잠깐)은 뺀다.
    private var firingOrder: [Int] { liveOffsets.filter { $0 < totalSeconds }.sorted(by: >) }

    /// 첫 줄 — 같은 종을 **시작하고 몇 분 뒤**로 읽는다. "시작 9:40 이후에 알려 줘요"
    /// 발표자는 "몇 분째 말하고 있나"와 "몇 분 남았나"를 둘 다 안다. 색은 둘째 줄의 같은 종과 같다.
    private var startLine: AttributedString {
        let offsets = firingOrder
        guard !offsets.isEmpty else { return AttributedString(String(localized: "No alerts")) }
        return Self.tinted(sentence(offsets.map { ($0, totalSeconds - $0) }) { String(localized: "Alerts you \($0) after the start") },
                           word: String(localized: "dial.startWord", defaultValue: "start"), color: Self.startColor)
    }

    /// 둘째 줄 — 끝나기 **몇 분 전**인가. "종료 19:20 전에 알려 줘요"
    private var endLine: AttributedString? {
        let offsets = firingOrder
        guard !offsets.isEmpty else { return nil }
        return Self.tinted(sentence(offsets.map { ($0, $0) }) { String(localized: "Alerts you \($0) before the end") },
                           word: String(localized: "dial.endWord", defaultValue: "end"), color: DSColor.negative)
    }

    /// (종, 문장에 쓸 초) 목록을 한 문장으로. 시간만 나열하고 "시작 … 이후"·"종료 … 전"은 문장이 한 번 말한다.
    /// 셋까지만 적고 나머지는 +N.
    private func sentence(_ items: [(bell: Int, seconds: Int)], format: (String) -> String) -> AttributedString {
        let shown = Array(items.prefix(3))
        let times = shown.map { Self.unbrokenTime($0.seconds) }
        let list = times.joined(separator: ", ") + (items.count > 3 ? " +\(items.count - 3)" : "")
        return Self.emphasized(format(list),
                               items: shown.enumerated().map { index, item in
                                   Emphasis(label: times[index], time: times[index],
                                            color: SectionPalette.color(AlertPresets.bellSectionIndex(
                                                of: item.bell, among: liveOffsets)))
                               })
    }

    /// 시작 낱말의 색. 구간 색(파랑·초록·보라…)과 겹치지 않는 노랑이고, 밝은 화면에서는 읽히게 진하다.
    private static let startColor = Color(UIColor { $0.userInterfaceStyle == .dark
        ? .systemYellow
        : UIColor(red: 0.62, green: 0.45, blue: 0.0, alpha: 1) })

    /// "시작"·"종료" 낱말을 칠한다 — 시작은 노랑(구간 색과 겹치지 않게), 종료는 끝날 때 올라오는 빨간 버튼의 색.
    /// 낱말은 언어마다 문장 속 모양 그대로 카탈로그에 있다(`dial.startWord`·`dial.endWord`). 못 찾으면 그대로 둔다.
    private static func tinted(_ text: AttributedString, word: String, color: Color) -> AttributedString {
        var text = text
        if !word.isEmpty, let range = text.range(of: word) {
            text[range].foregroundColor = color.onGlass
            text[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return text
    }

    struct Emphasis {
        let label: String
        let time: String
        let color: Color
    }

    /// 시간 하나가 두 줄로 갈리지 않게 안쪽 공백을 줄바꿈 없는 공백으로 쓴다
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
                text[timeRange].foregroundColor = item.color.onGlass
            }
            searchStart = labelRange.upperBound
        }
        return text
    }

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            VStack(spacing: DSSpacing.xs) {
                Text(screenVM.justRemovedAlert.map {
                    let label = AlertPresets.label($0)
                    return Self.emphasized(String(localized: "Removed: \(label)"),
                                           items: [Emphasis(label: label, time: AlertPresets.timePart($0), color: .primary)])
                } ?? startLine)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if let endLine {
                    Text(endLine)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            // ⚠️ 줄 수를 막지 않는다. 알림이 셋이면 기본 글자 크기에서도 두 줄이 차서, 글자를 키우면 뒤의 알림이 잘렸다.
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 48)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)

            // 버튼 자리 — 되돌리기가 뜨거나, 손짓을 한 줄로 말하거나, 비어 있다. 높이는 언제나 같다.
            ZStack {
                if let removed = screenVM.justRemovedAlert {
                    actionButton(title: String(localized: "Undo"), symbol: "arrow.uturn.backward") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            _ = screenVM.selectedOffsets.insert(removed)
                            screenVM.justRemovedAlert = nil
                        }
                    }
                } else if let hint {
                    Text(hint)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            .frame(minHeight: 34)
        }
        .padding(.horizontal)
        // 원 아래 자리는 정해져 있다. 가장 큰 글자에서는 세 알림 문장이 버튼을 덮었다 —
        // 가운데 시간(`TimerMainView`)과 같은 상한을 두고, 그 안에서는 줄이 필요한 만큼 내려간다.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // 사람이 종을 끌 때만(끄는 동안은 `liveOffsets` 가 저장값과 다르다). 앱이 설정을 되살릴 때는 말하지 않는다.
        .onChange(of: liveOffsets) { _, live in
            if live != screenVM.selectedOffsets { showRemoveHint() }
        }
        .onChange(of: screenVM.lastAddedAlert) { _, added in
            guard added != nil else { return }
            hasAddedBell = true
            showRemoveHint()
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

    /// 화면에 보이지 않는 손짓 둘을 한 줄로 말한다. 더하는 법은 한 번 해 볼 때까지 늘, 지우는 법은 종을 만진 직후 4초.
    private var hint: String? {
        if removeHintToken > 0 { return String(localized: "Double-tap a bell to remove it.") }
        if !hasAddedBell { return String(localized: "Double-tap the ring to add an alert.") }
        return nil
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

    private func showRemoveHint() {
        guard !hasRemovedBell else { return }
        withAnimation(.easeInOut(duration: 0.2)) { removeHintToken += 1 }
    }
}
