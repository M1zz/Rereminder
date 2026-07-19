//
//  SectionRing.swift
//  Rereminder
//
//  발표/멘토링 타이머용 섹션 분할 링
//  - 링 전체 = 총 시간(100%), 섹션별 호가 남은 시간 비율만큼 채워져 있고 시간이 지나며 줄어든다
//  - 섹션 경계 틱 = 섹션 종료 알림이 울리는 지점 (줄어드는 호 끝이 틱에 닿으면 섹션 전환)
//  - 좌표계는 ClockTrack과 동일: 12시 방향에서 시계 방향, 비율(0~1) 기반
//

import SwiftUI

struct SectionRing: View {
    struct Segment: Identifiable, Equatable {
        let id: UUID
        let name: String
        let durationText: String
        /// 링 위 구간 (남은 시간 비율 좌표, lo < hi)
        let lo: CGFloat
        let hi: CGFloat
    }

    var segments: [Segment]
    /// 남은 시간 / 총 시간 (0~1)
    var ratio: CGFloat
    var size: CGFloat
    var lineWidth: CGFloat

    private var clampedRatio: CGFloat { max(0, min(1, ratio)) }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
    }

    var body: some View {
        ZStack {
            // 배경 트랙 (지나간 구간이 드러나는 층)
            Circle()
                .stroke(.plain.opacity(0.5), style: strokeStyle)
                .frame(width: size, height: size)

            // 섹션별 남은 호 (인접 섹션은 명도로 구분)
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
                Circle()
                    .trim(from: seg.lo, to: max(seg.lo, min(seg.hi, clampedRatio)))
                    .stroke(segmentColor(index: index), style: strokeStyle)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }

            boundaryTicks
            segmentLabels
        }
        .dsAnimation(.linear(duration: 0.5), value: clampedRatio)
        .accessibilityHidden(true)
    }

    private func segmentColor(index: Int) -> Color {
        Color.accentColor.opacity(index.isMultiple(of: 2) ? 1.0 : 0.55)
    }

    // MARK: - 섹션 경계 틱 (알림 발생 지점)

    private var boundaryTicks: some View {
        ForEach(segments.filter { $0.lo > 0.001 }) { seg in
            let angle = -90.0 + Double(seg.lo) * 360.0
            let theta = angle * .pi / 180.0
            let radius = size / 2

            Rectangle()
                .fill(DSColor.marker)
                .frame(width: 4, height: lineWidth)
                .rotationEffect(.degrees(angle + 90))
                .offset(
                    x: CGFloat(cos(theta)) * radius,
                    y: CGFloat(sin(theta)) * radius
                )
        }
    }

    // MARK: - 섹션 이름 라벨 (호 중앙, 안/밖 교차 배치)

    private var segmentLabels: some View {
        ForEach(Array(segments.enumerated()), id: \.element.id) { index, seg in
            let mid = (seg.lo + seg.hi) / 2
            let angle = -90.0 + Double(mid) * 360.0
            let theta = angle * .pi / 180.0
            let distance = index.isMultiple(of: 2)
                ? size / 2 + lineWidth * 1.6   // 짝수: 원 바깥
                : size / 2 - lineWidth * 2.2   // 홀수: 원 안쪽
            let isElapsed = clampedRatio <= seg.lo

            Text("\(seg.name) \(seg.durationText)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(isElapsed ? 0.35 : 1.0)
                .offset(
                    x: CGFloat(cos(theta)) * distance,
                    y: CGFloat(sin(theta)) * distance
                )
        }
    }
}
