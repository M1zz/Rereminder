//
//  TimerShapeSilhouette.swift
//  Rereminder
//
//  타이머 모양 **실루엣** — 설정에서 "무엇을 고르는 건지"를 글자 대신 그림으로 보여준다.
//
//  이름만 있는 목록은 고를 수가 없다("줄 + 링"이 뭔데?). 그래서 같은 예시 타이머
//  (10분 · 알림 두 개 · 절반쯤 지난 상태)를 네 모양으로 그려 나란히 세운다.
//  **네 그림이 같은 순간을 가리켜야** 비교가 된다 — 예시 값은 이 파일 한 곳에 둔다.
//

import SwiftUI

struct TimerShapeSilhouette: View {
    let shape: TimerShape
    var size: CGFloat = 64
    /// 큰 미리보기에서는 지금 점·끝 표시까지 보여준다(작은 실루엣에서는 먼지처럼 보인다).
    var showsMarkers: Bool = false

    // MARK: - 예시 타이머 (네 모양이 같은 순간을 그린다)

    /// 10분 · 4분 전 + 1분 전 알림 → 구간 셋
    static let sampleSegments = TimerSections.derive(mainSeconds: 600, alertOffsets: [240, 60])
    static let sampleElapsed = 260
    static var sampleProgress: TimerSections.Progress? {
        TimerSections.progress(mainSeconds: 600, alertOffsets: [240, 60], elapsedSec: sampleElapsed)
    }
    private static let sampleRemainingRatio: CGFloat = 1 - CGFloat(sampleElapsed) / 600

    var body: some View {
        Group {
            switch shape {
            case .ring:        ringSilhouette
            case .lineAndRing: lineAndRingSilhouette
            case .bar:         barSilhouette
            case .snake:       snakeSilhouette
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - 원 계열

    /// 링 하나 = 전체.
    private var ringSilhouette: some View {
        let lineWidth = size * 0.13

        return ring(lineWidth: lineWidth,
                    diameter: size,
                    trim: Self.sampleRemainingRatio,
                    color: .accentColor)
            .frame(width: size, height: size)
    }

    /// 위에 일자 줄(전체) + 링(지금 구간 하나).
    ///
    /// 실루엣이 말해야 하는 건 **줄과 링이 서로 다른 것을 센다**는 사실이다. 그래서 링은
    /// 구간 색으로, 줄은 그 구간이 어디쯤인지 보이도록 칸을 나눠 그린다.
    private var lineAndRingSilhouette: some View {
        let stripHeight = size * 0.1
        let gap = size * 0.04
        let ringSize = size - stripHeight - size * 0.14
        let lineWidth = ringSize * 0.15
        let progress = Self.sampleProgress

        return VStack(spacing: size * 0.08) {
            // 전체 — 칸으로 나뉜 일자 줄
            GeometryReader { geometry in
                let total = CGFloat(Self.sampleSegments.last?.endSec ?? 1)
                let usable = geometry.size.width - gap * CGFloat(max(0, Self.sampleSegments.count - 1))
                HStack(spacing: gap) {
                    ForEach(Self.sampleSegments) { segment in
                        let color = SectionPalette.color(segment.index)
                        let remaining = TimerSections.remainingSeconds(of: segment,
                                                                      elapsedSec: Self.sampleElapsed)
                        let ratio = CGFloat(remaining) / CGFloat(max(1, segment.durationSec))
                        ZStack(alignment: .trailing) {
                            Capsule().fill(color.opacity(0.3))
                            GeometryReader { slot in
                                Capsule()
                                    .fill(color)
                                    .frame(width: slot.size.width * ratio)
                                    .offset(x: slot.size.width * (1 - ratio))
                            }
                        }
                        .frame(width: usable * CGFloat(segment.durationSec) / total)
                    }
                }
                .frame(height: stripHeight)
            }
            .frame(height: stripHeight)

            // 지금 구간 하나 — 링
            ring(lineWidth: lineWidth,
                 diameter: ringSize,
                 trim: CGFloat(progress?.remainingRatio ?? 1),
                 color: SectionPalette.color(progress?.index ?? 0))
                .frame(width: ringSize, height: ringSize)
        }
    }

    /// 두 실루엣이 같은 규칙으로 링을 그리도록 — 바탕 + 남은 호(+ 큰 미리보기에서는 끝점).
    private func ring(lineWidth: CGFloat,
                      diameter: CGFloat,
                      trim: CGFloat,
                      color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(.plain.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: trim)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if showsMarkers {
                Circle()
                    .fill(.white)
                    .frame(width: lineWidth * 0.9, height: lineWidth * 0.9)
                    .offset(x: diameter / 2)
                    .rotationEffect(.degrees(Double(trim) * 360))
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    // MARK: - 선형

    private var barSilhouette: some View {
        // 실루엣은 작아서 얇으면 안 읽힌다 — 실제 화면보다 굵은 비율로 그린다
        let height = size * 0.26
        let gap = size * 0.045

        return VStack {
            Spacer(minLength: 0)
            GeometryReader { geometry in
                let total = CGFloat(Self.sampleSegments.last?.endSec ?? 1)
                let usable = geometry.size.width - gap * CGFloat(max(0, Self.sampleSegments.count - 1))
                HStack(spacing: gap) {
                    ForEach(Self.sampleSegments) { segment in
                        let color = SectionPalette.color(segment.index)
                        let remaining = TimerSections.remainingSeconds(of: segment,
                                                                      elapsedSec: Self.sampleElapsed)
                        let ratio = CGFloat(remaining) / CGFloat(max(1, segment.durationSec))
                        ZStack(alignment: .trailing) {
                            Capsule().fill(color.opacity(0.3))
                            GeometryReader { slot in
                                Capsule()
                                    .fill(color)
                                    .frame(width: slot.size.width * ratio)
                                    .offset(x: slot.size.width * (1 - ratio))
                            }
                        }
                        .frame(width: usable * CGFloat(segment.durationSec) / total)
                    }
                }
                .frame(height: height)
            }
            .frame(height: height)
            Spacer(minLength: 0)
        }
    }

    private var snakeSilhouette: some View {
        // 작은 실루엣에서 4줄은 서로 붙어 뭉개진다 — 큰 미리보기에서만 실제와 같은 줄 수로
        SnakeTimerView(segments: Self.sampleSegments,
                       elapsedSec: Self.sampleElapsed,
                       rows: size >= 100 ? 4 : 3,
                       lineWidth: size * 0.13,
                       showsMarkers: showsMarkers)
            .padding(.vertical, size * 0.08)
    }
}
