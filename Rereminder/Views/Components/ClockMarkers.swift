//
//  ClockMarkers.swift
//  Rereminder
//
//  Created by xa on 8/31/25.
//

import Foundation
import SwiftUI

struct ClockMarkers: View {
    var remaining: CGFloat
    var markers: [CGFloat]
    var markerOffsets: [Int] = []
    var draggingIndex: Int? = nil
    var draggingRatio: CGFloat? = nil
    var dotSize: CGFloat = 12
    var inset: CGFloat = 3
    var upcoming: Bool = true
    var showLabels: Bool = true
    /// 종 하나를 옮기는 동안 물러나 있어야 할 마커들 (종 노브와 같이 흐려진다)
    var dimmedIndices: Set<Int> = []
    /// 60분을 넘어 두 번째 바퀴에 놓인 마커가 붙을 안쪽 줄의 반지름 비율 (1이면 줄이 하나뿐)
    /// ⚠️ 이게 없으면 두 번째 바퀴 마커가 1.0 으로 잘려 전부 12시에 뭉친다.
    var innerRadiusScale: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            markerContent(geo: geo)
        }
        .allowsHitTesting(false)
    }

    private func markerContent(geo: GeometryProxy) -> some View {
        let size = min(geo.size.width, geo.size.height)
        let r = size / 2
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2

        return ZStack {
            ForEach(Array(markers.enumerated()), id: \.offset) { index, m in
                markerView(
                    marker: m,
                    index: index,
                    radius: r,
                    centerX: cx,
                    centerY: cy
                )
            }
        }
    }

    private func markerView(marker: CGFloat, index: Int, radius: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        let raw = index == draggingIndex ? (draggingRatio ?? marker) : marker
        let lapped = max(0, raw)
        // 한 바퀴를 넘은 마커는 안쪽 줄로 내려보낸다(각도는 넘긴 만큼만)
        let isSecondLap = lapped > 1
        let t = isSecondLap ? min(1, lapped - 1) : lapped
        let markerRadius = isSecondLap ? radius * innerRadiusScale : radius
        let angle = -90.0 + Double(t * 360.0)
        let theta = angle * .pi / 180.0
        let isUpcoming = lapped >= remaining

        return ZStack {
            // 얇은 사각형 마크 (높이는 Timer 선 두께와 동일)
            Rectangle()
                .fill(DSColor.marker)  // 사전 알림 마커 색
                .frame(width: 4, height: dotSize)  // 폭 4 (2배), 높이는 Timer 선 두께
                .rotationEffect(.degrees(angle + 90))  // 원의 중심을 향하도록 먼저 회전
                .position(
                    x: centerX + CGFloat(cos(theta)) * markerRadius,
                    y: centerY + CGFloat(sin(theta)) * markerRadius
                )

            if showLabels && index < markerOffsets.count {
                markerLabel(
                    minutes: markerOffsets[index] / 60,
                    theta: theta,
                    isUpcoming: isUpcoming,
                    radius: markerRadius,
                    centerX: centerX,
                    centerY: centerY,
                    index: index
                )
            }
        }
        .opacity(dimmedIndices.contains(index) ? 0.25 : 1.0)
    }

    private func markerLabel(
        minutes: Int,
        theta: Double,
        isUpcoming: Bool,
        radius: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat,
        index: Int
    ) -> some View {
        // 홀수번째는 바깥, 짝수번째는 안쪽
        let labelDistance = index % 2 == 0
            ? radius - dotSize * 1.2  // 짝수: 원 안쪽 (더 가까이)
            : radius + dotSize * 1.5  // 홀수: 원 바깥

        let offsetSec = index < markerOffsets.count ? markerOffsets[index] : minutes * 60
        let mins = offsetSec / 60
        let secs = offsetSec % 60
        let label = secs == 0 ? "\(mins)min" : String(format: "%d:%02d", mins, secs)

        return Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(DSColor.marker)  // 사전 알림 마커 색
            .position(
                x: centerX + CGFloat(cos(theta)) * labelDistance,
                y: centerY + CGFloat(sin(theta)) * labelDistance
            )
    }
}
