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
        let theta = (-90.0 + Double(t * 360.0)) * .pi / 180.0
        let rr = radius - inset
        let x = centerX + CGFloat(cos(theta)) * rr
        let y = centerY + CGFloat(sin(theta)) * rr
        let isUpcoming = t >= remaining

        return ZStack {
            Circle()
                .fill(isUpcoming ? Color.orange : Color.gray.opacity(0.5))
                .frame(width: dotSize, height: dotSize)

            if showLabels && index < markerOffsets.count {
                markerLabel(minutes: markerOffsets[index] / 60, theta: theta, isUpcoming: isUpcoming)
            }
        }
        .position(x: x, y: y)
    }

    private func markerLabel(minutes: Int, theta: Double, isUpcoming: Bool) -> some View {
        Text("\(minutes)분")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(isUpcoming ? .orange : .gray)
            .offset(x: CGFloat(cos(theta)) * 20,
                   y: CGFloat(sin(theta)) * 20)
    }
}
