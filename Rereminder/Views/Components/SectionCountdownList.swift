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
    let segments: [TimerSections.Segment]
    /// 시작 후 경과 시간(초).
    let elapsedSec: Int
    var maxHeight: CGFloat = 160

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
                .foregroundStyle(color)

            Spacer(minLength: 0)

            // 전체에서 이 구간이 차지하는 길이 — 줄어드는 숫자와 헷갈리지 않게 작게 둔다.
            Text(verbatim: Self.mmss(segment.durationSec))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
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
