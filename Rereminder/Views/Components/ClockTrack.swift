//
//  ClockTrack.swift
//  Rereminder
//
//  Created by xa on 8/27/25.
//

import Foundation
import SwiftUI

struct ClockTrack: InsettableShape {
    var remaining: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let p = max(0, min(1, remaining))
        guard p > 0 else { return path }

        let size   = min(rect.width, rect.height)
        let radius = size / 2 - insetAmount
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let start = Angle.degrees(-90)
        let end   = Angle.degrees(start.degrees + Double(p * 360))

        path.addArc(center: center,
                    radius: radius,
                    startAngle: start,
                    endAngle: end,
                    clockwise: false)
        return path
    }

    var animatableData: CGFloat {
        get { remaining }
        set { remaining = newValue }
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var s = self
        s.insetAmount += amount
        return s
    }
}
