//
//  SnakeTimerView.swift
//  Rereminder
//
//  **ㄹ자로 접은 줄** — 한 줄짜리 구간 막대를 여러 줄로 접은 형태.
//
//  왜 접나: 선은 구간 크기를 *길이*로 보여줘서 원보다 정확하게 읽히지만, 폭이 좁으면 1분짜리
//  구간이 실오라기가 된다. 접으면 같은 화면에서 줄이 몇 배 길어져 짧은 구간도 살아난다.
//  긴 타이머(60분+)일수록 이득이 크다.
//
//  대신 치르는 값 둘 — 설정 화면에도 적어 두었다:
//   • 줄마다 읽는 방향이 뒤집힌다(→ ← → ←). "전체가 얼마 남았나"는 원만큼 즉각적이지 않다.
//   • **짧은 구간이 U턴에 얹히면 곡선으로 말려 실제보다 짧아 보인다.** 길이는 정확히
//     비례하는데도 눈이 곡선을 짧게 센다. 줄 수를 늘릴수록 이 자리가 늘어나므로 4줄로 둔다.
//
//  읽는 법은 링·막대와 같다: **진한 쪽이 남은 시간**, 옅은 쪽이 지나간 시간, 흰 점이 지금.
//  색은 `SectionPalette` 하나만 본다 — 링의 초록 호와 이 줄의 초록 구간이 같은 구간이어야 한다.
//

import SwiftUI

struct SnakeTimerView: View {
    let segments: [TimerSections.Segment]
    /// 시작 후 경과 시간(초).
    let elapsedSec: Int

    /// 접는 줄 수. 늘릴수록 줄이 길어지지만 U턴(왜곡되는 자리)도 늘어난다.
    var rows: Int = 4
    var lineWidth: CGFloat = 18
    /// 지금 점·끝 표시. 실루엣(미리보기)에서는 끈다.
    var showsMarkers: Bool = true

    /// 구간 사이 틈(경로 길이 대비). 종이 앉을 자리이기도 하다 —
    /// 붙여 놓으면 색이 바뀌는 자리가 경계인지 그늘인지 모른다.
    private let gapFraction: CGFloat = 0.005

    private var totalSeconds: Int { max(1, segments.last?.endSec ?? 1) }

    private var elapsedFraction: CGFloat {
        min(1, max(0, CGFloat(elapsedSec) / CGFloat(totalSeconds)))
    }

    var body: some View {
        Canvas { context, size in
            let path = Self.path(in: size, rows: rows, lineWidth: lineWidth)
            let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .round)
            let elapsed = elapsedFraction

            for segment in segments {
                let start = CGFloat(segment.startSec) / CGFloat(totalSeconds)
                let end = CGFloat(segment.endSec) / CGFloat(totalSeconds)
                // 첫 구간의 시작과 마지막 구간의 끝은 줄 자체의 끝이라 깎지 않는다
                let from = segment.index == 0 ? start : start + gapFraction
                let to = max(from, end - (segment.endSec == totalSeconds ? 0 : gapFraction))
                guard to > from else { continue }

                let color = SectionPalette.color(segment.index)
                context.stroke(path.trimmedPath(from: from, to: to),
                               with: .color(color.opacity(0.22)),
                               style: stroke)

                // 남은 몫만 진하게 (링·막대와 같은 규칙)
                let remainingFrom = max(from, elapsed)
                if remainingFrom < to {
                    context.stroke(path.trimmedPath(from: remainingFrom, to: to),
                                   with: .color(color),
                                   style: stroke)
                }
            }

            guard showsMarkers else { return }

            // **구간 경계 = 알림이 울리는 지점.** 링의 종 노브와 같은 표시를 줄 위에도 세운다.
            // (경계를 틈으로만 표시하면 "줄이 끊어졌다"로 읽힌다 — 왜 끊겼는지는 종이 말해 준다.)
            var bell = context.resolve(Image(systemName: "bell.fill"))
            bell.shading = .color(.white)
            for segment in segments.dropLast() {
                let at = CGFloat(segment.endSec) / CGFloat(totalSeconds)
                guard let point = Self.point(on: path, at: at) else { continue }
                let r = lineWidth * 0.46
                context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(DSColor.marker))
                let glyph = r * 1.05
                context.draw(bell, in: CGRect(x: point.x - glyph / 2, y: point.y - glyph / 2,
                                              width: glyph, height: glyph))
            }

            // 접힌 줄에서 가장 먼저 잃는 것이 "어디가 끝인가"다 — 끝점에 표시를 박아 둔다
            if let finish = Self.point(on: path, at: 1) {
                let r = lineWidth * 0.3
                context.stroke(Path(ellipseIn: CGRect(x: finish.x - r, y: finish.y - r,
                                                      width: r * 2, height: r * 2)),
                               with: .color(.primary.opacity(0.75)),
                               lineWidth: max(2, lineWidth * 0.16))
            }

            // 지금 자리 — 막대의 재생헤드, 링의 흰 점과 같은 역할
            if let head = Self.point(on: path, at: elapsed) {
                let r = lineWidth * 0.34
                context.fill(Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(.white))
            }
        }
        .animation(.linear(duration: 0.2), value: elapsedSec)
        .accessibilityHidden(true)
    }

    // MARK: - 경로

    /// 왼→오, U턴, 오→왼… 으로 왕복하는 경로.
    /// **경로 길이가 곧 시간**이다(구간을 길이 비율로 자르는 게 이 형태의 전부라, 줄과 U턴의
    /// 길이가 시간에 비례한다는 이 성질을 깨뜨리지 말 것).
    static func path(in size: CGSize, rows: Int, lineWidth: CGFloat) -> Path {
        var path = Path()
        let rowCount = max(1, rows)
        let rowHeight = size.height / CGFloat(rowCount)
        let turn = rowHeight / 2                       // U턴은 줄 간격의 반지름 반원
        let left = lineWidth / 2 + turn
        let right = size.width - lineWidth / 2 - turn
        guard right > left else { return path }

        for row in 0..<rowCount {
            let y = rowHeight * (CGFloat(row) + 0.5)
            let goesRight = row.isMultiple(of: 2)
            let from = goesRight ? left : right
            let to = goesRight ? right : left

            if row == 0 { path.move(to: CGPoint(x: from, y: y)) }
            path.addLine(to: CGPoint(x: to, y: y))

            if row < rowCount - 1 {
                // 오른쪽 끝에서는 시계 방향, 왼쪽 끝에서는 반시계 방향으로 다음 줄에 내려간다
                path.addArc(center: CGPoint(x: to, y: y + turn),
                            radius: turn,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(90),
                            clockwise: !goesRight)
            }
        }
        return path
    }

    /// 경로 위 한 지점(0~1). `Path` 에는 길이로 점을 찾는 API가 없어서 **아주 짧게 잘라
    /// 그 조각의 가운데**를 쓴다.
    private static func point(on path: Path, at fraction: CGFloat) -> CGPoint? {
        let f = min(1, max(0, fraction))
        let slice = path.trimmedPath(from: max(0, f - 0.002), to: min(1, f + 0.002))
        let box = slice.boundingRect
        guard !box.isNull, box.width.isFinite, box.height.isFinite else { return nil }
        return CGPoint(x: box.midX, y: box.midY)
    }
}
