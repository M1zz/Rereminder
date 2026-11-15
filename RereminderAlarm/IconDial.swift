//
//  IconDial.swift
//  RereminderAlarm
//
//  홈 화면 위젯의 링 — 앱 아이콘(`Rereminder/AppIcon.icon`)과 같은 그림이다.
//  굵은 구간 색 링, 알림 자리마다 흰 노브 위의 종(그 종이 끝내는 구간의 색), 양 끝은 둥글다.
//  바탕도 아이콘과 같은 흰빛·남색 그라데이션(`IconBackdrop`). 아이콘을 바꾸면 여기도 함께 볼 것.
//

import SwiftUI
import WidgetKit

/// 링 한 장. 12시에서 시계 방향으로 "남은 시간" 좌표다(앱 다이얼·아이콘과 같다).
/// `remaining` 이 1 이면 한 바퀴 전부, 도는 중이면 남은 만큼만 색이 남고 나머지는 옅은 바탕이다.
struct IconDial: View {
    let mainSeconds: Int
    let offsets: [Int]
    var remaining: Double = 1

    /// (시작, 끝, 구간 번호) 비율. 구간 번호는 경과 순서(`TimerSections.derive`)와 같다 — 0 이 처음 구간.
    private var arcs: [(from: Double, to: Double, index: Int)] {
        guard mainSeconds > 0 else { return [(0, 1, 0)] }
        let points = [mainSeconds] + bellSeconds.sorted(by: >) + [0]
        return (0..<(points.count - 1)).map { i in
            (Double(points[i + 1]) / Double(mainSeconds), Double(points[i]) / Double(mainSeconds), i)
        }
    }

    private var bellSeconds: [Int] {
        Array(Set(offsets.filter { $0 > 0 && $0 < mainSeconds }))
    }

    private var rest: Double { min(1, max(0, remaining)) }

    /// 비율 f 가 들어 있는 구간의 색
    private func color(at f: Double) -> Color {
        let arc = arcs.first { f >= $0.from && f <= $0.to } ?? arcs[0]
        return SectionPalette.color(arc.index)
    }

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            let line = d * 0.145
            let radius = (d - line) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let point: (Double) -> CGPoint = { f in
                let a = (f * 360 - 90) * .pi / 180
                return CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
            }

            ZStack {
                if rest < 1 {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: line)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(center)
                }
                if rest > 0 {
                    ForEach(arcs, id: \.index) { arc in
                        let to = min(arc.to, rest)
                        if to > arc.from {
                            Circle()
                                .trim(from: arc.from, to: to)
                                .stroke(SectionPalette.color(arc.index), style: StrokeStyle(lineWidth: line, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                                .frame(width: radius * 2, height: radius * 2)
                                .position(center)
                        }
                    }
                    // 호 전체의 양 끝은 둥글다 — 꼬리를 먼저, 12시의 머리를 그 위에(아이콘과 같다).
                    Circle().fill(color(at: rest)).frame(width: line, height: line).position(point(rest))
                    Circle().fill(color(at: 0)).frame(width: line, height: line).position(point(0))
                }
                ForEach(bellSeconds.filter { Double($0) / Double(mainSeconds) < rest }, id: \.self) { s in
                    let f = Double(s) / Double(mainSeconds)
                    let knob = line * 1.55
                    ZStack {
                        Circle().fill(.white)
                            .shadow(color: .black.opacity(0.18), radius: knob * 0.08, y: knob * 0.04)
                        Image(systemName: "bell.fill")
                            .font(.system(size: knob * 0.5, weight: .bold))
                            // 이 종이 끝내는 구간 = 종보다 위(남은 시간이 더 많은 쪽)
                            .foregroundStyle(color(at: min(1, f + 0.0001)))
                    }
                    .frame(width: knob, height: knob)
                    .position(point(f))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// 아이콘 가운데 숫자처럼 굵고 둥근 시간. 링 안쪽 폭에 맞춰 줄어든다.
struct IconDialTime<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geo in
            content
                .font(.system(size: geo.size.width * 0.22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .frame(width: geo.size.width * 0.6)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// 아이콘 바탕 — 밝을 땐 흰빛에서 옅은 청회색, 어두울 땐 남색에서 검정.
struct IconBackdrop: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(.displayP3, red: 0.078, green: 0.090, blue: 0.157), Color(.displayP3, red: 0.016, green: 0.020, blue: 0.043)]
                : [Color(.displayP3, red: 1, green: 1, blue: 1), Color(.displayP3, red: 0.906, green: 0.922, blue: 0.965)],
            startPoint: .top, endPoint: .bottom)
    }
}

/// "25:00" · "1:30:00" — 아이콘의 "4:59" 처럼 시계 모양으로 쓴다.
func iconClockText(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
}
