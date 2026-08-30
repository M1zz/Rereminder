//
//  MarkerDragBadge.swift
//  Rereminder
//
//  종(알림)을 끌 때 링 옆에 뜨는 **두 줄 배지**.
//
//  발표자는 그 지점을 두 가지로 알아야 한다 — 끝까지 얼마 남았나(⚑), 시작하고 얼마나 지났나(▶).
//  그래서 한 지점에 숫자가 둘이다.
//
//  ⚠️ 두 줄의 색은 **링에서 그 종의 양옆 구간 색**을 그대로 쓴다(부르는 쪽이 정해서 넘긴다).
//     링은 이미 알림 경계로 구간마다 색이 나뉘어 있어서, 종을 잡았다고 다른 색 체계로 갈아타면
//     "지금 만지는 구간이 어디였더라"를 다시 찾게 된다. **한쪽만 바꾸지 말 것.**
//  ⚠️ 3시·9시 방향에서는 배지가 화면 밖으로 밀려나므로 x 오프셋을 화면 폭으로 자른다.
//     글꼴·여백을 키우면 `halfWidth` 어림값도 같이 올려야 한다.
//

import SwiftUI

struct MarkerDragBadge: View {
    /// 종료까지 남은 시간(초) — 위 줄.
    let beforeEnd: Int
    /// 시작 후 지난 시간(초) — 아래 줄.
    let afterStart: Int
    /// 링 위 종의 각도(12시 = 0°, 시계 방향).
    let angle: Double
    /// 다이얼 지름.
    let size: CGFloat
    /// 화면 폭 — 배지가 밖으로 나가지 않게 자르는 기준.
    let availableWidth: CGFloat
    /// 위/아래 줄 색 (링의 그 구간 색).
    let colors: (beforeEnd: Color, afterStart: Color)

    /// 배지 반쪽 폭 어림값 — 화면 밖으로 나가지 않게 자를 때 쓴다.
    /// ⚠️ **글자 크기를 따라가야 한다.** 고정값이면 큰 글씨에서 실제 배지가 이 값보다
    ///    넓어져, 자른다고 자른 위치가 이미 화면 밖이다(그래서 숫자가 잘렸다).
    @ScaledMetric(relativeTo: .title3) private var halfWidth: CGFloat = 58

    /// 배지가 원 밖으로 나가는 거리. 값이 클수록 화면 가장자리에서 잘리기 쉽다.
    @ScaledMetric(relativeTo: .title3) private var outset: CGFloat = 38

    var body: some View {
        let tooltipAngle = angle - 90
        // 두 줄 배지는 높이 절반이 34pt 쯤 되므로, 12시·6시에서 링을 덮지 않을 만큼 띄운다.
        // ⚠️ 예전엔 +52 로 더 밀어냈는데, 좁은 화면(디스플레이 확대 등)에서는 그만큼
        //    가장자리에 먼저 닿아 잘렸다. 원 쪽으로 조금 당긴다.
        let distance = size / 2 + outset
        let rawX = cos(tooltipAngle * .pi / 180) * distance
        // 화면 안쪽으로 자른다. 여백 8pt 는 그림자·모서리 몫이다.
        let limit = max(0, availableWidth / 2 - halfWidth - 8)
        let xOffset = min(max(rawX, -limit), limit)
        let yOffset = sin(tooltipAngle * .pi / 180) * distance

        return VStack(spacing: 0) {
            row(icon: "flag.checkered", seconds: beforeEnd, background: colors.beforeEnd)
            row(icon: "play.fill", seconds: afterStart, background: colors.afterStart)
        }
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        .offset(x: xOffset, y: yOffset)
        .accessibilityHidden(true)
    }

    private func row(icon: String, seconds: Int, background: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .dsScaledFont(13, weight: .bold, relativeTo: .footnote, maxSize: 17)
            Text(TimeMapper.mmss(max(0, seconds)))
                // 상한을 둔다 — 위 halfWidth 어림값이 유효하려면 글자가 무한정 크면 안 된다
                .dsScaledFont(20, weight: .bold, relativeTo: .title3, maxSize: 26)
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        // 배지가 원 위로 겹치므로 대비를 확실히 준다
        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0)
    }
}
