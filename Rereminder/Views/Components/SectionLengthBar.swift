//
//  SectionLengthBar.swift
//  Rereminder
//
//  **걸기 전에** 보는 구간 길이 한 줄 — "이 10분은 4분 + 5분 + 1분으로 나뉜다".
//
//  왜 대기 중에도 필요한가: 알림을 옮기는 조작은 링 위에서 **각도**로 한다. 각도는 "몇 분짜리
//  구간이 생겼나"를 잘 말해 주지 못한다 — 종을 옮겨 놓고 나서야 "그래서 첫 구간이 몇 분이지?"를
//  머리로 계산하게 된다. 그 답을 숫자로 바로 옆에 둔다.
//
//  실행 중에는 이 줄이 서지 않는다 — 그 자리는 `SectionCountdownList`(줄어드는 숫자) 몫이다.
//  둘을 같이 세우면 같은 구간을 두 번 그리는 셈이고, 도는 동안 알고 싶은 건 "남은 시간"이다.
//
//  ⚠️ 색은 `SectionPalette` 그대로 — 링의 그 구간 호와 **같은 색**이어야 "저 파란 조각이 이 4:00"
//     이라는 연결이 산다. 점 모양도 `SectionCountdownList` 의 '아직 오지 않은 구간'(빈 원)과 맞춘다.
//

import SwiftUI

struct SectionLengthBar: View {
    /// 위쪽 **바닥 여백**. 부모(TimerMainView.stackGap)가 주는 간격에 더해지는 최소값이다.
    /// ⚠️ 부모만 믿지 않는다 — 예전에 부모의 Spacer 하나 때문에 이 줄이 링에 9pt 까지
    ///    달라붙은 적이 있다. 컴포넌트가 스스로 최소한을 보장한다.
    @ScaledMetric(relativeTo: .footnote) private var minTopInset: CGFloat = 6

    let segments: [TimerSections.Segment]

    var body: some View {
        // 다 들어가면 **가운데**, 넘치면 밀어서 본다.
        // ⚠️ 스크롤뷰만 쓰면 칩이 늘 왼쪽에 붙는데, 바로 위의 원은 가운데라 어긋나 보인다.
        ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal, showsIndicators: false) {
                row.padding(.horizontal, 24)
            }
        }
        // 어떤 부모 아래에서도 원(또는 위 요소)에 달라붙지 않는다
        .padding(.top, minTopInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Section lengths"))
    }

    private var row: some View {
        HStack(spacing: 8) {
            ForEach(segments) { segment in
                chip(segment)
            }
        }
    }

    private func chip(_ segment: TimerSections.Segment) -> some View {
        let color = SectionPalette.color(segment.index)

        return HStack(spacing: 6) {
            // 빈 원 = 아직 오지 않은 구간. 실행 중 리스트와 같은 기호를 쓴다.
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: 9, height: 9)

            Text(verbatim: TimeMapper.clockText(segment.durationSec))
                .dsScaledFont(15, weight: .semibold, design: .rounded,
                              relativeTo: .footnote, maxSize: 21)
                .monospacedDigit()
                // 타이머 숫자는 접히지 않는다 — 큰 글씨 설정에서 "110:00" 이 두 줄이 되면
                // 칩 높이가 들쭉날쭉해지고 무엇보다 시간이 시간처럼 안 읽힌다.
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(color.opacity(0.14))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Section \(segment.index + 1)"))
        .accessibilityValue(Text(verbatim: TimeMapper.clockText(segment.durationSec)))
    }
}
