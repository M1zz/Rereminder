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
    @State private var dragTooltipAngle: Double = 0
    @State private var draggingMarkerOffset: Int? = nil
    @State private var markerDragAngle: Double = 0

    private var ratio: CGFloat {
        return CGFloat(max(0, min(1, remaining / TimeInterval(TimeMapper.maxSeconds))))
    }
    private var markers: [CGFloat] {
        return screenVM.sortedOffsetsDesc.reversed()
            .map { offset in
                CGFloat(offset) / TimeMapper.secondsPerDegree / 360.0
            }
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            let clockSize = min(availableWidth * 0.85, availableHeight * 0.55)
            let lineWidth = clockSize * 0.083
            let spacing = availableHeight * 0.01
            let buttonSize = clockSize * 0.18

            VStack(spacing: 0) {
                // 빠른Settings 영역
                Group {
                    if screenVM.state != .running {
                        TimePresetButtons(screenVM: screenVM)
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

                // Next 알림 Info (원 밖 아래쪽)
                if !screenVM.nextAlertText.isEmpty {
                    nextAlertInfo
                        .padding(.vertical, spacing * 3)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                screenVM.timerVM.start()
            }
        } message: {
            Text("Notification permission is required for timer alerts.\n\nWithout permission:\n• You won't receive pre-alerts\n• You won't receive end alerts\n• Notifications won't work in background\n\nPlease enable notifications in Settings.")
        }
    }

    @ViewBuilder
    private func statusText(fontSize: CGFloat) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                StatusIndicator(state: screenVM.state)
                Text(stateText)
                    .font(.system(size: fontSize * 0.45, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .offset(y: -fontSize * 0.8)  // 중앙 시간 위쪽에 배치
        .accessibilityHidden(true)  // 상태는 중앙 시간 라벨로 통합 안내
    }

    private func clockView(size: CGFloat, lineWidth: CGFloat, geometry: GeometryProxy, buttonSize: CGFloat) -> some View {
        ZStack {
            backgroundCircle(size: size, lineWidth: lineWidth)
            progressCircle(size: size, lineWidth: lineWidth)

            // Timer 실행 중이고 5min 이상 남았을 때만 >> 표시
            if screenVM.state == .running && screenVM.timerVM.remaining > 300 {
                progressIndicator(size: size)
            }

            clockMarkers(size: size, lineWidth: lineWidth)

            if screenVM.state != .running && screenVM.state != .paused {
                dragPointer(size: size, lineWidth: lineWidth)
            }

            if screenVM.state != .running && screenVM.state != .paused {
                markerDragHandles(size: size, lineWidth: lineWidth)
            }

            if isDragging && screenVM.state != .running && screenVM.state != .paused {
                dragTooltip(size: size, fontSize: min(geometry.size.width, geometry.size.height) * 0.03)
            }

            if draggingMarkerOffset != nil {
                markerDragTooltip(size: size, fontSize: min(geometry.size.width, geometry.size.height) * 0.03)
            }

            let fontSize = min(geometry.size.width, geometry.size.height) * 0.16

            centerTimeDisplay(fontSize: fontSize)

            statusText(fontSize: fontSize)

            // 버튼들을 숫자 아래에 배치
            buttonRow(buttonSize: buttonSize)
                .offset(y: fontSize * 1.3)
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

    private func progressIndicator(size: CGFloat) -> some View {
        // Timer 진행에 따라 화살표가 움직임 (Start 지점 근처에서 Start)
        let currentAngle = screenVM.timerVM.remaining / TimeMapper.secondsPerDegree

        // 화살표를 실제 진행 위치보다 약간 앞서서 배치
        let indicatorAngle = currentAngle - 90 - 5  // 12시 방향(-90)에서 Start
        let radius = size / 2 - 2  // 원 라인 위
        let xOffset = cos(CGFloat(indicatorAngle) * .pi / 180) * radius
        let yOffset = sin(CGFloat(indicatorAngle) * .pi / 180) * radius

        // 화살표가 시계방향을 가리키도록 회전
        let rotationAngle = indicatorAngle - 90
        let fontSize = size * 0.083

        return ZStack {
            // 배경 (가독성을 위한 그림자)
            Text(">>")
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.3))
                .rotationEffect(.degrees(Double(rotationAngle)))
                .offset(x: xOffset + 1, y: yOffset + 1)

            // 메인 화살표
            Text(">>")
                .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
                .rotationEffect(.degrees(Double(rotationAngle)))
                .offset(x: xOffset, y: yOffset)
        }
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
        let currentAngle: Double
        let circleColor: Color

        if screenVM.state == .running || screenVM.state == .paused {
            // 실행/Pause 중: 남은 시간 기준으로 표시
            currentAngle = screenVM.timerVM.remaining / TimeMapper.secondsPerDegree
            circleColor = Color.accentColor
        } else if screenVM.state == .overtime {
            // 오버타임: 빨간색 원형 (음수 시간은 각도로 변환하지 않고 0으로 표시)
            currentAngle = 0
            circleColor = Color.red
        } else {
            // 대기/Done 상태: Settings된 시간 표시
            currentAngle = screenVM.mainAngle
            circleColor = Color.accentColor
        }

        return ZStack {
            // 첫 번째 바퀴 (0-360도): 기본 색상
            Circle()
                .trim(from: 0, to: min(1.0, max(0, currentAngle) / 360.0))
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
            if currentAngle > 360 {
                Circle()
                    .trim(from: 0, to: min(1.0, (currentAngle - 360) / 360.0))
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
            showLabels: true
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
            }
    }

    private func dragTooltip(size: CGFloat, fontSize: CGFloat) -> some View {
        let timeText = mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes)
        let xOffset = cos(dragTooltipAngle * .pi / 180) * (size / 2 + fontSize * 2.5)
        let yOffset = sin(dragTooltipAngle * .pi / 180) * (size / 2 + fontSize * 2.5)

        return Text(timeText)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .padding(.horizontal, fontSize * 0.75)
            .padding(.vertical, fontSize * 0.375)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(fontSize * 0.5)
            .offset(x: xOffset, y: yOffset)
            .accessibilityHidden(true)
    }

    private func markerDragHandles(size: CGFloat, lineWidth: CGFloat) -> some View {
        let sortedOffsets = Array(screenVM.selectedOffsets.sorted())
        return ZStack {
            ForEach(sortedOffsets, id: \.self) { offsetSec in
                let angle = Double(offsetSec) / TimeMapper.secondsPerDegree
                let displayAngle = draggingMarkerOffset == offsetSec ? markerDragAngle : angle
                Circle()
                    .fill(Color.clear)
                    .frame(width: lineWidth * 2.5, height: lineWidth * 2.5)
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
                                }
                                draggingMarkerOffset = nil
                            }
                    )
                    .rotationEffect(.init(degrees: -90))
            }
        }
        .accessibilityHidden(true)
    }

    private func markerDragTooltip(size: CGFloat, fontSize: CGFloat) -> some View {
        let dragSec = TimeMapper.angleToSeconds(from: markerDragAngle)
        let mins = dragSec / 60
        let secs = dragSec % 60
        let timeText = String(format: "%d:%02d", mins, secs)
        let tooltipAngle = markerDragAngle - 90
        let xOffset = cos(tooltipAngle * .pi / 180) * (size / 2 + fontSize * 2.5)
        let yOffset = sin(tooltipAngle * .pi / 180) * (size / 2 + fontSize * 2.5)

        return Text(timeText)
            .font(.system(size: fontSize, weight: .medium, design: .rounded))
            .padding(.horizontal, fontSize * 0.75)
            .padding(.vertical, fontSize * 0.375)
            .background(Color.orange)
            .foregroundStyle(.white)
            .cornerRadius(fontSize * 0.5)
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
            Button(action: { screenVM.cancel() }) {
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
                screenVM.applyCurrentSettings()
                screenVM.start()
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
            Button(action: { screenVM.pause() }) {
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
            Button(action: { screenVM.resume() }) {
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
