//
//  ClipClock.swift
//  RereminderClip
//
//  메인 화면(`TimerMainView.clockView`)의 다이얼 조작을 클립으로 옮긴 시계.
//  메인은 발표 모드 구간 링·템플릿까지 얹혀 있어 그대로 가져올 수 없어,
//  클립에 해당하는 부분만 같은 규칙으로 다시 구현했다.
//
//  메인과 맞춘 규칙:
//  - 대기 중에는 절대 각도(1° = 10초, 2바퀴까지)로 링을 채우고, 흰 점을 끌어 시간을 정한다.
//  - 실행 중에는 남은 비율로 바뀌고, 줄어드는 호의 끝을 흰 점으로 표시한다.
//  - 알림 지점은 주황 종 노브. 대기 중에는 끌어서 옮길 수 있다.
//  - 드래그 중·직후에는 해당 위치에 시간 툴팁을 띄운다.
//  - 선 두께 = 지름의 8.3%, 트랙은 `plain` 50%
//

import SwiftUI

struct ClipClock: View {
    @EnvironmentObject private var viewModel: ClipTimerViewModel

    var size: CGFloat

    /// 손을 놓고 이만큼 지나면 배지·링 강조·흐려진 종이 한꺼번에 원래대로 돌아온다 (메인 앱과 동일)
    private static let tooltipLingerSeconds: Double = 3
    /// 사라질 땐 뚝 끊지 않고 녹여서 — 들어올 땐 빠르게, 나갈 땐 천천히
    private static let dissolveDuration: Double = 0.35

    // 다이얼 드래그
    @State private var showDragTooltip = false
    @State private var dragTooltipLingerTask: Task<Void, Never>?
    @State private var isDraggingMain = false
    @State private var mainFingerAngle: Double = 0
    @State private var mainGrabDelta: Double = 0

    // 종 노브 드래그
    @State private var draggingAlertOffset: Int?
    @State private var alertDragAngle: Double = 0
    @State private var lingeringAlertOffset: Int?
    @State private var alertLingerTask: Task<Void, Never>?

    /// 자르지 않은 손가락 각도 — 종이 끝에 걸려도 손가락은 계속 따라가야 튀지 않는다
    @State private var alertFingerAngle: Double = 0
    /// 잡은 순간 종과 손가락이 어긋나 있던 만큼. 이걸 유지해야 집는 순간 종이 손끝으로 순간이동하지 않는다
    @State private var alertGrabDelta: Double = 0

    /// 다이얼 중심을 알아야 각도를 계산할 수 있어, 회전에 휘둘리지 않는 고정 좌표계를 따로 둔다
    private static let dialSpace = "clip.dial"

    private var lineWidth: CGFloat { size * 0.083 }
    private var isEditable: Bool { viewModel.isEditable }
    private var isProgressMode: Bool { !viewModel.isEditable }

    /// 노브 히트 영역(지름 2.8 × 선 두께)이 링 밖으로 나가므로,
    /// 뷰 프레임을 그만큼 키워 터치가 프레임 밖에서 잘리지 않게 한다.
    private var hitMargin: CGFloat { lineWidth * 1.4 }

    var body: some View {
        ZStack {
            track
            progressArcs

            if viewModel.state == .running || viewModel.state == .paused {
                progressEdgeDot
            }

            // 종을 잡고 있는 동안 링을 "시작 후 / 종료 전" 두 색으로 가른다
            if isEditable, let marker = highlightedAlert {
                alertSplitArc(angle: marker.angle)
                    .transition(.opacity)
            }

            alertKnobs

            if isEditable {
                dragPointer
            }

            if showDragTooltip && isEditable {
                dragTooltip
                    .transition(.opacity)
            }

            if let marker = highlightedAlert {
                alertDragTooltip(marker: marker)
                    .transition(.opacity)
            }
        }
        .frame(width: size + hitMargin * 2, height: size + hitMargin * 2)
        .coordinateSpace(name: Self.dialSpace)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Timer dial"))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAdjustableAction { direction in
            guard isEditable else { return }
            // 한 단계 = 1분
            let delta: Double = direction == .increment ? 6 : -6
            viewModel.updateMainAngle(viewModel.mainAngle + delta)
        }
    }

    // MARK: - Ring

    private var track: some View {
        Circle()
            .stroke(
                DSColor.plain.opacity(DSOpacity.track),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .frame(width: size, height: size)
    }

    /// 대기 중엔 절대 각도(2바퀴째는 연두), 실행 중엔 남은 비율
    private var progressArcs: some View {
        let primary: CGFloat
        let secondary: CGFloat
        let color: Color

        if viewModel.state == .overtime {
            primary = 0
            secondary = 0
            color = DSColor.stateOvertime
        } else if isProgressMode {
            primary = viewModel.remainingRatio
            secondary = 0
            color = Color.accentColor
        } else {
            let angle = viewModel.mainAngle
            primary = CGFloat(min(1.0, max(0, angle) / 360.0))
            secondary = CGFloat(max(0, min(1.0, (angle - 360) / 360.0)))
            color = Color.accentColor
        }

        return ZStack {
            Circle()
                .trim(from: 0, to: primary)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))

            // 두 번째 바퀴 (60분 초과)
            if secondary > 0 {
                Circle()
                    .trim(from: 0, to: secondary)
                    .stroke(
                        Color.green.opacity(0.7),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: size, height: size)
    }

    /// 줄어드는 호의 움직이는 끝점 — 대기 중 드래그 핸들과 같은 시각 언어(흰 원)
    private var progressEdgeDot: some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth * 0.9, height: lineWidth * 0.9)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
            .offset(x: size / 2)
            .rotationEffect(.degrees(Double(viewModel.remainingRatio) * 360.0))
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }

    // MARK: - 시간 드래그 핸들

    private var dragPointer: some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth, height: lineWidth)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
            // 손가락으로 잡기 쉽도록 보이는 크기보다 넓은 히트 영역
            .frame(width: lineWidth * 2.8, height: lineWidth * 2.8)
            .contentShape(Circle())
            .offset(x: size / 2)
            .rotationEffect(.degrees(viewModel.mainAngle))
            .gesture(mainDragGesture)
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }

    /// 좌표계 원점이 히트 여백만큼 밖에 있으므로 중심도 그만큼 밀린다
    private var dialCenter: CGPoint {
        CGPoint(x: size / 2 + hitMargin, y: size / 2 + hitMargin)
    }

    private var mainDragGesture: some Gesture {
        // 좌표계만 고정 좌표계로 바꾼다 — 인식 거리는 그대로 둔다
        return DragGesture(coordinateSpace: .named(Self.dialSpace))
            .onChanged { value in
                showDragTooltip = true
                dragTooltipLingerTask?.cancel()

                if !isDraggingMain {
                    isDraggingMain = true
                    // 손가락은 핸들 한가운데를 짚지 않는다. 그 차이를 기억해 두면 집는 순간 안 튄다
                    let grabbed = TimeMapper.ringAngle(at: value.startLocation, center: dialCenter)
                    mainFingerAngle = grabbed
                    mainGrabDelta = viewModel.mainAngle - grabbed
                }

                let finger = TimeMapper.ringAngle(at: value.location, center: dialCenter)
                mainFingerAngle = TimeMapper.unwrappedAngle(finger, continuing: mainFingerAngle)
                // 자르는 건 여기서만 — 잘린 값은 다음 계산에 되먹이지 않는다
                let angle = max(0, min(mainFingerAngle + mainGrabDelta, TimeMapper.maxAngle))
                viewModel.updateMainAngle(angle)
            }
            .onEnded { _ in
                isDraggingMain = false
                // 손을 놓은 뒤에도 잠시 유지
                dragTooltipLingerTask = Task {
                    try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: Self.dissolveDuration)) { showDragTooltip = false }
                }
            }
    }

    // MARK: - 알림 종 노브

    private var alertKnobs: some View {
        let total = CGFloat(max(1, viewModel.totalSeconds))
        let knobScale: CGFloat = isEditable ? 1.6 : 1.15
        let isHighlighting = highlightedAlert != nil

        return ZStack {
            ForEach(viewModel.alertOffsets, id: \.self) { offsetSec in
                let baseAngle: Double = isProgressMode
                    ? Double(CGFloat(offsetSec) / total) * 360.0
                    : Double(offsetSec) / TimeMapper.secondsPerDegree
                let isDraggingThis = draggingAlertOffset == offsetSec
                let angle = isDraggingThis ? alertDragAngle : baseAngle
                // 방금 놓은 종도 배지가 남아 있는 동안은 계속 주인공이다
                let isFocused = isDraggingThis
                    || (draggingAlertOffset == nil && lingeringAlertOffset == offsetSec)
                // 손을 떼는 순간 크기가 줄면 종이 한 번 튄다 — 배지가 녹아 사라질 때 같이 작아진다
                let scale = isFocused ? knobScale * 1.25 : knobScale
                // 하나를 옮기는 동안 나머지는 물러나 있어야 어느 종을 만지는지 헷갈리지 않는다
                let dimmed = isHighlighting && !isFocused
                let fired = isProgressMode && viewModel.remainingRatio <= CGFloat(offsetSec) / total

                ZStack {
                    Circle()
                        .fill(DSColor.marker)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    Image(systemName: fired ? "bell.slash.fill" : "bell.fill")
                        .font(.system(size: lineWidth * 0.7 * (isEditable ? 1.0 : 0.8), weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: lineWidth * scale, height: lineWidth * scale)
                .opacity(fired ? 0.35 : (dimmed ? 0.25 : 1.0))
                // 링을 따라 돌아도 종 아이콘은 똑바로 서 있도록 역회전
                .rotationEffect(.degrees(90 - angle))
                .frame(width: lineWidth * 2.8, height: lineWidth * 2.8)
                .contentShape(Circle())
                .offset(x: size / 2)
                .rotationEffect(.degrees(angle))
                .gesture(alertDragGesture(for: offsetSec), including: isEditable ? .all : .none)
                .rotationEffect(.degrees(-90))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.alertOffsets)
        // 흐려지고 돌아오는 것만 부드럽게 — 각도는 손가락을 그대로 따라가야 한다
        .animation(highlightAnimation, value: draggingAlertOffset)
        .animation(highlightAnimation, value: lingeringAlertOffset)
        .allowsHitTesting(isEditable)
        .accessibilityHidden(true)
    }

    /// 물러날 땐 빠르게, 돌아올 땐 배지가 녹는 속도에 맞춰 천천히
    private var highlightAnimation: Animation {
        highlightedAlert != nil
            ? .easeInOut(duration: 0.2)
            : .easeOut(duration: Self.dissolveDuration)
    }

    /// 지금 주목해야 할 알림 — 끌고 있는 종, 없으면 방금 놓은 종.
    /// 배지·링 강조·다른 종 흐리기가 모두 이 값 하나를 따라간다.
    private var highlightedAlert: (seconds: Int, angle: Double)? {
        if draggingAlertOffset != nil {
            return (TimeMapper.angleToSeconds(from: alertDragAngle), alertDragAngle)
        }
        if let sec = lingeringAlertOffset {
            return (sec, Double(sec) / TimeMapper.secondsPerDegree)
        }
        return nil
    }

    /// 종 위치를 경계로 링의 "종료 전" 쪽(0° ~ 종)만 주황으로 덮어 배지의 두 줄과 색을 맞춘다.
    /// 나머지(종 ~ 설정 시간)는 원래 강조색으로 남아 "시작 후" 구간이 된다.
    private func alertSplitArc(angle: Double) -> some View {
        let fraction = angle / 360.0
        return ZStack {
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, max(0, fraction))))
                .stroke(
                    DSColor.marker,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

            // 60분을 넘겨 두 번째 바퀴에 걸친 알림
            if fraction > 1 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, fraction - 1)))
                    .stroke(
                        DSColor.marker,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(-90))
        .accessibilityHidden(true)
    }

    private func alertDragGesture(for offsetSec: Int) -> some Gesture {
        DragGesture(coordinateSpace: .named(Self.dialSpace))
            .onChanged { value in
                if draggingAlertOffset != offsetSec {
                    draggingAlertOffset = offsetSec
                    // 손가락은 종 한가운데를 짚지 않는다. 그 차이를 기억해 두면 집는 순간 안 튄다
                    let grabbed = TimeMapper.ringAngle(at: value.startLocation, center: dialCenter)
                    alertFingerAngle = grabbed
                    alertGrabDelta = Double(offsetSec) / TimeMapper.secondsPerDegree - grabbed
                }
                alertLingerTask?.cancel()
                lingeringAlertOffset = nil

                let finger = TimeMapper.ringAngle(at: value.location, center: dialCenter)
                alertFingerAngle = TimeMapper.unwrappedAngle(finger, continuing: alertFingerAngle)

                // 알림은 총 시간보다 앞이어야 의미가 있다 (메인 앱과 같은 10초 여유)
                let maxAngle = Double(viewModel.totalSeconds - 10) / TimeMapper.secondsPerDegree
                // 자르는 건 여기서만 — 잘린 값은 다음 계산에 되먹이지 않는다
                alertDragAngle = max(0, min(alertFingerAngle + alertGrabDelta, max(0, maxAngle)))
            }
            .onEnded { _ in
                guard let dragged = draggingAlertOffset else { return }
                let newSec = TimeMapper.angleToSeconds(from: alertDragAngle)
                let keeps = newSec > 0 && newSec < viewModel.totalSeconds

                // ⚠️ 손을 뗄 때는 애니메이션을 걸지 않는다 — 메인 앱과 같은 이유다.
                //    ForEach 의 id 가 알림 초라서 지웠다 넣는 순간 SwiftUI 가 "다른 종"으로 보고
                //    `.transition(.scale + .opacity)` 를 재생해 종이 펑 튀어 보인다.
                //    (링 밖으로 끌어 지우는 경우는 그대로 페이드아웃)
                var transaction = Transaction()
                transaction.disablesAnimations = keeps
                withTransaction(transaction) {
                    viewModel.moveAlert(from: dragged, to: newSec)
                    // 놓은 자리의 시간을 잠시 유지 — 그동안 종도 큰 채로 남는다
                    if keeps { lingeringAlertOffset = newSec }
                    draggingAlertOffset = nil
                }

                guard keeps else { return }
                alertLingerTask = Task {
                    try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: Self.dissolveDuration)) { lingeringAlertOffset = nil }
                }
            }
    }

    // MARK: - 툴팁

    private var dragTooltip: some View {
        tooltip(
            text: mmss(viewModel.totalSeconds),
            angle: viewModel.mainAngle - 90,
            background: Color.accentColor
        )
    }

    /// 알림 배지 — 한 지점을 두 가지로 읽어준다.
    /// 위: 종료까지 얼마나 남았는지, 아래: 시작 후 얼마나 지났는지.
    /// (5분 발표에서 종료 1분 전에 종을 두면 1:00 / 4:00)
    /// 각 줄의 색은 링에서 강조되는 구간 색과 같아 어느 숫자가 어디인지 바로 보인다.
    private func alertDragTooltip(marker: (seconds: Int, angle: Double)) -> some View {
        let beforeEnd = max(0, marker.seconds)
        let afterStart = max(0, viewModel.totalSeconds - beforeEnd)

        let radians: Double = (marker.angle - 90) * .pi / 180
        // 두 줄 배지는 높이 절반이 34pt 쯤 되므로, 12시·6시에서 링을 덮지 않을 만큼 띄운다
        let distance: CGFloat = size / 2 + 52
        // 3시·9시 방향에서 화면 밖으로 나가지 않게 가둔다 (원이 화면 폭을 거의 꽉 채우므로 필요하다).
        // 화면 폭을 모르므로 원 안쪽으로만 잡는다 — 어떤 기기에서도 안전한 선이다
        let limit = max(0, size / 2 - Self.badgeHalfWidth)
        let dx = min(max(CGFloat(cos(radians)) * distance, -limit), limit)

        return VStack(spacing: 0) {
            badgeRow(icon: "flag.checkered", text: mmss(beforeEnd), background: DSColor.marker)
            badgeRow(icon: "play.fill", text: mmss(afterStart), background: Color.accentColor)
        }
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm + 4, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        .offset(x: dx, y: CGFloat(sin(radians)) * distance)
        .accessibilityHidden(true)
    }

    /// 배지 반너비 어림값 — 글꼴·여백을 키우면 이 값도 같이 올려야 한다
    private static let badgeHalfWidth: CGFloat = 58

    private func badgeRow(icon: String, text: String, background: Color) -> some View {
        HStack(spacing: DSSpacing.xs + 2) {
            Image(systemName: icon)
                .font(DSFont.caption.weight(.bold))
            Text(text)
                .font(Font.title3.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.xs + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        // 배지가 원 위로 겹치므로 대비를 확실히 준다
        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0)
    }

    private func tooltip(text: String, angle: Double, background: Color) -> some View {
        let radians: Double = angle * .pi / 180
        let distance: CGFloat = size / 2 + 32
        let dx: CGFloat = CGFloat(cos(radians)) * distance
        let dy: CGFloat = CGFloat(sin(radians)) * distance
        let font: Font = DSFont.body.weight(.semibold).monospacedDigit()
        let label: Text = Text(text).font(font)
        return label
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs + 2)
            .background(background)
            .foregroundStyle(.white)
            .cornerRadius(DSRadius.sm + 4)
            .offset(x: dx, y: dy)
            .accessibilityHidden(true)
    }

    private func mmss(_ seconds: Int) -> String { TimeMapper.mmss(seconds) }

    // MARK: - Accessibility

    private var accessibilityValue: String {
        let total = viewModel.totalSeconds
        return String(localized: "\(total / 60) minutes \(total % 60) seconds")
    }
}
