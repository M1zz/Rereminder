//
//  RoundedRectRing.swift
//  Rereminder
//
//  화면 테두리를 따라가는 둥근 사각 링 — **워치 실행 화면**이 쓴다.
//
//  왜 원이 아닌가: 애플워치 화면 자체가 둥근 사각형이라 원을 그리면 네 모서리가 통째로 남는다.
//  40mm(162×197pt)에서는 그 낭비 때문에 원 아래 동작 버튼이 **화면 밖으로 잘려 있었다.**
//  같은 지름이면 둥근 사각이 가운데에 남기는 자리가 훨씬 넓다.
//
//  ⚠️ **`Ring`(Shape)과 `point(atFraction:)` 은 같은 경로를 같은 순서로 걷는다.**
//     `trim(from: 0, to: t)` 이 끝나는 자리가 곧 `point(atFraction: t)` 여야 한다 —
//     한쪽만 고치면 줄어드는 호의 끝과 알림 종이 어긋나 서로 다른 시각을 가리킨다.
//     그래서 둘 다 `segments(in:cornerRadius:)` 하나에서 나온다.
//

import SwiftUI

enum RoundedRectRing {

    /// 경로 조각 하나. 각도는 도(degree)이고 **화면 좌표계**(y가 아래로 증가)라
    /// 각도가 커지는 방향이 눈에는 시계 방향이다.
    enum Segment {
        case line(from: CGPoint, to: CGPoint)
        case arc(center: CGPoint, radius: CGFloat, start: Double, end: Double)

        var length: CGFloat {
            switch self {
            case let .line(a, b):
                return hypot(b.x - a.x, b.y - a.y)
            case let .arc(_, radius, start, end):
                return radius * CGFloat(abs(end - start) * .pi / 180)
            }
        }

        /// 이 조각 안에서의 위치(0…1).
        func point(at fraction: CGFloat) -> CGPoint {
            let f = min(max(fraction, 0), 1)
            switch self {
            case let .line(a, b):
                return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            case let .arc(center, radius, start, end):
                let angle = (start + (end - start) * Double(f)) * .pi / 180
                return CGPoint(x: center.x + radius * CGFloat(cos(angle)),
                               y: center.y + radius * CGFloat(sin(angle)))
            }
        }
    }

    /// 모서리 반지름은 짧은 변의 절반을 넘을 수 없다(넘으면 경로가 뒤집힌다).
    static func clampedRadius(_ radius: CGFloat, in size: CGSize) -> CGFloat {
        max(0, min(radius, min(size.width, size.height) / 2))
    }

    /// **12시(위 가운데)에서 시작해 시계 방향** 한 바퀴.
    /// 12시에서 시작하는 이유는 남은 시간 호·알림 종이 전부 그 좌표를 쓰기 때문이다
    /// (원형 링과 같은 문법 — 위가 시작이고 시계 방향으로 줄어든다).
    static func segments(in size: CGSize, cornerRadius: CGFloat) -> [Segment] {
        let w = size.width
        let h = size.height
        let r = clampedRadius(cornerRadius, in: size)
        return [
            .line(from: CGPoint(x: w / 2, y: 0), to: CGPoint(x: w - r, y: 0)),
            .arc(center: CGPoint(x: w - r, y: r), radius: r, start: -90, end: 0),
            .line(from: CGPoint(x: w, y: r), to: CGPoint(x: w, y: h - r)),
            .arc(center: CGPoint(x: w - r, y: h - r), radius: r, start: 0, end: 90),
            .line(from: CGPoint(x: w - r, y: h), to: CGPoint(x: r, y: h)),
            .arc(center: CGPoint(x: r, y: h - r), radius: r, start: 90, end: 180),
            .line(from: CGPoint(x: 0, y: h - r), to: CGPoint(x: 0, y: r)),
            .arc(center: CGPoint(x: r, y: r), radius: r, start: 180, end: 270),
            .line(from: CGPoint(x: r, y: 0), to: CGPoint(x: w / 2, y: 0))
        ]
    }

    static func perimeter(in size: CGSize, cornerRadius: CGFloat) -> CGFloat {
        segments(in: size, cornerRadius: cornerRadius).reduce(0) { $0 + $1.length }
    }

    /// 둘레의 t 지점(0…1). 알림 종·진행 표시가 이 값으로 자리를 잡는다.
    static func point(atFraction t: Double, in size: CGSize, cornerRadius: CGFloat) -> CGPoint {
        let segs = segments(in: size, cornerRadius: cornerRadius)
        let total = segs.reduce(0) { $0 + $1.length }
        guard total > 0 else { return CGPoint(x: size.width / 2, y: 0) }

        var walked = CGFloat(min(max(t, 0), 1)) * total
        for segment in segs {
            let length = segment.length
            // ⚠️ 길이 0인 조각은 **건너뛴다.** 모서리 반지름이 0이면 네 호가 전부 길이 0인데,
            //    여기서 돌려주면 t 와 상관없이 첫 모서리 좌표가 나온다(정사각형에서 종이 전부
            //    오른쪽 위에 몰려 찍혔다).
            if length <= 0 { continue }
            if walked <= length { return segment.point(at: walked / length) }
            walked -= length
        }
        // 부동소수 오차로 마지막을 넘어선 경우 — 출발점(12시)으로 돌아온 것이다.
        return CGPoint(x: size.width / 2, y: 0)
    }

    /// 위 좌표계를 그대로 그리는 Shape. `.trim(from:to:)` 이 같은 파라미터를 쓴다.
    struct Ring: Shape {
        var cornerRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            let segs = segments(in: rect.size, cornerRadius: cornerRadius)
            path.move(to: CGPoint(x: rect.size.width / 2, y: 0))
            for segment in segs {
                switch segment {
                case let .line(_, to):
                    path.addLine(to: to)
                case let .arc(center, radius, start, end):
                    // 각도가 커지는 방향 = 화면에서 시계 방향 (y가 아래로 증가하므로)
                    path.addArc(center: center,
                                radius: radius,
                                startAngle: .degrees(start),
                                endAngle: .degrees(end),
                                clockwise: false)
                }
            }
            return path.offsetBy(dx: rect.minX, dy: rect.minY)
        }
    }
}
