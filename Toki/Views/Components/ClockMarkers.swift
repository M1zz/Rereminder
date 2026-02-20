//
//  ClockMarkers.swift
//  Toki
//
//  Created by xa on 8/31/25.
//

import Foundation
import SwiftUI

struct ClockMarkers: View {
    var remaining: CGFloat
    var markers: [CGFloat]
    var markerOffsets: [Int] = []
    var dotSize: CGFloat = 12
    var inset: CGFloat = 3
    var upcoming: Bool = true
    var showLabels: Bool = true

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
        let t = max(0, min(1, marker))
        let angle = -90.0 + Double(t * 360.0)
        let theta = angle * .pi / 180.0
        let isUpcoming = t >= remaining

        return ZStack {
            // 얇은 사각형 마크 (높이는 Timer 선 두께와 동일)
            Rectangle()
                .fill(Color(red: 1.0, green: 0.6, blue: 0.0))  // 선명한 오렌지색
                .frame(width: 4, height: dotSize)  // 폭 4 (2배), 높이는 Timer 선 두께
                .rotationEffect(.degrees(angle + 90))  // 원의 중심을 향하도록 먼저 회전
                .position(
                    x: centerX + CGFloat(cos(theta)) * radius,
                    y: centerY + CGFloat(sin(theta)) * radius
                )

            if showLabels && index < markerOffsets.count {
                markerLabel(
                    minutes: markerOffsets[index] / 60,
                    theta: theta,
                    isUpcoming: isUpcoming,
                    radius: radius,
                    centerX: centerX,
                    centerY: centerY,
                    index: index
                )
            }
        }
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

        return Text("\(minutes)min")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))  // 선명한 오렌지색
            .position(
                x: centerX + CGFloat(cos(theta)) * labelDistance,
                y: centerY + CGFloat(sin(theta)) * labelDistance
            )
    }
}
