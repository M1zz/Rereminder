//
//  TimerActionBar.swift
//  Rereminder
//
//  원 아래에 서는 **동작 줄** — 시작 / 일시정지 / 재개 / 정지.
//
//  왜 다시 만들었나: 버튼이 원 **안**에 있던 시절에는 자리가 없어서 색깔 동그라미 두 개였다.
//  그 동그라미를 원 밖으로 그대로 옮겨 놓으니 화면에 뜬금없이 떠 있는 점 두 개가 됐다.
//  밖에는 자리가 있으니 버튼답게 생겨도 된다.
//
//  규칙
//   • **주 동작은 채운 캡슐 하나**(아이콘 + 글자). 지금 눌러야 할 것이 무엇인지 글자가 말한다 —
//     ▶ 하나만 있으면 "시작"인지 "재개"인지 아이콘으로 유추해야 한다.
//   • 색은 **테마 강조색**을 쓴다. 예전 시작 버튼은 분홍(`DSColor.positive`) 고정이라 파란 링
//     아래에서 혼자 튀었다. 링과 같은 색이어야 화면이 한 덩어리로 읽힌다.
//   • **주황은 쓰지 않는다** — 이 화면에서 주황은 알림 종의 색이다(`SectionPalette` 규칙).
//   • 정지는 곁들이 동작이라 회색 원 하나. 대기 중에는 아예 없다(정지할 게 없다).
//

import SwiftUI

struct TimerActionBar: View {
    let state: TimerState
    /// 발표 모드면 시작 버튼 글자가 "발표 시작"이 된다.
    var isPresentation: Bool = false
    /// 캡슐 높이. 원 크기를 따라간다.
    var height: CGFloat = 56

    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsCancel: Bool { state != .idle }

    /// 지금 캡슐에 들어갈 글자·심볼·동작.
    private var primary: (title: String, symbol: String, action: () -> Void) {
        switch state {
        case .idle, .finished:
            return (isPresentation ? String(localized: "Start Presentation") : String(localized: "Start"),
                    "play.fill", onStart)
        case .running, .overtime:
            return (String(localized: "Pause"), "pause.fill", onPause)
        case .paused:
            return (String(localized: "Resume"), "play.fill", onResume)
        }
    }

    /// 캡슐 폭을 정하는 글자들 — 이 상태에서 **나올 수 있는 모든 글자**.
    ///
    /// **일시정지 ↔ 재개를 오갈 때 캡슐이 글자 길이만큼 늘었다 줄었다 하면** 버튼이 제자리에서
    /// 꿈틀거린다. 그래서 도는 동안에는 두 글자를 모두 겹쳐 두고(보이지 않게) 그중 넓은 쪽으로
    /// 폭을 고정한다. 대기 → 실행처럼 성격이 바뀌는 순간에만 폭이 한 번 움직인다.
    /// ⚠️ 글자 수로 고르면 안 된다 — 언어마다 폭이 다르다("Pause"·"一時停止"). 실제로 그려서 잰다.
    private var sizingTitles: [String] {
        switch state {
        case .idle, .finished:
            return [primary.title]
        case .running, .overtime, .paused:
            return [String(localized: "Pause"), String(localized: "Resume")]
        }
    }

    /// 한 번의 움직임으로 묶는다 — 정지 버튼이 들어오는 것, 캡슐이 밀리는 것, 글자가 바뀌는 것이
    /// 각자 다른 속도로 움직이면 그게 "허접한 애니메이션"이다.
    private var motion: Animation? {
        reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.86)
    }

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            if showsCancel {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: height * 0.34, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: height, height: height)
                        .background(Circle().fill(Color(.systemGray5)))
                }
                .buttonStyle(PressScaleStyle(reduceMotion: reduceMotion))
                .accessibilityLabel(String(localized: "Cancel Timer"))
                // 옆에서 밀려들지 않고 **제자리에서 피어난다** — 옆에서 들어오면 캡슐과 두 방향으로
                // 엇갈려 어지럽다.
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            capsule
        }
        .animation(motion, value: state)
        .animation(motion, value: isPresentation)
    }

    // MARK: - 주 동작

    private var capsule: some View {
        let item = primary

        return Button(action: item.action) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: item.symbol)
                    .font(.system(size: height * 0.32, weight: .bold))
                    // ▶ ↔ ⏸ 는 시스템이 가진 교체 애니메이션이 가장 자연스럽다
                    .contentTransition(.symbolEffect(.replace))

                // ⚠️ `.background` 로 유령 글자를 깔면 폭이 안 잡힌다(배경은 부모 크기를 따를 뿐이다).
                //    ZStack 은 자식 중 가장 큰 것을 따르므로 여기서만 폭이 고정된다.
                ZStack {
                    ForEach(sizingTitles, id: \.self) { ghost in
                        Text(ghost)
                            .font(.system(size: height * 0.32, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .hidden()
                            .accessibilityHidden(true)
                    }

                    Text(item.title)
                        .font(.system(size: height * 0.32, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        // 글자는 겹쳐 녹인다(딱 끊기면 상태가 바뀐 게 아니라 화면이 튄 것처럼 보인다)
                        .contentTransition(.opacity)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, height * 0.55)
            .frame(height: height)
            .frame(minWidth: height * 2.6)
            .background(Capsule().fill(Color.accentColor))
        }
        .buttonStyle(PressScaleStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(item.title)
    }
}

/// 누르면 살짝 들어가는 것 — 버튼이 눌렸다는 유일한 신호라 형태로도 남긴다.
private struct PressScaleStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.96 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
