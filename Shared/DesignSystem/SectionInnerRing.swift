//
//  SectionInnerRing.swift
//  Rereminder
//
//  **이중 링의 안쪽 링** — "지금 지나는 이 구간이 얼마 남았나".
//
//  바깥(본 링)은 전체가 얼마 남았나를, 안쪽은 이 구간이 얼마 남았나를 말한다.
//
//  ⚠️ **지금은 워치 전용이다.** iPhone 은 링 한 겹(구간 색으로 나뉜 전체) + 원 아래 구간
//     카운트다운 리스트로 돌아갔다 — 원 두 겹은 볼 때마다 어느 링이 무엇인지 골라야 해서
//     헷갈렸다. 워치는 화면이 좁아 리스트를 세울 자리가 없으므로 이 링이 그 역할을 한다.
//
//  ⚠️ 색은 반드시 `SectionPalette` 를 따른다 — 안쪽 링은 바깥 링의 그 구간과 **같은 색**이어야
//     "이 링이 저 구간"이라는 연결이 산다. 대신 두께와 간격으로 층을 가른다.
//

import SwiftUI

struct SectionInnerRing: View {
    let progress: TimerSections.Progress
    /// 링 지름 (선 중심 기준). `SectionInnerRing.diameter(...)` 로 구한다.
    let diameter: CGFloat
    /// 안쪽 링의 선 두께. `SectionInnerRing.lineWidth(...)` 로 구한다.
    let lineWidth: CGFloat
    /// 줄어드는 끝의 흰 점. 좁은 화면(워치)에서는 점이 먼지처럼 보여서 끈다.
    var showsEdgeDot: Bool = true

    /// 본 링 안쪽 가장자리에서 링 두께의 0.45배만큼 띄운 자리.
    /// 지금 구간의 색은 바깥 링의 그 구간과 같은 색이라, 사이가 좁으면 두 링이 한 덩어리로
    /// 붙어 보인다 — **간격이 곧 "이건 다른 층"이라는 표시다.**
    static func diameter(ringSize: CGFloat, lineWidth ringLineWidth: CGFloat) -> CGFloat {
        ringSize - ringLineWidth * 2.4
    }

    /// 본 링보다 얇게. 같은 굵기면 두 링이 같은 층으로 읽혀 어느 쪽이 전체인지 알 수 없다.
    /// 다만 너무 얇으면 줄어드는 게 안 보인다 — 0.5 에서 0.58 로 올렸다.
    static func lineWidth(ringLineWidth: CGFloat) -> CGFloat { ringLineWidth * 0.58 }

    var body: some View {
        ZStack {
            // 이 구간의 전체 길이 — 남은 호가 어디까지 있었는지 알아야 비율이 읽힌다
            Circle()
                .stroke(.plain.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .trim(from: 0, to: CGFloat(progress.remainingRatio))
                .stroke(SectionPalette.color(progress.index),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // 줄어드는 끝의 흰 점 — 바깥 링과 같은 색이라 나란히 붙는 구간이 생기는데,
            // 이 점이 "이 링은 따로 움직인다"를 말해 준다(바깥 링 끝점과 같은 문법).
            if showsEdgeDot {
                Circle()
                    .fill(.white)
                    .frame(width: lineWidth * 0.85, height: lineWidth * 0.85)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    .offset(x: diameter / 2)
                    .rotationEffect(.degrees(Double(progress.remainingRatio) * 360))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: diameter, height: diameter)
        .dsAnimation(.linear(duration: 0.5), value: progress.remainingRatio)
        // 구간이 바뀌면 새로 그린다 — 비율이 0 에서 1 로 튀는 걸 애니메이션으로 이으면
        // 링이 거꾸로 감기는 것처럼 보인다.
        .id(progress.index)
        .accessibilityHidden(true)
    }
}
