//
//  TimerMainView.swift
//  Toki
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

    private var ratio: CGFloat {
        return CGFloat(max(0, min(1, remaining / TimeInterval(TimeMapper.maxSeconds))))
    }
    private var markers: [CGFloat] {
        return screenVM.selectedOffsets
            .sorted()
            .map { offset in
                // offset(초)을 각도로 변환 후 360도 대비 비율로 계산
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
                // 빠른설정 영역
                Group {
                    if screenVM.state != .running {
                        TimePresetButtons(
                            screenVM: screenVM,
                            onShowTimeInput: { showTimeInput = true }
                        )
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

                // 다음 알림 정보 (원 밖 아래쪽)
                if !screenVM.nextAlertText.isEmpty {
                    nextAlertInfo
                        .padding(.vertical, spacing * 3)
                }

                Divider()
                    .padding(.vertical, spacing * 2)

                prealertSection
                    .padding(.bottom, spacing * 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showTimeInput) {
            TimeInputSheet(screenVM: screenVM, isPresented: $showTimeInput)
                .presentationDetents([.height(300)])
        }
        .fullScreenCover(isPresented: $screenVM.showTimerAlert) {
            TimerAlertView {
                print("🎯 TimerAlertView 확인 버튼 클릭 - 닫기")
                screenVM.showTimerAlert = false
            }
        }
        .onChange(of: screenVM.showTimerAlert) { oldValue, newValue in
            print("🔔 showTimerAlert 변경: \(oldValue) → \(newValue)")
        }
        .alert("알림 권한이 필요합니다", isPresented: $screenVM.showPermissionWarning) {
            Button("설정으로 이동", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("나중에", role: .cancel) {
                // 권한 없이 타이머 시작
                screenVM.showToast?("⚠️ 알림 권한 없이 시작됨")
                screenVM.timerVM.start()
            }
        } message: {
            Text("타이머 알림을 받으려면 알림 권한이 필요합니다.\n\n권한이 없으면:\n• 예비 알림을 받을 수 없습니다\n• 종료 알림을 받을 수 없습니다\n• 백그라운드에서 알림이 작동하지 않습니다\n\n설정에서 알림 권한을 켜주세요.")
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
    }

    private func clockView(size: CGFloat, lineWidth: CGFloat, geometry: GeometryProxy, buttonSize: CGFloat) -> some View {
        ZStack {
            backgroundCircle(size: size, lineWidth: lineWidth)
            progressCircle(size: size, lineWidth: lineWidth)

            // 타이머 실행 중이고 5분 이상 남았을 때만 >> 표시
            if screenVM.state == .running && screenVM.timerVM.remaining > 300 {
                progressIndicator(size: size)
            }

            clockMarkers(size: size, lineWidth: lineWidth)

            if screenVM.state != .running && screenVM.state != .paused {
                dragPointer(size: size, lineWidth: lineWidth)
            }

            if isDragging && screenVM.state != .running && screenVM.state != .paused {
                dragTooltip(size: size, fontSize: min(geometry.size.width, geometry.size.height) * 0.03)
            }

            let fontSize = min(geometry.size.width, geometry.size.height) * 0.16

            centerTimeDisplay(fontSize: fontSize)

            statusText(fontSize: fontSize)

            // 버튼들을 숫자 아래에 배치
            buttonRow(buttonSize: buttonSize)
                .offset(y: fontSize * 1.3)
        }
    }

    private func progressIndicator(size: CGFloat) -> some View {
        // 타이머 진행에 따라 화살표가 움직임 (시작 지점 근처에서 시작)
        let currentAngle = screenVM.timerVM.remaining / TimeMapper.secondsPerDegree

        // 화살표를 실제 진행 위치보다 약간 앞서서 배치
        let indicatorAngle = currentAngle - 90 - 5  // 12시 방향(-90)에서 시작
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
    }

    private func progressCircle(size: CGFloat, lineWidth: CGFloat) -> some View {
        let currentAngle: Double
        let circleColor: Color

        if screenVM.state == .running || screenVM.state == .paused {
            // 실행/일시정지 중: 남은 시간 기준으로 표시
            currentAngle = screenVM.timerVM.remaining / TimeMapper.secondsPerDegree
            circleColor = Color.accentColor
        } else if screenVM.state == .overtime {
            // 오버타임: 빨간색 원형 (음수 시간은 각도로 변환하지 않고 0으로 표시)
            currentAngle = 0
            circleColor = Color.red
        } else {
            // 대기/완료 상태: 설정된 시간 표시
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
    }

    private func clockMarkers(size: CGFloat, lineWidth: CGFloat) -> some View {
        ClockMarkers(
            remaining: ratio,
            markers: markers,
            markerOffsets: Array(screenVM.selectedOffsets.sorted()),
            dotSize: lineWidth,
            inset: 0,
            upcoming: true,
            showLabels: true
        )
        .frame(width: size, height: size)
    }

    private func dragPointer(size: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth, height: lineWidth)
            .offset(x: size / 2)
            .rotationEffect(.degrees(screenVM.mainAngle))
            .gesture(dragGesture)
            .rotationEffect(.init(degrees: -90))
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
    }

    private func centerTimeDisplay(fontSize: CGFloat) -> some View {
        Text((screenVM.state == .running || screenVM.state == .overtime) ? screenVM.timeString(from: screenVM.timerVM.remaining) : mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .onTapGesture {
                if screenVM.state != .running && screenVM.state != .overtime && screenVM.state != .paused {
                    showTimeInput = true
                }
            }
    }

    @ViewBuilder
    private var nextAlertInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 16, weight: .semibold))
                Text(screenVM.nextAlertText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
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

    @ViewBuilder
    private var prealertSection: some View {
        let mainSeconds = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        let presets = Timer.presetOffsetsSec

        VStack(alignment: .leading, spacing: 8) {
            Text("예비 알림")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { sec in
                        prealertToggle(sec: sec, mainSeconds: mainSeconds)
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private func prealertToggle(sec: Int, mainSeconds: Int) -> some View {
        let isDisabled = sec >= mainSeconds
        return Toggle(
            isOn: Binding(
                get: { screenVM.selectedOffsets.contains(sec) },
                set: { on in
                    if on {
                        screenVM.selectedOffsets.insert(sec)
                    } else {
                        screenVM.selectedOffsets.remove(sec)
                    }
                    screenVM.showPrealertToast(for: sec, isEnabled: on)
                }
            )
        ) {
            Text("\(sec/60) \(String(localized: "분"))")
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .disabled(isDisabled)
    }

    private func mmss(from sec: Int) -> String {
        let t = max(0, sec)
        let m = t / 60
        let s = t % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func mmss(sec: Int, min: Int) -> String {
        return String(format: "%02d:%02d", min, sec)
    }
    
    func snappedAngle(from rawAngle: Double) -> Double {
        let totalSeconds = rawAngle * TimeMapper.secondsPerDegree
        let snappedSeconds = (totalSeconds / TimeMapper.secondsPerDegree).rounded() * TimeMapper.secondsPerDegree
        return snappedSeconds / TimeMapper.secondsPerDegree  // 도(degree) 단위로 환산
    }
    
    func onDrag(value: DragGesture.Value) {
        let vector = CGVector(dx: value.location.x, dy: value.location.y)
        let radians = atan2(vector.dy, vector.dx)  // 벡터가 x축과 이루는 각도를 구함
        var newAngle = radians * 180 / .pi
        if newAngle < 0 { newAngle = 360 + newAngle }

        var d = newAngle - fmod(screenVM.mainAngle, 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }

        var next = screenVM.mainAngle + d
        if next > TimeMapper.maxAngle { next = TimeMapper.maxAngle }
        if next < 0 { next = 0 }

        let snapped = snappedAngle(from: next)
        screenVM.mainAngle = snapped
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
            return "대기 중"
        case .running:
            return "진행 중"
        case .paused:
            return "일시정지됨"
        case .finished:
            return "완료"
        case .overtime:
            return "초과 진행 중"
        }
    }

    // 왼쪽 버튼 (취소) - 타이머 시작 후에만 표시
    @ViewBuilder
    private func leftButton(buttonSize: CGFloat) -> some View {
        if screenVM.state != .idle {
            Button(action: { screenVM.cancel() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: Color.plain,
                size: buttonSize
            ))
            .accessibilityLabel("타이머 취소")
        }
    }

    // 오른쪽 버튼 (재생/일시정지)
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
                tint: Color.positive,
                size: buttonSize
            ))
            .accessibilityLabel("타이머 시작")

        case .running, .overtime:
            Button(action: { screenVM.pause() }) {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: Color.bitNegative,
                size: buttonSize
            ))
            .accessibilityLabel("타이머 일시정지")

        case .paused:
            Button(action: { screenVM.resume() }) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: Color.positive,
                size: buttonSize
            ))
            .accessibilityLabel("타이머 재개")
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

// 상태 표시 인디케이터 (깜빡이는 동그라미)
struct StatusIndicator: View {
    let state: TimerState
    @State private var isAnimating = false
    @ScaledMetric private var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(stateColor)
            .frame(width: size, height: size)
            .opacity(shouldBlink ? (isAnimating ? 1.0 : 0.3) : 1.0)
            .onAppear {
                if shouldBlink {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
    }

    private var shouldBlink: Bool {
        state == .idle
    }

    private var stateColor: Color {
        switch state {
        case .idle:
            return .yellow
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
}

#Preview {
    TimerMainView()
        .environmentObject(TimerScreenViewModel())

}
