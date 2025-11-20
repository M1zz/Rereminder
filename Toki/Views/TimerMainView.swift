//
//  TimerMainView.swift
//  Toki
//
//  Created by Oh Seojin on 9/24/25.
//

import SwiftUI

struct TimerMainView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    var size: CGFloat = 240
    var lineWidth: CGFloat = 20
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
            .map { CGFloat($0) / TimeInterval(TimeMapper.maxSeconds) }
    }

    var body: some View {
        VStack(spacing: 24) {
            statusText
                .padding(.top, 8)

            // 빠른설정 영역 (고정 높이)
            Group {
                if screenVM.state != .running {
                    TimePresetButtons(screenVM: screenVM)
                        .padding(.horizontal, 4)
                } else {
                    // 실행 중일 때 빈 공간으로 높이 유지
                    Color.clear
                        .frame(height: 50)
                }
            }

            Spacer()
                .frame(height: 8)

            clockView

            Spacer()
                .frame(height: 8)

            TimerButton(
                state: screenVM.timerVM.state,
                onStart: {
                    screenVM.applyCurrentSettings()
                    screenVM.start()
                },
                onPause: { screenVM.pause() },
                onResume: { screenVM.resume() },
                onCancel: { screenVM.cancel() }
            )

            Divider()
                .padding(.vertical, 8)

            prealertSection
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showTimeInput) {
            TimeInputSheet(screenVM: screenVM, isPresented: $showTimeInput)
                .presentationDetents([.height(300)])
        }
    }

    private var statusText: some View {
        Text(stateText)
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
    }

    private var clockView: some View {
        ZStack {
            backgroundCircle
            progressCircle

            // 타이머 실행 중이고 3분 이상 남았을 때만 >> 표시
            if screenVM.state == .running && screenVM.timerVM.remaining > 180 {
                progressIndicator
            }

            clockMarkers

            if screenVM.state != .running {
                dragPointer
            }

            if isDragging && screenVM.state != .running {
                dragTooltip
            }

            centerTimeDisplay
        }
    }

    private var progressIndicator: some View {
        let currentProgress = screenVM.timerVM.remaining / TimeMapper.maxAngle / TimeMapper.secondsPerDegree
        let angle = currentProgress * 360 - 90  // -90은 12시 방향 시작

        // 화살표를 진행 방향(시계방향) 앞쪽에 배치
        let indicatorAngle = angle - 10  // 진행 방향보다 10도 앞서서 배치
        let radius = size / 2 - 2  // 원 라인 위
        let xOffset = cos(indicatorAngle * .pi / 180) * radius
        let yOffset = sin(indicatorAngle * .pi / 180) * radius

        // 화살표가 시계방향을 가리키도록 회전
        let rotationAngle = indicatorAngle - 90

        return ZStack {
            // 배경 (가독성을 위한 그림자)
            Text(">>")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.3))
                .rotationEffect(.degrees(rotationAngle))
                .offset(x: xOffset + 1, y: yOffset + 1)

            // 메인 화살표
            Text(">>")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
                .rotationEffect(.degrees(rotationAngle))
                .offset(x: xOffset, y: yOffset)
        }
    }

    private var backgroundCircle: some View {
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

    private var progressCircle: some View {
        let trimTo: Double
        if screenVM.state == .running || screenVM.state == .paused {
            // 실행/일시정지 중: 남은 시간 기준으로 표시
            trimTo = screenVM.timerVM.remaining / TimeMapper.maxAngle / TimeMapper.secondsPerDegree
        } else {
            // 대기/완료 상태: 설정된 시간 표시
            trimTo = screenVM.mainAngle / TimeMapper.maxAngle
        }

        return Circle()
            .trim(from: 0, to: trimTo)
            .stroke(
                Color.accentColor,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size, height: size)
            .rotationEffect(.init(degrees: -90))
    }

    private var clockMarkers: some View {
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

    private var dragPointer: some View {
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

    private var dragTooltip: some View {
        let timeText = mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes)
        let xOffset = cos(dragTooltipAngle * .pi / 180) * (size / 2 + 40)
        let yOffset = sin(dragTooltipAngle * .pi / 180) * (size / 2 + 40)

        return Text(timeText)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(8)
            .offset(x: xOffset, y: yOffset)
    }

    private var centerTimeDisplay: some View {
        Text(screenVM.state == .running ? screenVM.timeString(from: screenVM.timerVM.remaining) : mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes))
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .monospacedDigit()
            .onTapGesture {
                if screenVM.state != .running {
                    showTimeInput = true
                }
            }
    }

    private var prealertSection: some View {
        let mainSeconds = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        let presets = Timer.presetOffsetsSec

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("예비 알림")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    ForEach(presets, id: \.self) { sec in
                        prealertToggle(sec: sec, mainSeconds: mainSeconds)
                    }
                }
            }
        }
    }

    private func prealertToggle(sec: Int, mainSeconds: Int) -> some View {
        let isDisabled = sec >= mainSeconds
        return Toggle(
            "\(sec/60)분",
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
        )
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
        
        var d = newAngle - screenVM.mainAngle
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }

        var next = screenVM.mainAngle + d
        if next > 360 { next = 360 }
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
        }
    }

    private var stateText: String {
        switch screenVM.state {
        case .idle:
            return "대기 중"
        case .running:
            return "진행 중"
        case .paused:
            return "일시정지됨"
        case .finished:
            return "완료"
        }
    }
}

#Preview {
    TimerMainView()
        .environmentObject(TimerScreenViewModel())

}
