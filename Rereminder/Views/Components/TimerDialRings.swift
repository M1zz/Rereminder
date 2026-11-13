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
        /// 지금 줄어드는 구간(걸기 전에는 먼저 줄어들 구간). 이것만 진하게 그린다.
        var activeSectionIndex: Int? = nil
        /// 차오르는 중이면 12시에서 여기까지만 칠한다(1.0 = 한 바퀴).
        var fillLaps: CGFloat = DialFillMask.noMask
        /// 구간 번호(1·2·3)를 붙일 때인가. 움직이는 동안에는 붙이지 않는다.
        var showsSectionNumbers: Bool
        /// 타이머가 걸려 있는가. 걸기 전(절대 각도)과 뒤(남은 비율)는 좌표가 다르다.
        var isProgress: Bool = false
    }

    let plan: Plan

    var body: some View {
        ZStack {
            backgroundCircle

            // 안쪽 줄에도 옅은 바탕 링 — 얼마나 더 갈 수 있는지 보이도록.
            // 나타날 때는 12시부터 시계 방향으로 차오르고, 사라질 때는 같은 길로 되감긴다.
            if plan.innerFraction > 0 || plan.innerRingReveal > 0 {
                Circle()
                    .trim(from: 0, to: plan.innerRingReveal)
                    .stroke(.plain.opacity(0.5),
                            style: StrokeStyle(lineWidth: plan.lineWidth, lineCap: .round))
                    .frame(width: plan.innerSize, height: plan.innerSize)
                    .rotationEffect(.degrees(-90))
            }

            // 색만 가린다. 바탕 링은 처음부터 보여야 "빈 원"이다.
            ZStack {
                // 바깥 줄 = 첫 바퀴
                if plan.showsSectionColors {
                    sectionArcs(size: plan.size, lap: 0)
                } else {
                    plainArc(to: plan.outerFraction, size: plan.size)
                }

                // 안쪽 줄 = 60분을 넘어간 시간.
                // 예전에는 같은 원 위에 연두색으로 겹쳐 그려서 두 바퀴가 서로를 덮었다.
                if plan.innerFraction > 0 || plan.innerRingReveal > 0 {
                    if plan.showsSectionColors {
                        sectionArcs(size: plan.innerSize, lap: 1)
                    } else {
                        plainArc(to: plan.innerFraction, size: plan.innerSize)
                    }
                }
            }
            .mask {
                DialFillMask(laps: plan.fillLaps, size: plan.size, innerSize: plan.innerSize, lineWidth: plan.lineWidth)
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
    private func arcOpacity(sectionIndex: Int, isEditingThis: Bool) -> Double {
        if plan.focusedSectionIndex != nil { return isEditingThis ? 1.0 : 0.55 }
        guard let active = plan.activeSectionIndex else { return 1.0 }
        return sectionIndex == active ? 1.0 : 0.4
    }

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
                        .opacity(arcOpacity(sectionIndex: sectionIndex, isEditingThis: isEditingThis))
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(-90))

                    // 호 전체의 양 끝만 둥글게. 경계는 위처럼 맞붙는다.
                    let opacity = arcOpacity(sectionIndex: sectionIndex, isEditingThis: isEditingThis)
                    let color = SectionPalette.color(sectionIndex)
                    // 한 바퀴를 꽉 채운 줄은 시작과 끝이 맞닿아 끝이 없다
                    if from == 0, lap == 1 || plan.totalFraction < 1 {
                        RingEndCap(fraction: 0, facesForward: false, lineWidth: plan.lineWidth)
                            .fill(color)
                            .opacity(opacity)
                            .frame(width: size, height: size)
                    }
                    if bounds[i + 1] == plan.totalFraction, to < 1 {
                        RingEndCap(fraction: to, facesForward: true, lineWidth: plan.lineWidth)
                            .fill(color)
                            .opacity(opacity)
                            .frame(width: size, height: size)
                    }

                    // 구간 번호 — 리스트의 "1, 2, 3"과 링의 호를 잇는 이름표.
                    // 호가 짧으면(숫자보다 좁으면) 넣지 않는다 — 옆 구간 위로 삐져나온다.
                    if plan.showsSectionNumbers, to - from >= 0.055 {
                        sectionNumber(sectionIndex + 1, atFraction: (from + to) / 2, size: size)
                    }
                }
            }
        }
        // ⚠️ 걸고 멈추는 순간에는 좌표가 통째로 바뀐다(절대 각도 ↔ 남은 비율). 그 변화까지 아래 애니메이션을 태우면
        //    링이 휘감아 돌았다 — 바로 바꾼다. 끝·정지로 돌아올 때는 화면이 빈 원을 다시 채운다(`TimerMainView.refillDialOnReturn`).
        .transaction(value: plan.isProgress) { $0.animation = nil }
        .animation(.easeInOut(duration: 0.2), value: plan.markers)
        .animation(.easeInOut(duration: 0.2), value: plan.focusedSectionIndex)
        .animation(.easeInOut(duration: 0.3), value: plan.activeSectionIndex)
    }

    /// 링 위 한 지점(0~1)에 구간 번호를 세워서 얹는다.
    private func sectionNumber(_ number: Int, atFraction fraction: CGFloat, size: CGFloat) -> some View {
        let angle = Double(fraction) * 360.0
        return Text(verbatim: "\(number)")
            .font(.system(size: plan.lineWidth * 0.6, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            // 밝은 구간 색(보라·초록·청록) 위에서는 흰 글자의 대비가 모자랐다(접근성 감사 "Contrast nearly passed").
            // 숫자 뒤에 살짝 어두운 원을 깔아 어느 구간 색 위에서도 4.5:1 을 넘게 한다.
            .background(
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: plan.lineWidth * 0.85, height: plan.lineWidth * 0.85)
            )
            // 링 위 자리로 옮긴다 — 12시에서 시계 방향으로 angle 만큼.
            // ⚠️ rotationEffect 를 겹쳐 돌려 놓으면 숫자는 똑바로 보여도 접근성 프레임이 "돌린 상자의 외곽"으로
            //    부풀어, 45° 근처 번호(대개 2)의 프레임에 어두운 원 밖의 밝은 링 색이 섞여 대비 감사가 실패했다.
            //    회전 없이 offset 으로만 옮겨 프레임이 숫자 크기 그대로 원 안에 머물게 한다.
            .offset(
                x: size / 2 * CGFloat(cos((angle - 90) * .pi / 180)),
                y: size / 2 * CGFloat(sin((angle - 90) * .pi / 180))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - 호의 둥근 끝

/// 호 끝에 붙이는 반원. 12시 기준 시계 방향 좌표(1.0 = 한 바퀴)이고, 호와 함께 움직이도록 애니메이션된다.
/// ⚠️ 구간 호에 `.round` 캡을 쓰면 옆 구간으로 부풀고, 원을 얹으면 흐린 구간에서 겹친 자리만 진해진다.
///    호 바깥쪽 반원만 그려야 어느 투명도에서도 한 덩어리로 보인다.
struct RingEndCap: Shape {
    var fraction: CGFloat
    let facesForward: Bool
    let lineWidth: CGFloat

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let degrees = Double(fraction) * 360 - 90
        let radians = degrees * .pi / 180
        let center = CGPoint(x: rect.midX + rect.width / 2 * cos(radians),
                             y: rect.midY + rect.width / 2 * sin(radians))
        var path = Path()
        path.addArc(center: center, radius: lineWidth / 2,
                    startAngle: .degrees(degrees),
                    endAngle: .degrees(degrees + (facesForward ? 180 : -180)),
                    clockwise: !facesForward)
        path.closeSubpath()
        return path
    }
}

// MARK: - 차오르는 가림막

/// 12시에서 시계 방향으로 `laps` 까지만 보이는 가림막. 한 바퀴를 넘으면 안쪽 줄로 이어진다.
/// ⚠️ 호마다 `trim` 을 움직이면 구간들이 동시에 자란다. 가림막 하나를 움직여야 차례로 찬다.
struct DialFillMask: Shape {
    /// 가리지 않는 값. 다이얼 최대는 두 바퀴다.
    static let noMask: CGFloat = 3

    var laps: CGFloat
    let size: CGFloat
    let innerSize: CGFloat
    let lineWidth: CGFloat

    var animatableData: CGFloat {
        get { laps }
        set { laps = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard laps < Self.noMask else {
            return Path(rect.insetBy(dx: -lineWidth * 2, dy: -lineWidth * 2))
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        func addArc(radius: CGFloat, laps: CGFloat) {
            guard laps > 0 else { return }
            var arc = Path()
            arc.addArc(center: center, radius: radius,
                       startAngle: .degrees(-90), endAngle: .degrees(-90 + Double(laps) * 360), clockwise: false)
            path.addPath(arc.strokedPath(StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)))
        }
        addArc(radius: size / 2, laps: min(1, laps))
        addArc(radius: innerSize / 2, laps: min(1, laps - 1))
        return path
    }
}

