//
//  TimerMainView.swift
//  Rereminder
//
//  Created by Oh Seojin on 9/24/25.
//

import SwiftUI

struct TimerMainView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    private var remaining: TimeInterval { screenVM.remaining }

    @State private var showTimeInput = false
    @State private var isDragging = false

    /// 구간 이름 입력 포커스 (키보드 내리기 제어용)
    @FocusState private var focusedSectionIndex: Int?
    @State private var dragTooltipAngle: Double = 0
    @State private var draggingMarkerOffset: Int? = nil
    @State private var markerDragAngle: Double = 0

    // 드래그를 놓은 뒤에도 툴팁을 잠시 유지 (5초)
    @State private var showDragTooltip = false
    @State private var dragTooltipLingerTask: Task<Void, Never>?
    @State private var lingeringMarkerOffset: Int? = nil
    @State private var markerLingerTask: Task<Void, Never>?

    private static let tooltipLingerSeconds: Double = 5

    /// 실행/일시정지/오버타임: 설정 시간을 100%로 보는 비율 모드
    private var isProgressMode: Bool {
        screenVM.state == .running || screenVM.state == .paused || screenVM.state == .overtime
    }

    /// 발표 모드: 섹션이 시간을 결정하므로 다이얼 직접 편집 대신 구간 편집 모달 사용
    private var isPresentationMode: Bool {
        screenVM.currentMode == .presentation
    }

    private var ratio: CGFloat {
        if isProgressMode {
            // 설정 시간 = 100%에서 감소
            let total = TimeInterval(max(1, screenVM.configuredMainSeconds))
            return CGFloat(max(0, min(1, remaining / total)))
        }
        return CGFloat(max(0, min(1, remaining / TimeInterval(TimeMapper.maxSeconds))))
    }
    private var markers: [CGFloat] {
        let offsets = screenVM.sortedOffsetsDesc.reversed()
        if isProgressMode {
            // 비율 좌표: 10분 타이머의 1분 전 알림 = 링의 10% 지점
            let total = CGFloat(max(1, screenVM.configuredMainSeconds))
            return offsets.map { CGFloat($0) / total }
        }
        return offsets.map { offset in
            CGFloat(offset) / TimeMapper.secondsPerDegree / 360.0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            // 발표 모드: 하단 구간 리스트 공간 확보를 위해 원을 축소
            let clockSize = min(availableWidth * 0.85, availableHeight * 0.55)
                * (isPresentationMode ? 0.72 : 1.0)
            let lineWidth = clockSize * 0.083
            let spacing = availableHeight * 0.01
            let buttonSize = clockSize * 0.18

            VStack(spacing: 0) {
                // 빠른Settings 영역
                Group {
                    if screenVM.state != .running {
                        AlertPresetButtons(screenVM: screenVM)
                            .padding(.top, spacing * 2)
                    } else {
                        // 실행 중일 때 빈 공간으로 높이 유지
                        Color.clear
                            .frame(height: availableHeight * 0.08)
                    }
                }

                Spacer()

                clockView(size: clockSize, lineWidth: lineWidth, geometry: geometry, buttonSize: buttonSize)

                Spacer()

                if isPresentationMode {
                    // 알림 지점 기준 파생 구간 리스트 (원 밖 아래쪽)
                    derivedSectionList(maxHeight: availableHeight * 0.4)
                        .padding(.bottom, spacing * 2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !screenVM.nextAlertText.isEmpty {
                    // Next 알림 Info (원 밖 아래쪽)
                    nextAlertInfo
                        .padding(.vertical, spacing * 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // 빈 곳을 탭하면 키보드 내림 (버튼·제스처는 그대로 동작)
        .simultaneousGesture(TapGesture().onEnded {
            focusedSectionIndex = nil
        })
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedSectionIndex = nil
                }
            }
        }
        .sheet(isPresented: $showTimeInput) {
            TimeInputSheet(screenVM: screenVM, isPresented: $showTimeInput)
                .presentationDetents([.height(300)])
        }
        .fullScreenCover(isPresented: $screenVM.showTimerAlert) {
            TimerAlertView {
                screenVM.showTimerAlert = false
            }
        }
        .alert("Notification permission is required", isPresented: $screenVM.showPermissionWarning) {
            Button("Go to Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Later", role: .cancel) {
                // 권한 없이 Start Timer
                screenVM.showToast?("⚠️ Started without notification permission")
                withAnimation(.easeInOut(duration: 0.4)) {
                    screenVM.timerVM.start()
                }
            }
        } message: {
            Text("Notification permission is required for timer alerts.\n\nWithout permission:\n• You won't receive pre-alerts\n• You won't receive end alerts\n• Notifications won't work in background\n\nPlease enable notifications in Settings.")
        }
    }

    private func clockView(size: CGFloat, lineWidth: CGFloat, geometry: GeometryProxy, buttonSize: CGFloat) -> some View {
        ZStack {
            backgroundCircle(size: size, lineWidth: lineWidth)
            progressCircle(size: size, lineWidth: lineWidth)

            // 구간 링은 발표 모드 전용
            if isPresentationMode {
                sectionOuterRing(size: size, lineWidth: lineWidth)
                    .transition(.opacity)
            }

            // 실행/일시정지 중: 줄어드는 호의 끝점을 동그라미로 표시
            if screenVM.state == .running || screenVM.state == .paused {
                progressEdgeDot(size: size, lineWidth: lineWidth)
            }

            clockMarkers(size: size, lineWidth: lineWidth)

            // 시간 조절 드래그는 대기/Done 상태에서만 (실행·일시정지·오버타임 중에는 불가)
            if isTimeEditable {
                dragPointer(size: size, lineWidth: lineWidth)
            }

            // 알림 노브: 대기 중엔 드래그 핸들, 실행/일시정지 중엔 알림 시점 표시
            alertKnobs(size: size, lineWidth: lineWidth)

            if showDragTooltip && isTimeEditable {
                dragTooltip(size: size)
            }

            if (draggingMarkerOffset != nil || lingeringMarkerOffset != nil) && isTimeEditable {
                markerDragTooltip(size: size)
            }

            let fontSize = isPresentationMode
                ? size * 0.17
                : min(geometry.size.width, geometry.size.height) * 0.16

            // 시간 + 버튼 묶음을 원의 세로 중앙에 배치 (모든 모드 공통)
            VStack(spacing: fontSize * 0.45) {
                if let segment = currentSegment {
                    // 발표 모드 실행 중: 현재 구간 이름 + 구간 색 점
                    HStack(spacing: DSSpacing.xs) {
                        Circle()
                            .fill(sectionColor(segment.index))
                            .frame(width: fontSize * 0.22, height: fontSize * 0.22)
                        Text(segment.name)
                            .font(.system(size: fontSize * 0.45, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .animation(.easeInOut(duration: 0.3), value: segment.index)
                } else if isProgressMode && !screenVM.timerVM.currentLabel.isEmpty {
                    // 타이머 라벨(예: "Mentoring")만 표시 — 상태 텍스트는 표시하지 않음
                    Text(screenVM.timerVM.currentLabel)
                        .font(.system(size: fontSize * 0.45, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                centerTimeDisplay(fontSize: fontSize)
                buttonRow(buttonSize: buttonSize)
            }
        }
        .onChange(of: screenVM.state) { _, newState in
            let announcement: String
            switch newState {
            case .running:
                announcement = String(localized: "Timer started")
            case .paused:
                announcement = String(localized: "Timer paused")
            case .overtime:
                announcement = String(localized: "Timer finished, overtime counting")
            case .finished:
                announcement = String(localized: "Timer stopped")
            case .idle:
                announcement = String(localized: "Timer ready")
            }
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    /// 줄어드는 호의 움직이는 끝점 표시 — 대기 중 드래그 핸들과 같은 시각 언어(흰 원)
    private func progressEdgeDot(size: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth * 0.9, height: lineWidth * 0.9)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
            .offset(x: size / 2)
            .rotationEffect(.degrees(Double(ratio) * 360.0))
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }

    /// 구간별 고유 색 팔레트 (주황은 알림 마커 전용이라 제외)
    private static let sectionPalette: [Color] = [.blue, .green, .purple, .teal, .pink, .indigo]

    /// 구간 인덱스(경과 순서 기준) → 색
    private func sectionColor(_ index: Int) -> Color {
        Self.sectionPalette[index % Self.sectionPalette.count]
    }

    /// 알림 지점을 경계로 분할된 바깥 구간 링 (발표용 토글)
    /// 각 구간은 리스트와 같은 고유 색으로 표시된다
    private func sectionOuterRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        let ringWidth = lineWidth * 0.45
        let ringSize = size + lineWidth * 1.9
        let arcEnd: CGFloat = isProgressMode
            ? 1.0
            : CGFloat(min(1.0, max(0, screenVM.mainAngle) / 360.0))
        let bounds = [0] + markers.filter { $0 > 0 && $0 < arcEnd }.sorted() + [arcEnd]
        let gap: CGFloat = 0.004

        return ZStack {
            ForEach(0..<(bounds.count - 1), id: \.self) { i in
                // 링은 "남은 시간" 좌표라 경과 순서와 반대 → 리스트 인덱스로 역매핑
                let sectionIndex = bounds.count - 2 - i
                let isEditingThis = focusedSectionIndex == sectionIndex
                let trimFrom = bounds[i] + gap
                let trimTo = max(bounds[i] + gap, bounds[i + 1] - gap)

                // 편집 중인 호는 리스트 행과 같은 문법의 테두리를 두른다
                if isEditingThis {
                    Circle()
                        .trim(from: trimFrom, to: trimTo)
                        .stroke(
                            Color.primary.opacity(0.85),
                            style: StrokeStyle(lineWidth: ringWidth * 1.8 + 4, lineCap: .butt)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                }

                Circle()
                    .trim(from: trimFrom, to: trimTo)
                    .stroke(
                        sectionColor(sectionIndex).opacity(isEditingThis ? 1.0 : 0.85),
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

    private func backgroundCircle(size: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .stroke(
                .plain.opacity(0.5),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func progressCircle(size: CGFloat, lineWidth: CGFloat) -> some View {
        let primaryFraction: CGFloat
        let secondaryFraction: CGFloat  // 대기 중 60분 초과 설정 시 2바퀴째
        let circleColor: Color

        if screenVM.state == .running || screenVM.state == .paused {
            // 실행/Pause 중: 설정 시간 = 100% 링이 비율로 감소
            primaryFraction = ratio
            secondaryFraction = 0
            circleColor = Color.accentColor
        } else if screenVM.state == .overtime {
            // 오버타임: 빨간색 원형 (음수 시간은 각도로 변환하지 않고 0으로 표시)
            primaryFraction = 0
            secondaryFraction = 0
            circleColor = Color.red
        } else {
            // 대기/Done 상태: Settings된 시간을 절대 각도(1° = 10초)로 표시
            let angle = screenVM.mainAngle
            primaryFraction = CGFloat(min(1.0, max(0, angle) / 360.0))
            secondaryFraction = CGFloat(max(0, min(1.0, (angle - 360) / 360.0)))
            circleColor = Color.accentColor
        }

        return ZStack {
            // 첫 번째 바퀴: 기본 색상
            Circle()
                .trim(from: 0, to: primaryFraction)
                .stroke(
                    circleColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.init(degrees: -90))

            // 두 번째 바퀴 (360-720도): 연두색
            if secondaryFraction > 0 {
                Circle()
                    .trim(from: 0, to: secondaryFraction)
                    .stroke(
                        Color.green.opacity(0.7),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.init(degrees: -90))
            }
        }
        .accessibilityHidden(true)
    }

    private func clockMarkers(size: CGFloat, lineWidth: CGFloat) -> some View {
        let sortedOffsets = Array(screenVM.selectedOffsets.sorted())
        let draggingIdx: Int? = if let offset = draggingMarkerOffset {
            sortedOffsets.firstIndex(of: offset)
        } else {
            nil
        }
        let dragRatio: CGFloat? = if draggingMarkerOffset != nil {
            CGFloat(markerDragAngle * TimeMapper.secondsPerDegree)
                / (TimeMapper.secondsPerDegree * 360.0)
        } else {
            nil
        }

        return ClockMarkers(
            remaining: ratio,
            markers: markers,
            markerOffsets: sortedOffsets,
            draggingIndex: draggingIdx,
            draggingRatio: dragRatio,
            dotSize: lineWidth,
            inset: 0,
            upcoming: true,
            // 상시 라벨은 제거 — 드래그 중/직후 툴팁이 대신함
            showLabels: false
        )
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func dragPointer(size: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth, height: lineWidth)
            .offset(x: size / 2)
            .rotationEffect(.degrees(screenVM.mainAngle))
            .gesture(dragGesture)
            .rotationEffect(.init(degrees: -90))
            .accessibilityHidden(true)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                showDragTooltip = true
                dragTooltipLingerTask?.cancel()
                withAnimation(.linear(duration: 0.3)) {
                    onDrag(value: value)
                }
                dragTooltipAngle = screenVM.mainAngle - 90
            }
            .onEnded { _ in
                isDragging = false
                let snapped = snappedAngle(from: screenVM.mainAngle)
                withAnimation {
                    screenVM.mainAngle = snapped
                }
                dragTooltipAngle = snapped - 90
                // 손을 놓은 뒤에도 잠시 유지
                dragTooltipLingerTask = Task {
                    try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        showDragTooltip = false
                    }
                }
            }
    }

    private func dragTooltip(size: CGFloat) -> some View {
        let timeText = mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes)
        let xOffset = cos(dragTooltipAngle * .pi / 180) * (size / 2 + 32)
        let yOffset = sin(dragTooltipAngle * .pi / 180) * (size / 2 + 32)

        return Text(timeText)
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(10)
            .offset(x: xOffset, y: yOffset)
            .accessibilityHidden(true)
    }

    /// 알림 노브 — 상태에 따라 역할이 달라진다:
    /// - 대기/Done: 크게 표시 + 드래그로 알림 시점 조절
    /// - 실행/일시정지/오버타임: 작게 표시만 (비율 위치), 이미 울린 알림은 흐리게
    private func alertKnobs(size: CGFloat, lineWidth: CGFloat) -> some View {
        let sortedOffsets = Array(screenVM.selectedOffsets.sorted())
        let total = CGFloat(max(1, screenVM.configuredMainSeconds))
        return ZStack {
            ForEach(sortedOffsets, id: \.self) { offsetSec in
                let baseAngle: Double = isProgressMode
                    ? Double(CGFloat(offsetSec) / total) * 360.0
                    : Double(offsetSec) / TimeMapper.secondsPerDegree
                let displayAngle = draggingMarkerOffset == offsetSec ? markerDragAngle : baseAngle
                let isDraggingThis = draggingMarkerOffset == offsetSec
                let fired = isProgressMode && ratio <= CGFloat(offsetSec) / total
                let knobScale: CGFloat = isTimeEditable ? (isDraggingThis ? 2.0 : 1.6) : 1.15

                ZStack {
                    Circle()
                        .fill(DSColor.marker)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    Image(systemName: fired ? "bell.slash.fill" : "bell.fill")
                        .font(.system(size: lineWidth * 0.7 * (isTimeEditable ? 1.0 : 0.8), weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: lineWidth * knobScale, height: lineWidth * knobScale)
                .opacity(fired ? 0.35 : 1.0)
                // 링을 따라 돌아도 종 아이콘은 똑바로 서 있도록 역회전
                .rotationEffect(.degrees(90 - displayAngle))
                .frame(width: lineWidth * 2.8, height: lineWidth * 2.8)
                .contentShape(Circle())
                .offset(x: size / 2)
                .rotationEffect(.degrees(displayAngle))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let currentAngle: Double
                                if draggingMarkerOffset == offsetSec {
                                    currentAngle = markerDragAngle
                                } else {
                                    draggingMarkerOffset = offsetSec
                                    currentAngle = Double(offsetSec) / TimeMapper.secondsPerDegree
                                }
                                markerLingerTask?.cancel()
                                lingeringMarkerOffset = nil
                                var newAngle = TimeMapper.angleDelta(
                                    from: value.location,
                                    currentAngle: currentAngle
                                )
                                let mainSec = screenVM.mainMinutes * 60 + screenVM.mainSeconds
                                let maxAngle = Double(mainSec - 10) / TimeMapper.secondsPerDegree
                                newAngle = max(0, min(newAngle, max(0, maxAngle)))
                                markerDragAngle = newAngle
                            }
                            .onEnded { _ in
                                guard let dragOffset = draggingMarkerOffset else { return }
                                let newSec = TimeMapper.angleToSeconds(from: markerDragAngle)
                                let mainSec = screenVM.mainMinutes * 60 + screenVM.mainSeconds
                                screenVM.selectedOffsets.remove(dragOffset)
                                if newSec > 0 && newSec < mainSec {
                                    screenVM.selectedOffsets.insert(newSec)
                                    // 놓은 자리의 라벨을 잠시 유지
                                    lingeringMarkerOffset = newSec
                                    markerLingerTask = Task {
                                        try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                                        guard !Task.isCancelled else { return }
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            lingeringMarkerOffset = nil
                                        }
                                    }
                                }
                                draggingMarkerOffset = nil
                            },
                        including: isTimeEditable ? .all : .none
                    )
                    .rotationEffect(.init(degrees: -90))
                    // 알림 토글 시 노브가 축소+페이드로 나타나고 사라지도록
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screenVM.sortedOffsetsDesc)
        .allowsHitTesting(isTimeEditable)
        .accessibilityHidden(true)
    }

    private func markerDragTooltip(size: CGFloat) -> some View {
        // 드래그 중이면 현재 드래그 위치, 놓은 후에는 확정된 위치에 표시
        let sec: Int
        let angle: Double
        if draggingMarkerOffset != nil {
            sec = TimeMapper.angleToSeconds(from: markerDragAngle)
            angle = markerDragAngle
        } else {
            sec = lingeringMarkerOffset ?? 0
            angle = Double(sec) / TimeMapper.secondsPerDegree
        }
        let timeText = String(format: "%d:%02d", sec / 60, sec % 60)
        let tooltipAngle = angle - 90
        let xOffset = cos(tooltipAngle * .pi / 180) * (size / 2 + 32)
        let yOffset = sin(tooltipAngle * .pi / 180) * (size / 2 + 32)

        return Text(timeText)
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(DSColor.marker)
            .foregroundStyle(.white)
            .cornerRadius(10)
            .offset(x: xOffset, y: yOffset)
            .accessibilityHidden(true)
    }

    private func centerTimeDisplay(fontSize: CGFloat) -> some View {
        Text((screenVM.state == .running || screenVM.state == .overtime) ? screenVM.timeString(from: screenVM.timerVM.remaining) : mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .onTapGesture {
                if isTimeEditable {
                    showTimeInput = true
                }
            }
            // VoiceOver: 다이얼 전체를 "상태 + 시간" 한 덩어리로 안내하고,
            // 드래그 대신 위/아래 스와이프로 시간을 조정할 수 있게 한다.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stateLabel)
            .accessibilityValue(accessibilityTimeValue)
            .accessibilityHint(isTimeEditable
                ? String(localized: "Swipe up or down to adjust the time. Double tap to enter an exact time.")
                : "")
            .accessibilityAddTraits(isTimeEditable ? [.isButton, .updatesFrequently] : .updatesFrequently)
            .accessibilityAdjustableAction { direction in
                guard isTimeEditable else { return }
                switch direction {
                case .increment:
                    adjustTime(by: 60)
                case .decrement:
                    adjustTime(by: -60)
                @unknown default:
                    break
                }
            }
    }

    /// 실행/일시정지/오버타임이 아닐 때만 시간 편집 가능
    /// (발표 모드에서도 다이얼·알림 편집 가능 — 알림이 구간 경계를 정의한다)
    private var isTimeEditable: Bool {
        screenVM.state != .running && screenVM.state != .overtime && screenVM.state != .paused
    }

    /// VoiceOver가 읽어줄 시간 값 (편집 중이면 설정값, 진행 중이면 남은 시간)
    private var accessibilityTimeValue: String {
        if screenVM.state == .running || screenVM.state == .overtime {
            return spokenTime(totalSeconds: max(0, Int(screenVM.timerVM.remaining)))
        }
        return spokenTime(totalSeconds: screenVM.mainMinutes * 60 + screenVM.mainSeconds)
    }

    /// 초를 "N분 M초" 형태의 음성 친화 문자열로 변환
    private func spokenTime(totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 && seconds > 0 {
            return String(localized: "\(minutes) min \(seconds) sec")
        } else if minutes > 0 {
            return String(localized: "\(minutes) min")
        } else {
            return String(localized: "\(seconds) sec")
        }
    }

    /// VoiceOver 위/아래 스와이프 시 시간을 1분 단위로 증감 (0 ~ 최대 120분)
    private func adjustTime(by deltaSeconds: Int) {
        let total = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        let newTotal = max(0, min(TimeMapper.maxSeconds, total + deltaSeconds))
        screenVM.mainMinutes = newTotal / 60
        screenVM.mainSeconds = newTotal % 60
    }

    // MARK: - Derived Section List (발표 모드)

    /// 알림 지점을 경계로 타이머를 구간으로 나눈 리스트
    /// 예: 15분 타이머 + 5분 전 알림 → Section 1 (0:00–10:00), Section 2 (10:00–15:00)
    private var derivedSegments: [(index: Int, startSec: Int, endSec: Int)] {
        let mainSec = isProgressMode
            ? screenVM.configuredMainSeconds
            : screenVM.mainMinutes * 60 + screenVM.mainSeconds
        guard mainSec > 0 else { return [] }
        let boundaries = screenVM.selectedOffsets
            .filter { $0 > 0 && $0 < mainSec }
            .map { mainSec - $0 }
            .sorted()
        let points = [0] + boundaries + [mainSec]
        return (0..<(points.count - 1)).map { i in
            (index: i, startSec: points[i], endSec: points[i + 1])
        }
    }

    private func derivedSectionList(maxHeight: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: DSSpacing.xs) {
                ForEach(derivedSegments, id: \.index) { seg in
                    let isEditingThis = focusedSectionIndex == seg.index
                    HStack(spacing: DSSpacing.sm) {
                        // 링의 해당 구간과 같은 색 — 어느 호가 이 구간인지 연결
                        Circle()
                            .fill(sectionColor(seg.index))
                            .frame(width: 10, height: 10)

                        // 이름 편집 — 비워두면 placeholder("구간 N") 사용
                        TextField(
                            String(localized: "Section \(seg.index + 1)"),
                            text: sectionNameBinding(seg.index)
                        )
                        .font(DSFont.callout.weight(.medium))
                        .disabled(!isTimeEditable)
                        .focused($focusedSectionIndex, equals: seg.index)
                        .submitLabel(.done)
                        .accessibilityLabel(String(localized: "Section name"))

                        Spacer()

                        Text("\(rangeText(seg.startSec)) – \(rangeEndText(seg.endSec))")
                            .font(DSFont.callout.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Text(durationText(seg.endSec - seg.startSec))
                            .font(DSFont.callout.weight(.semibold).monospacedDigit())
                            .foregroundStyle(DSColor.marker)
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isEditingThis
                                ? sectionColor(seg.index).opacity(0.12)
                                : Color(.systemGray6))
                    )
                    .overlay(
                        // 편집 중인 구간은 구간색 테두리로 포커싱
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isEditingThis ? sectionColor(seg.index) : .clear,
                                lineWidth: 1.5
                            )
                    )
                    // 다른 구간을 편집 중이면 이 행은 한 발 물러남
                    .opacity(focusedSectionIndex == nil || isEditingThis ? 1.0 : 0.55)
                    .accessibilityElement(children: .combine)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 16)
            // 알림 토글로 구간이 나뉘거나 합쳐질 때 부드럽게
            .animation(.easeInOut(duration: 0.25), value: screenVM.sortedOffsetsDesc)
            // 편집 포커스 이동 시 하이라이트 전환
            .animation(.easeInOut(duration: 0.2), value: focusedSectionIndex)
        }
        .frame(maxHeight: maxHeight)
        // 리스트를 끌면 키보드가 따라 내려감
        .scrollDismissesKeyboard(.interactively)
    }

    /// 초 → "10:00" 형태 (M:SS 표기 통일)
    private func durationText(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }

    /// 구간 범위 시작 표기 — 타이머의 처음이면 "시작", 경계는 알림 칩과 같은 "종료 기준 N 전"
    private func rangeText(_ sec: Int) -> String {
        guard sec != 0 else { return String(localized: "Start") }
        return boundaryText(sec)
    }

    /// 구간 범위 끝 표기 — 타이머의 끝이면 "종료", 경계는 알림 칩과 같은 "종료 기준 N 전"
    private func rangeEndText(_ sec: Int) -> String {
        guard sec != derivedSegments.last?.endSec else { return String(localized: "End") }
        return boundaryText(sec)
    }

    /// 경계 시각을 알림 칩과 같은 좌표(종료까지 남은 시간)로 표기 — "5:00 전"
    private func boundaryText(_ elapsedSec: Int) -> String {
        let total = derivedSegments.last?.endSec ?? 0
        let remaining = max(0, total - elapsedSec)
        return String(localized: "\(mmss(from: remaining)) left")
    }

    /// 실행 중 현재 진행 중인 구간 (경과 시간 기준)
    /// 발표 모드: 항상 표시 (placeholder 포함)
    /// 타이머 모드: 사용자가 직접 이름을 지은 구간만 표시
    private var currentSegment: (index: Int, name: String)? {
        guard isProgressMode else { return nil }
        let segments = derivedSegments
        guard !segments.isEmpty else { return nil }

        let total = Double(screenVM.configuredMainSeconds)
        let elapsed = total - max(0, screenVM.remaining)
        let seg = segments.first(where: { Double($0.endSec) > elapsed }) ?? segments[segments.count - 1]

        let custom = (screenVM.sectionNames[seg.index] ?? "").trimmingCharacters(in: .whitespaces)
        if !isPresentationMode && custom.isEmpty { return nil }
        return (seg.index, custom.isEmpty ? sectionDisplayName(seg.index) : custom)
    }

    /// 구간 표시 이름 — 사용자 지정 이름이 있으면 그것, 없으면 placeholder
    private func sectionDisplayName(_ index: Int) -> String {
        let custom = (screenVM.sectionNames[index] ?? "").trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? String(localized: "Section \(index + 1)") : custom
    }

    /// 구간 이름 바인딩 — 빈 값이면 저장하지 않고 placeholder로 복귀
    private func sectionNameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { screenVM.sectionNames[index] ?? "" },
            set: { screenVM.sectionNames[index] = $0.isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder
    private var nextAlertInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                    .dsScaledFont(16, weight: .semibold, relativeTo: .body, maxSize: 22)
                Text(screenVM.nextAlertText)
                    .dsScaledFont(17, weight: .semibold, design: .rounded, relativeTo: .body, maxSize: 24)
            }
            .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal, 16)
    }

    private func mmss(from sec: Int) -> String {
        let t = max(0, sec)
        return TimeMapper.formatTime(minutes: t / 60, seconds: t % 60)
    }

    private func mmss(sec: Int, min: Int) -> String {
        TimeMapper.formatTime(minutes: min, seconds: sec)
    }
    
    func snappedAngle(from rawAngle: Double) -> Double {
        TimeMapper.snappedAngle(from: rawAngle)
    }
    
    func onDrag(value: DragGesture.Value) {
        let newAngle = TimeMapper.angleDelta(
            from: value.location,
            currentAngle: screenVM.mainAngle
        )
        screenVM.mainAngle = newAngle
    }

    private var stateColor: Color {
        switch screenVM.state {
        case .idle:
            return .gray
        case .running:
            return .green
        case .paused:
            return .orange
        case .finished:
            return .blue
        case .overtime:
            return .red
        }
    }

    private var stateText: LocalizedStringKey {
        switch screenVM.state {
        case .idle:
            return "Ready"
        case .running:
            return "In Progress"
        case .paused:
            return "Paused"
        case .finished:
            return "Done"
        case .overtime:
            return "Overtime"
        }
    }

    /// VoiceOver 라벨용 상태 문자열 ("Timer, 준비됨" 형태로 시간 값과 결합)
    private var stateLabel: String {
        let state: String
        switch screenVM.state {
        case .idle:
            state = String(localized: "Ready")
        case .running:
            state = String(localized: "In Progress")
        case .paused:
            state = String(localized: "Paused")
        case .finished:
            state = String(localized: "Done")
        case .overtime:
            state = String(localized: "Overtime")
        }
        return String(localized: "Timer, \(state)")
    }

    // 왼쪽 버튼 (Cancel) - Start Timer 후에만 표시
    @ViewBuilder
    private func leftButton(buttonSize: CGFloat) -> some View {
        if screenVM.state != .idle {
            Button(action: {
                // 비율 링 → 절대 각도 다이얼로 역모핑
                withAnimation(.easeInOut(duration: 0.4)) {
                    screenVM.cancel()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.plain,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Cancel Timer"))
        }
    }

    // 오른쪽 버튼 (재생/Pause)
    @ViewBuilder
    private func rightButton(buttonSize: CGFloat) -> some View {
        switch screenVM.state {
        case .idle, .finished:
            Button(action: {
                if isPresentationMode {
                    // 알림 경계로부터 구간을 생성한 뒤 발표 시작
                    screenVM.syncSectionsFromAlerts()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screenVM.startPresentation()
                    }
                    return
                }
                screenVM.applyCurrentSettings()
                // 설정 호(절대 각도)가 100% 링으로 차오르는 모핑
                withAnimation(.easeInOut(duration: 0.4)) {
                    screenVM.start()
                }
            }) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.positive,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Start Timer"))

        case .running, .overtime:
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    screenVM.pause()
                }
            }) {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.negativeSoft,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Pause Timer"))

        case .paused:
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    screenVM.resume()
                }
            }) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.positive,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Resume Timer"))
        }
    }

    // 버튼들을 수평으로 배치
    @ViewBuilder
    private func buttonRow(buttonSize: CGFloat) -> some View {
        HStack(spacing: buttonSize * 0.5) {
            leftButton(buttonSize: buttonSize)
            rightButton(buttonSize: buttonSize)
        }
    }
}

#Preview {
    TimerMainView()
        .environmentObject(TimerScreenViewModel())
}
