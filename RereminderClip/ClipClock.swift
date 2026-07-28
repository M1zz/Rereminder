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

    /// 손을 놓은 뒤 툴팁을 유지하는 시간 (메인 앱과 동일)
    private static let tooltipLingerSeconds: Double = 5

    // 다이얼 드래그
    @State private var showDragTooltip = false
    @State private var dragTooltipLingerTask: Task<Void, Never>?

    // 종 노브 드래그
    @State private var draggingAlertOffset: Int?
    @State private var alertDragAngle: Double = 0
    @State private var lingeringAlertOffset: Int?
    @State private var alertLingerTask: Task<Void, Never>?

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

            alertKnobs

            if isEditable {
                dragPointer
            }

            if showDragTooltip && isEditable {
                dragTooltip
            }

            if draggingAlertOffset != nil || lingeringAlertOffset != nil {
                alertDragTooltip
            }
        }
        .frame(width: size + hitMargin * 2, height: size + hitMargin * 2)
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

    private var mainDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                showDragTooltip = true
                dragTooltipLingerTask?.cancel()
                let newAngle = TimeMapper.angleDelta(
                    from: value.location,
                    currentAngle: viewModel.mainAngle
                )
                withAnimation(.linear(duration: 0.3)) {
                    viewModel.updateMainAngle(newAngle)
                }
            }
            .onEnded { _ in
                // 손을 놓은 뒤에도 잠시 유지
                dragTooltipLingerTask = Task {
                    try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) { showDragTooltip = false }
                }
            }
    }

    // MARK: - 알림 종 노브

    private var alertKnobs: some View {
        let total = CGFloat(max(1, viewModel.totalSeconds))
        let knobScale: CGFloat = isEditable ? 1.6 : 1.15

        return ZStack {
            ForEach(viewModel.alertOffsets, id: \.self) { offsetSec in
                let baseAngle: Double = isProgressMode
                    ? Double(CGFloat(offsetSec) / total) * 360.0
                    : Double(offsetSec) / TimeMapper.secondsPerDegree
                let isDraggingThis = draggingAlertOffset == offsetSec
                let angle = isDraggingThis ? alertDragAngle : baseAngle
                let scale = isDraggingThis ? knobScale * 1.25 : knobScale
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
                .opacity(fired ? 0.35 : 1.0)
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
        .allowsHitTesting(isEditable)
        .accessibilityHidden(true)
    }

    private func alertDragGesture(for offsetSec: Int) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let currentAngle: Double
                if draggingAlertOffset == offsetSec {
                    currentAngle = alertDragAngle
                } else {
                    draggingAlertOffset = offsetSec
                    currentAngle = Double(offsetSec) / TimeMapper.secondsPerDegree
                }
                alertLingerTask?.cancel()
                lingeringAlertOffset = nil

                var newAngle = TimeMapper.angleDelta(from: value.location, currentAngle: currentAngle)
                // 알림은 총 시간보다 앞이어야 의미가 있다 (메인 앱과 같은 10초 여유)
                let maxAngle = Double(viewModel.totalSeconds - 10) / TimeMapper.secondsPerDegree
                newAngle = max(0, min(newAngle, max(0, maxAngle)))
                alertDragAngle = newAngle
            }
            .onEnded { _ in
                guard let dragged = draggingAlertOffset else { return }
                let newSec = TimeMapper.angleToSeconds(from: alertDragAngle)
                viewModel.moveAlert(from: dragged, to: newSec)

                // 놓은 자리의 시간을 잠시 유지
                if newSec > 0 && newSec < viewModel.totalSeconds {
                    lingeringAlertOffset = newSec
                    alertLingerTask = Task {
                        try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.3)) { lingeringAlertOffset = nil }
                    }
                }
                draggingAlertOffset = nil
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

    private var alertDragTooltip: some View {
        let sec: Int
        let angle: Double
        if draggingAlertOffset != nil {
            sec = TimeMapper.angleToSeconds(from: alertDragAngle)
            angle = alertDragAngle
        } else {
            sec = lingeringAlertOffset ?? 0
            angle = Double(sec) / TimeMapper.secondsPerDegree
        }
        return tooltip(text: mmss(sec), angle: angle - 90, background: DSColor.marker)
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

    private func mmss(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    // MARK: - Accessibility

    private var accessibilityValue: String {
        let total = viewModel.totalSeconds
        return String(localized: "\(total / 60) minutes \(total % 60) seconds")
    }
}
