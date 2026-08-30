//
//  SectionCountdownList.swift
//  Rereminder
//
//  실행 중 원 아래에 서는 **구간별 카운트다운**.
//
//  45분을 20분 + 25분으로 나눠 놨다면, 처음에는 20:00만 줄어들고 25:00은 제자리에 서 있다가
//  앞 구간이 0이 되면 그때부터 줄어든다. 링은 "전체가 얼마나 남았나"를 보여주는데,
//  발표자가 실제로 세는 건 **지금 이 구간이 얼마 남았나**다.
//
//  숫자 옆에는 **길이에 비례한 막대**가 선다. 숫자만으로는 4분 구간과 8분 구간의 차이를 눈이
//  아니라 머리로 계산해야 한다 — 막대는 그걸 길이로 바꾼다(가장 긴 구간이 최대 폭).
//  막대는 **오른쪽 정렬**이고, 남은 시간만큼만 칠해져 왼쪽 끝이 오른쪽으로 밀리며 줄어든다.
//  (링·구간 막대와 같은 문법 — **오른쪽의 진한 부분이 남은 시간**이다.)
//
//  색은 링의 구간 색을 그대로 쓴다(`SectionPalette`). 같은 구간이면 어디서나 같은 색이어야
//  "저 초록 호가 이 초록 숫자"라는 연결이 생긴다 — 색을 한쪽만 바꾸지 말 것.
//  다만 **지금 구간만 100%**, 아직 오지 않은 구간은 물러나 있고 지나간 구간은 더 물러난다.
//  전부 같은 세기로 칠하면 어느 게 지금인지 다시 찾아야 한다.
//
//  ⚠️ 남은 시간 계산은 여기서 하지 않는다 — `TimerSections.remainingSeconds` 하나만 쓴다
//     (링·리스트·발표 모드가 같은 계산을 봐야 보이는 구간과 울리는 구간이 갈라지지 않는다).
//

import SwiftUI

struct SectionCountdownList: View {
    /// 위쪽 **바닥 여백** — 대기 중의 `SectionLengthBar` 와 같은 이유, 같은 값.
    @ScaledMetric(relativeTo: .footnote) private var minTopInset: CGFloat = 6

    let segments: [TimerSections.Segment]
    /// 시작 후 경과 시간(초).
    let elapsedSec: Int
    var maxHeight: CGFloat = 160

    /// 가장 긴 구간의 막대 폭. 나머지는 길이에 비례해 짧아진다.
    /// ⚠️ `GeometryReader` 로 화면 폭에서 재지 않는다 — 스크롤뷰 안에서 높이가 함께 늘어나
    ///    목록이 늘 최대 높이를 차지하게 된다. 고정값이면 그 위험이 없고 줄 사이 비교도 안정적이다.
    private let barMaxWidth: CGFloat = 116
    /// 아주 짧은 구간도 보이긴 해야 한다 — 비례대로면 30초짜리는 사라진다.
    private let barMinWidth: CGFloat = 10
    private let barHeight: CGFloat = 7

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                ForEach(segments) { segment in
                    row(segment)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: maxHeight)
        .padding(.horizontal, 24)
        // 어떤 부모 아래에서도 원에 달라붙지 않는다 (대기 중 SectionLengthBar 와 같은 규칙)
        .padding(.top, minTopInset)
    }

    private func row(_ segment: TimerSections.Segment) -> some View {
        let phase = TimerSections.phase(of: segment, elapsedSec: elapsedSec)
        let color = SectionPalette.color(segment.index)
        let remaining = TimerSections.remainingSeconds(of: segment, elapsedSec: elapsedSec)

        return HStack(spacing: 10) {
            marker(phase: phase, color: color)

            Text(verbatim: Self.mmss(remaining))
                .dsScaledFont(phase == .active ? 22 : 17,
                              weight: phase == .active ? .bold : .semibold,
                              design: .rounded,
                              relativeTo: .body,
                              maxSize: phase == .active ? 30 : 24)
                .monospacedDigit()
                // ⚠️ 시간은 **절대 접히지 않는다.** 이게 없으면 폭이 모자랄 때 SwiftUI 가
                //    텍스트부터 접어서 "8:56" 이 "8:5 / 6" 으로 두 줄이 된다
                //    (큰 글씨 설정이면 글자가 30pt 까지 커져 더 쉽게 걸린다).
                //    양보하는 쪽은 막대다 — 아래 bar(...) 가 남는 폭만 쓴다.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(color)

            Spacer(minLength: 8)

            // 길이에 비례한 막대 — 숫자가 못 하는 "이 구간이 저 구간의 두 배"를 눈으로 보여준다.
            bar(segment: segment, remaining: remaining, color: color)
        }
        .opacity(dimming(for: phase))
        .padding(.horizontal, 12)
        .padding(.vertical, phase == .active ? 6 : 3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(phase == .active ? 0.14 : 0))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Section \(segment.index + 1)"))
        .accessibilityValue(Text(verbatim: Self.mmss(remaining)))
    }

    /// 구간 길이에 비례한 막대. **오른쪽 정렬**이고 남은 만큼만 칠해진다 —
    /// 왼쪽 끝이 오른쪽으로 밀리며 줄어들어, 숫자와 같은 것을 길이로 말한다.
    private func bar(segment: TimerSections.Segment,
                     remaining: Int,
                     color: Color) -> some View {
        let width = Self.trackWidth(durationSec: segment.durationSec,
                                    longestSec: segments.map(\.durationSec).max() ?? 0,
                                    maxWidth: barMaxWidth,
                                    minWidth: barMinWidth)
        let ratio = Self.fillRatio(remaining: remaining, durationSec: segment.durationSec)

        // ⚠️ 폭을 고정(frame(width:))하면 좁은 화면에서 시간 텍스트를 밀어내 접히게 만든다.
        //    maxWidth 로 두어 **막대가 양보**하고, 채움은 GeometryReader 가 준
        //    **실제 그려진 폭**을 쓴다(비례 폭으로 계산하면 좁아졌을 때 비율이 어긋난다).
        return GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Capsule().fill(color.opacity(0.22))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * ratio)
            }
        }
        .frame(maxWidth: width, minHeight: barHeight, maxHeight: barHeight)
        // 1초마다 툭툭 끊기지 않게 미끄러진다(원 아래 막대와 같은 값).
        .animation(.linear(duration: 0.2), value: remaining)
        .accessibilityHidden(true)
    }

    /// 지금 구간은 꽉 찬 점, 아직 오지 않은 구간은 빈 점, 지나간 구간은 체크.
    /// 색만으로는 색각 이상이 있는 사람이 구분하기 어렵다 — 모양도 함께 다르게 둔다.
    @ViewBuilder
    private func marker(phase: TimerSections.Phase, color: Color) -> some View {
        switch phase {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color)
                .frame(width: 14, height: 14)
        case .active:
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .frame(width: 14, height: 14)
        case .upcoming:
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 11, height: 11)
                .frame(width: 14, height: 14)
        }
    }

    private func dimming(for phase: TimerSections.Phase) -> Double {
        switch phase {
        case .active:   return 1.0
        case .upcoming: return 0.55
        case .done:     return 0.3
        }
    }

    // MARK: - 폭 계산 (순수 함수 — 눈으로 못 보는 비율을 테스트가 지킨다)

    /// 이 구간 막대의 **전체 길이**. 가장 긴 구간이 `maxWidth`, 나머지는 그에 비례한다.
    ///
    /// ⚠️ 비례 폭이 `minWidth` 보다 좁아지면 최소 폭으로 올린다 — 20분 중 30초짜리 구간은
    ///    비례대로면 3pt 라 사라지고, **사라진 구간은 "없는 구간"으로 읽힌다**.
    ///    그만큼 그 줄만 실제보다 길어진다(알고 쓰는 거짓말 — `SectionBarLayout` 과 같은 규칙).
    static func trackWidth(durationSec: Int,
                           longestSec: Int,
                           maxWidth: CGFloat,
                           minWidth: CGFloat) -> CGFloat {
        let longest = max(1, longestSec)
        let proportional = maxWidth * CGFloat(max(0, durationSec)) / CGFloat(longest)
        return min(maxWidth, max(minWidth, proportional))
    }

    /// 막대에서 **칠해지는 몫** (1 → 0). 오른쪽 정렬이라 이 값이 줄면 왼쪽 끝이 오른쪽으로 밀린다.
    static func fillRatio(remaining: Int, durationSec: Int) -> CGFloat {
        guard durationSec > 0 else { return 0 }
        return min(1, max(0, CGFloat(remaining) / CGFloat(durationSec)))
    }

    /// "20:00" — 한 시간이 넘으면 "1:05:00".
    private static func mmss(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let hours = s / 3600
        let minutes = (s % 3600) / 60
        let secs = s % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
