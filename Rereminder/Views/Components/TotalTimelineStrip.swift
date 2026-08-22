//
//  TotalTimelineStrip.swift
//  Rereminder
//
//  "줄 + 링" 모양에서 **원 위에 서는 일자 줄** — 전체 타이머 하나.
//
//  왜 있나 — 2.2.0 까지 이 자리는 원 안에 링을 한 겹 더 두른 **이중 링**이었다. 바깥이 전체,
//  안쪽이 지금 구간. 그런데 같은 모양(원)이 둘이면 볼 때마다 "어느 쪽이 무엇이더라"를 먼저
//  골라야 한다 — 1초 안에 답을 얻어야 하는 화면에서 그 한 번의 선택이 비싸다.
//
//  그래서 질문 둘을 **형태 둘**로 갈랐다. 길이(이 줄)는 *전체가 어디쯤인가*, 각도(링)는
//  *지금 구간이 얼마 남았나*. 형태가 다르면 고르지 않아도 눈이 알아서 나눈다.
//
//  ⚠️ 그림은 구간 막대(`SectionProgressBar`)를 **그대로** 쓴다. 칸 색·종·재생헤드가 두 모양에서
//     같아야 설정에서 모양을 바꿔도 다시 배우지 않는다. 다만 여기서는 주인공이 아니므로
//     **얇게, 칸마다 숫자 없이** 그리고 남은 전체 시간만 오른쪽 끝에 한 번 적는다
//     (칸마다 숫자를 또 붙이면 한 화면에 시간이 다섯 개가 되어 원래 문제로 돌아간다).
//

import SwiftUI

struct TotalTimelineStrip: View {
    let segments: [TimerSections.Segment]
    /// 시작 후 경과 시간(초).
    let elapsedSec: Int
    /// 이미 다듬어진 전체 남은 시간 문자열 (표기 규칙은 부르는 쪽이 갖는다).
    let totalRemainingText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: DSSpacing.sm)
                Text(totalRemainingText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            // 막대가 숫자 없이 쓰는 좌우 여백과 같은 값 — 글자와 칸의 왼쪽 끝이 맞아야 한 덩어리로 읽힌다
            .padding(.horizontal, 8)

            SectionProgressBar(segments: segments,
                               elapsedSec: elapsedSec,
                               // 링이 주인공이라 원 아래 막대(14)보다도 얇다
                               barHeight: 10,
                               showsLabels: false)
        }
        .padding(.horizontal, DSSpacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Total time remaining"))
        .accessibilityValue(Text(totalRemainingText))
    }
}
