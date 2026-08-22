//
//  SectionProgressBar.swift
//  Rereminder
//
//  실행 중 원 아래에 서는 **완전 선형 구간 막대**.
//
//  링은 "전체가 얼마나 남았나"를 각도로 말한다. 그런데 발표자가 실제로 묻는 건 두 가지다 —
//  *지금 이 구간이 얼마 남았나*, 그리고 *이 구간이 전체에서 얼마나 큰 덩어리인가*.
//  뒤엣것은 원이 잘 못 한다: 서로 다른 각도 위치에 놓인 호 두 개의 길이 비교는 어렵고,
//  진행 중에는 지나간 경계가 호에서 빠지면서 배치까지 계속 변한다.
//
//  막대는 그걸 **공통 축 위의 길이**로 바꾼다. 5분 구간과 25분 구간이 눈으로 바로 비교되고,
//  시작(왼쪽 끝)과 끝(오른쪽 끝)이라는 기준점이 생긴다 — 원에는 12시 말고는 없던 것이다.
//
//  읽는 법은 링과 같다. **오른쪽의 진한 부분이 남은 시간**이고 왼쪽 옅은 부분은 지나간 시간,
//  그 경계의 흰 표시가 지금이다(링에서 줄어드는 호 끝의 흰 점과 같은 역할).
//
//  ⚠️ 색은 `SectionPalette` 하나만 본다 — 링의 초록 호와 막대의 초록 칸이 같은 구간이어야 한다.
//  ⚠️ 남은 시간 계산은 `TimerSections.remainingSeconds`, 자리 계산은 `SectionBarLayout` 하나씩만 쓴다.
//

import SwiftUI

struct SectionProgressBar: View {
    let segments: [TimerSections.Segment]
    /// 시작 후 경과 시간(초).
    let elapsedSec: Int

    var barHeight: CGFloat = 14

    /// 칸 아래 남은 시간 숫자를 붙일지.
    ///
    /// **끄는 자리는 하나 — "줄 + 링" 모양의 원 위 일자 줄이다.** 거기서는 이 막대가 주인공이
    /// 아니라 *전체가 어디쯤인가*만 답하고, 숫자는 링 안쪽(지금 구간)과 줄 끝(전체) 둘로 충분하다.
    /// 칸마다 숫자를 또 붙이면 한 화면에 시간이 다섯 개가 되어 원래 문제로 돌아간다.
    var showsLabels: Bool = true

    /// 칸 사이 여백 — 여기 종이 앉는다(막대가 두꺼울수록 종도 커지므로 같이 벌어진다).
    private var gap: CGFloat { max(3, barHeight * 0.32) }
    private let minSlotWidth: CGFloat = 6
    private let labelSpacing: CGFloat = 6

    /// 숫자가 없으면 좌우로 더 벌려 쓴다 — 잘릴 글자가 없으므로 여백을 남길 이유가 없다.
    private var horizontalPadding: CGFloat { showsLabels ? 24 : 8 }

    var body: some View {
        GeometryReader { geometry in
            let slots = SectionBarLayout.slots(segments: segments,
                                               totalWidth: geometry.size.width,
                                               gap: gap,
                                               minWidth: minSlotWidth)
            VStack(alignment: .leading, spacing: labelSpacing) {
                bar(slots: slots)
                if showsLabels {
                    labels(slots: slots, totalWidth: geometry.size.width)
                }
            }
        }
        .frame(height: showsLabels ? barHeight + labelSpacing + Self.labelHeight : barHeight)
        .padding(.horizontal, horizontalPadding)
        // 1초마다 툭툭 끊기지 않게 재생헤드가 미끄러진다. 구간 id 는 그대로라 칸이 새로 생기지 않는다.
        .animation(.linear(duration: 0.2), value: elapsedSec)
        .accessibilityElement(children: .contain)
    }

    // MARK: - 막대

    private func bar(slots: [SectionBarLayout.Slot]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(slots, segments)), id: \.0.id) { slot, segment in
                slotView(slot: slot, segment: segment)
                    .offset(x: slot.x)
            }
            alertBells(slots: slots)
            playhead(slots: slots)
        }
        .frame(height: barHeight)
    }

    /// 칸과 칸 사이 = **알림이 울리는 지점.** 링의 종 노브와 같은 표시를 막대에도 세운다.
    /// 이게 없으면 칸 사이 틈이 "왜 끊겼지"로 읽힌다.
    private func alertBells(slots: [SectionBarLayout.Slot]) -> some View {
        let diameter = barHeight * 1.05

        return ForEach(slots.dropLast()) { slot in
            ZStack {
                Circle().fill(DSColor.marker)
                Image(systemName: "bell.fill")
                    .font(.system(size: diameter * 0.52, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: diameter, height: diameter)
            .offset(x: slot.maxX + gap / 2 - diameter / 2)
        }
    }

    /// 칸 하나 — 옅은 바탕에 **오른쪽부터** 진한 색이 남는다(오른쪽 = 아직 오지 않은 시간).
    private func slotView(slot: SectionBarLayout.Slot,
                          segment: TimerSections.Segment) -> some View {
        let color = SectionPalette.color(segment.index)
        let remaining = TimerSections.remainingSeconds(of: segment, elapsedSec: elapsedSec)
        let ratio = segment.durationSec > 0
            ? CGFloat(remaining) / CGFloat(segment.durationSec)
            : 0

        return ZStack(alignment: .trailing) {
            Rectangle().fill(color.opacity(0.22))
            Rectangle().fill(color).frame(width: slot.width * min(1, max(0, ratio)))
        }
        .frame(width: slot.width, height: barHeight)
        .clipShape(Capsule())
    }

    /// 지금 이 순간. 지나간 쪽과 남은 쪽의 경계에 선다.
    @ViewBuilder
    private func playhead(slots: [SectionBarLayout.Slot]) -> some View {
        if elapsedSec > 0 {
            let x = SectionBarLayout.playheadX(slots: slots,
                                               segments: segments,
                                               elapsedSec: elapsedSec)
            Capsule()
                .fill(.white)
                .frame(width: 3, height: barHeight + 8)
                .shadow(color: .black.opacity(0.35), radius: 2)
                .offset(x: x - 1.5, y: -4)
        }
    }

    // MARK: - 숫자

    /// 칸 아래 남은 시간.
    ///
    /// 규칙 세 가지:
    /// 1. **지나간 구간은 숫자를 지운다.** `0:00` 이 여럿 늘어서면 지금 숫자를 눈으로 다시 찾아야 하고,
    ///    지나갔다는 건 옅어진 막대가 이미 말하고 있다.
    /// 2. **지금 구간의 숫자는 무슨 일이 있어도 보인다.** 마지막 1분처럼 칸이 좁아지는 순간은
    ///    하필 그 숫자가 가장 급한 때다 — 칸보다 넓어져도 그리고, 화면 밖으로만 안 나가게 자른다.
    /// 3. 아직 오지 않은 구간은 제 칸에 들어갈 때만, 그리고 지금 구간의 숫자와 겹치지 않을 때만 붙인다.
    private func labels(slots: [SectionBarLayout.Slot], totalWidth: CGFloat) -> some View {
        let paired = Array(zip(slots, segments))
        let activeBox = paired.lazy.compactMap { slot, segment -> LabelBox? in
            guard TimerSections.phase(of: segment, elapsedSec: elapsedSec) == .active else { return nil }
            return box(slot: slot, segment: segment, isActive: true, totalWidth: totalWidth)
        }.first

        return ZStack(alignment: .topLeading) {
            ForEach(paired, id: \.0.id) { slot, segment in
                label(slot: slot, segment: segment, totalWidth: totalWidth, activeBox: activeBox)
            }
        }
        .frame(height: Self.labelHeight, alignment: .topLeading)
    }

    /// 숫자 하나가 놓일 자리.
    ///
    /// `x`/`width` 는 글자를 가운데 정렬할 **프레임**이고, `inkStart`/`inkEnd` 는 그 안에서
    /// **글자가 실제로 덮는 범위**다. 둘을 갈라 두는 이유는 겹침 판정 때문이다 —
    /// ⚠️ 프레임으로 따지면 칸 사이 간격(3pt)이 판정 여백보다 좁아서 **바로 옆 칸의 숫자가 늘
    ///    겹친 것으로 나와 사라진다.** 프레임은 칸만큼 넓어도 글자는 그 가운데 몇 글자뿐이다.
    private struct LabelBox {
        let index: Int
        let x: CGFloat
        let width: CGFloat
        let inkStart: CGFloat
        let inkEnd: CGFloat
    }

    private func box(slot: SectionBarLayout.Slot,
                     segment: TimerSections.Segment,
                     isActive: Bool,
                     totalWidth: CGFloat) -> LabelBox {
        let text = self.text(of: segment)
        let ink = estimatedWidth(of: text, isActive: isActive)
        let width = max(slot.width, ink)
        let centered = slot.x + slot.width / 2 - width / 2
        let clamped = min(max(0, centered), max(0, totalWidth - width))
        let center = clamped + width / 2
        return LabelBox(index: segment.index,
                        x: clamped,
                        width: width,
                        inkStart: center - ink / 2,
                        inkEnd: center + ink / 2)
    }

    @ViewBuilder
    private func label(slot: SectionBarLayout.Slot,
                       segment: TimerSections.Segment,
                       totalWidth: CGFloat,
                       activeBox: LabelBox?) -> some View {
        let phase = TimerSections.phase(of: segment, elapsedSec: elapsedSec)
        let isActive = phase == .active
        let text = self.text(of: segment)
        let place = isActive
            ? (activeBox ?? box(slot: slot, segment: segment, isActive: true, totalWidth: totalWidth))
            : box(slot: slot, segment: segment, isActive: false, totalWidth: totalWidth)

        let fits = slot.width >= estimatedWidth(of: text, isActive: false)
        let collides = activeBox.map {
            $0.index != segment.index && place.inkStart < $0.inkEnd + 4 && $0.inkStart < place.inkEnd + 4
        } ?? false

        if isActive || (phase == .upcoming && fits && !collides) {
            Text(verbatim: text)
                .dsScaledFont(isActive ? 15 : 12,
                              weight: isActive ? .bold : .semibold,
                              design: .rounded,
                              relativeTo: .caption,
                              maxSize: isActive ? 20 : 16)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(SectionPalette.color(segment.index))
                .opacity(isActive ? 1.0 : 0.55)
                .frame(width: place.width, height: Self.labelHeight)
                .offset(x: place.x)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Section \(segment.index + 1)"))
                .accessibilityValue(Text(verbatim: text))
        }
    }

    private func text(of segment: TimerSections.Segment) -> String {
        TimeMapper.clockText(TimerSections.remainingSeconds(of: segment, elapsedSec: elapsedSec))
    }

    /// 글자가 칸에 들어가는지 어림한다. 정확한 측정 대신 자릿수 × 폭 — 한 시간이 넘어
    /// "1:05:00" 이 되면 자연히 더 넓은 칸을 요구한다.
    private func estimatedWidth(of text: String, isActive: Bool) -> CGFloat {
        CGFloat(text.count) * (isActive ? 9.5 : 7.5) + 4
    }

    private static let labelHeight: CGFloat = 20
}
