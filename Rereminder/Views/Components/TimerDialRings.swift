//
//  TimerDialRings.swift
//  Rereminder
//
//  다이얼의 **링들** — 바탕 줄, 남은 시간 줄, 알림 경계로 나뉜 구간 색, 구간 번호.
//
//  화면(`TimerMainView`)이 "무엇을 그릴지" 정한 결과(`Plan`)만 받아서 그린다. 뷰모델도 상태도
//  모르기 때문에, 링이 이상하게 보일 때 **어디를 봐야 하는지가 둘로 갈린다** —
//  값이 틀렸으면 화면 쪽, 같은 값인데 그림이 틀렸으면 이 파일.
//
//  ⚠️ 좌표계는 어디서나 같다: **12시에서 시작, 시계 방향, 1.0 = 한 바퀴.**
//     링은 "종료까지 남은 시간" 좌표라 경과 순서와 반대이고, 구간 번호 역매핑은
//     `TimerSections.ringSectionIndex` 하나만 쓴다(테스트도 그쪽에 있다).
//

import SwiftUI

struct TimerDialRings: View {
    /// 이번 프레임에 그릴 링의 전부. 화면이 계산해서 넘긴다.
    struct Plan: Equatable {
        var size: CGFloat
        var lineWidth: CGFloat
        /// 60분을 넘어간 시간이 놓이는 안쪽 줄의 지름.
        var innerSize: CGFloat

        /// 바깥 줄에 그릴 남은 호 (0~1).
        var outerFraction: CGFloat
        /// 안쪽 줄(2바퀴째)에 그릴 남은 호.
        var innerFraction: CGFloat
        /// 설정 시간 전체 길이(바퀴 수 포함, 예: 90분 = 1.5) — 구간 색이 바퀴를 걸쳐도 이어지도록.
        var totalFraction: CGFloat
        /// 안쪽 줄이 빙 둘러 차오른 정도(0~1). 줄이 생기고 사라지는 연출.
        var innerRingReveal: CGFloat

        /// 알림 지점들(같은 좌표계).
        var markers: [CGFloat]
        /// 알림 경계로 나눠 구간 색으로 칠할 때인가. 아니면 단색이다.
        var showsSectionColors: Bool
        /// 단색일 때 쓸 색(실행 중 강조색 / 오버타임 빨강).
        var plainColor: Color
        /// 이름을 편집 중인 구간 — 그 호만 도드라지고 나머지는 물러난다.
        var focusedSectionIndex: Int?
        /// 구간 번호(1·2·3)를 붙일 때인가. 움직이는 동안에는 붙이지 않는다.
        var showsSectionNumbers: Bool
    }

    let plan: Plan

    var body: some View {
        ZStack {
            backgroundCircle

            // 바깥 줄 = 첫 바퀴
            if plan.showsSectionColors {
                sectionArcs(size: plan.size, lap: 0)
            } else {
                plainArc(to: plan.outerFraction, size: plan.size)
            }

            // 안쪽 줄 = 60분을 넘어간 시간.
            // 예전에는 같은 원 위에 연두색으로 겹쳐 그려서 두 바퀴가 서로를 덮었다.
            if plan.innerFraction > 0 || plan.innerRingReveal > 0 {
                // 얼마나 더 갈 수 있는지 보이도록 안쪽에도 옅은 바탕 링.
                // 나타날 때는 12시부터 시계 방향으로 차오르고, 사라질 때는 같은 길로 되감긴다.
                Circle()
                    .trim(from: 0, to: plan.innerRingReveal)
                    .stroke(.plain.opacity(0.5),
                            style: StrokeStyle(lineWidth: plan.lineWidth, lineCap: .round))
                    .frame(width: plan.innerSize, height: plan.innerSize)
                    .rotationEffect(.degrees(-90))

                if plan.showsSectionColors {
                    sectionArcs(size: plan.innerSize, lap: 1)
                } else {
                    plainArc(to: plan.innerFraction, size: plan.innerSize)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - 조각

    private var backgroundCircle: some View {
        Circle()
            .stroke(.plain.opacity(0.5),
                    style: StrokeStyle(lineWidth: plan.lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: plan.size, height: plan.size)
    }

    private func plainArc(to fraction: CGFloat, size: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(plan.plainColor,
                    style: StrokeStyle(lineWidth: plan.lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
    }

    /// 알림 경계로 나뉜 구간 색 호들.
    /// 구간이 바퀴 경계를 걸치면 잘라서 양쪽 줄에 나눠 그린다(`lap` 0 = 바깥, 1 = 안쪽).
    private func sectionArcs(size: CGFloat, lap: Int) -> some View {
        let bounds = [0] + plan.markers.filter { $0 > 0 && $0 < plan.totalFraction }.sorted()
            + [plan.totalFraction]
        let lapStart = CGFloat(lap)

        return ZStack {
            ForEach(0..<max(0, bounds.count - 1), id: \.self) { i in
                // 링은 "종료까지 남은 시간" 좌표라 경과 순서와 반대 → 구간 인덱스로 역매핑
                let sectionIndex = TimerSections.ringSectionIndex(
                    segmentEnd: Double(bounds[i + 1]),
                    markers: plan.markers.map(Double.init)
                )
                let isEditingThis = plan.focusedSectionIndex == sectionIndex
                let from = max(bounds[i], lapStart) - lapStart
                let to = min(bounds[i + 1], lapStart + 1) - lapStart

                if to > from {
                    // 이름을 편집 중인 구간은 링에서도 도드라진다 (리스트 카드의 테두리와 같은 문법)
                    if isEditingThis {
                        Circle()
                            .trim(from: from, to: to)
                            .stroke(Color.primary.opacity(0.85),
                                    style: StrokeStyle(lineWidth: plan.lineWidth + 6, lineCap: .butt))
                            .frame(width: size, height: size)
                            .rotationEffect(.degrees(-90))
                    }

                    Circle()
                        .trim(from: from, to: to)
                        .stroke(
                            SectionPalette.color(sectionIndex),
                            // 이어 붙는 경계라 round 캡을 쓰면 서로 겹쳐 부풀어 보인다
                            style: StrokeStyle(lineWidth: plan.lineWidth, lineCap: .butt)
                        )
                        // 다른 구간을 편집 중이면 이 호는 한 발 물러난다 (리스트 행과 같은 값)
                        .opacity(plan.focusedSectionIndex == nil || isEditingThis ? 1.0 : 0.55)
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(-90))

                    // 구간 번호 — 리스트의 "1, 2, 3"과 링의 호를 잇는 이름표.
                    // 호가 짧으면(숫자보다 좁으면) 넣지 않는다 — 옆 구간 위로 삐져나온다.
                    if plan.showsSectionNumbers, to - from >= 0.055 {
                        sectionNumber(sectionIndex + 1, atFraction: (from + to) / 2, size: size)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: plan.markers)
        .animation(.easeInOut(duration: 0.2), value: plan.focusedSectionIndex)
    }

    /// 링 위 한 지점(0~1)에 구간 번호를 세워서 얹는다.
    private func sectionNumber(_ number: Int, atFraction fraction: CGFloat, size: CGFloat) -> some View {
        let angle = Double(fraction) * 360.0
        return Text(verbatim: "\(number)")
            .font(.system(size: plan.lineWidth * 0.6, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
            // 링을 따라 돌아도 숫자는 똑바로 서 있어야 읽힌다
            .rotationEffect(.degrees(90 - angle))
            .offset(x: size / 2)
            .rotationEffect(.degrees(angle))
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }
}

// MARK: - 발표 모드의 바깥 얇은 링

/// 알림 지점을 경계로 나뉜 **바깥쪽 얇은 구간 링** (발표 모드 진행 중).
/// 본 링은 진행 중에 남은 시간만 그리므로, 구간 전체의 지도 역할을 이 링이 맡는다.
struct SectionOuterRing: View {
    let size: CGFloat
    let lineWidth: CGFloat
    /// 설정 시간까지의 길이(0~1).
    let arcEnd: CGFloat
    let markers: [CGFloat]
    let focusedSectionIndex: Int?

    private let gap: CGFloat = 0.004

    var body: some View {
        let ringWidth = lineWidth * 0.45
        let ringSize = size + lineWidth * 1.9
        let bounds = [0] + markers.filter { $0 > 0 && $0 < arcEnd }.sorted() + [arcEnd]

        return ZStack {
            ForEach(0..<max(0, bounds.count - 1), id: \.self) { i in
                // 링은 "남은 시간" 좌표라 경과 순서와 반대 → 리스트 인덱스로 역매핑
                let sectionIndex = bounds.count - 2 - i
                let isEditingThis = focusedSectionIndex == sectionIndex
                let trimFrom = bounds[i] + gap
                let trimTo = max(bounds[i] + gap, bounds[i + 1] - gap)

                // 편집 중인 호는 리스트 행과 같은 문법의 테두리를 두른다
                if isEditingThis {
                    Circle()
                        .trim(from: trimFrom, to: trimTo)
                        .stroke(Color.primary.opacity(0.85),
                                style: StrokeStyle(lineWidth: ringWidth * 1.8 + 4, lineCap: .butt))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                }

                Circle()
                    .trim(from: trimFrom, to: trimTo)
                    .stroke(
                        SectionPalette.color(sectionIndex).opacity(isEditingThis ? 1.0 : 0.85),
                        // 편집 중인 구간의 호는 굵어져서 위치가 바로 보임
                        style: StrokeStyle(lineWidth: ringWidth * (isEditingThis ? 1.8 : 1.0), lineCap: .butt)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: focusedSectionIndex)
        .accessibilityHidden(true)
    }
}
