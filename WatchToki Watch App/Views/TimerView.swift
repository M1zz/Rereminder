//
//  TimerView.swift
//  Toki
//
//  Created by 내꺼다 on 8/8/25.
//

import SwiftUI

public struct TimerView: View {
    @StateObject private var timerViewModel: TimerViewModel
    @Binding var path: [NavigationTarget]

    init(timerViewModel: TimerViewModel, path: Binding<[NavigationTarget]>) {
        self._timerViewModel = StateObject(wrappedValue: timerViewModel)
        self._path = path
    }

    public var body: some View {
        VStack(spacing: 8) {
            // 상태 표시
            HStack(spacing: 4) {
                Circle()
                    .fill(timerViewModel.isPaused ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(timerViewModel.isPaused ? String(localized: "Pause") : String(localized: "In Progress"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Spacer(minLength: 4)

            ZStack {
                // 배경 원
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)

                // 진행 원
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // 진행 방향 화살표 (3min 이상 남았을 때만)
                if !timerViewModel.isPaused && timerViewModel.timeRemaining > 180 {
                    progressIndicator
                }

                // Pre-alerts 마커들 (다중)
                ForEach(timerViewModel.prealertOffsets, id: \.self) { offset in
                    let offsetSeconds = offset * 60
                    if timerViewModel.mainDuration > offsetSeconds {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .offset(alertMarkerOffset(offsetSeconds: offsetSeconds, ringSize: 120))

                        Text("\(offset)min")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                            .offset(alertLabelOffset(offsetSeconds: offsetSeconds, ringSize: 120))
                    }
                }

                // 단일 알림 마커 (하위 호환성)
                if timerViewModel.notificationTime > 0 && timerViewModel.prealertOffsets.isEmpty {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(alertMarkerOffset(offsetSeconds: timerViewModel.notificationTime, ringSize: 120))

                    Text("\(timerViewModel.notificationTime / 60)min")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .offset(alertLabelOffset(offsetSeconds: timerViewModel.notificationTime, ringSize: 120))
                }

                // 중앙 시간 표시
                Text(timerViewModel.timeRemaining.formattedTimeString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            }

            Spacer(minLength: 4)

            // 버튼 (아이콘만)
            HStack(spacing: 12) {
                Button {
                    path = []
                    timerViewModel.stop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .frame(height: 20)

                Button {
                    timerViewModel.togglePause()
                } label: {
                    Image(systemName: timerViewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(height: 20)
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { timerViewModel.start() }
        .onDisappear { timerViewModel.stop() }
        .navigationBarBackButtonHidden(true)
    }

    private var progress: Double {
        guard timerViewModel.mainDuration > 0 else { return 0 }
        return Double(timerViewModel.timeRemaining) / Double(timerViewModel.mainDuration)
    }

    private var progressIndicator: some View {
        let currentProgress = progress
        let angle = (currentProgress * 360) - 90  // -90은 12시 방향 Start

        // 화살표를 진행 방향(시계방향) 앞쪽에 배치
        let indicatorAngle = angle - 10  // 진행 방향보다 10도 앞서서 배치
        let radius: CGFloat = 60 - 2  // 원 라인 위
        let xOffset = cos(indicatorAngle * .pi / 180) * radius
        let yOffset = sin(indicatorAngle * .pi / 180) * radius

        // 화살표가 시계방향을 가리키도록 회전
        let rotationAngle = indicatorAngle - 90

        return ZStack {
            // 배경 (가독성을 위한 그림자)
            Text(">>")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.3))
                .rotationEffect(.degrees(rotationAngle))
                .offset(x: xOffset + 1, y: yOffset + 1)

            // 메인 화살표
            Text(">>")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
                .rotationEffect(.degrees(rotationAngle))
                .offset(x: xOffset, y: yOffset)
        }
    }

    private func alertMarkerProgress(offsetSeconds: Int) -> Double {
        guard timerViewModel.mainDuration > 0 else { return 0 }
        // 알림이 울릴 시점의 남은 시간 비율 (역방향)
        let remainingAtAlert = Double(offsetSeconds) / Double(timerViewModel.mainDuration)
        return remainingAtAlert
    }

    private func alertMarkerOffset(offsetSeconds: Int, ringSize: CGFloat) -> CGSize {
        let radius = ringSize / 2
        let progress = alertMarkerProgress(offsetSeconds: offsetSeconds)
        // 시계 방향으로 줄어드는 방향 (12시에서 Start)
        let angle = Angle.degrees(-90 + (360 * progress))
        let x = cos(angle.radians) * radius
        let y = sin(angle.radians) * radius
        return CGSize(width: x, height: y)
    }

    private func alertLabelOffset(offsetSeconds: Int, ringSize: CGFloat) -> CGSize {
        let radius = ringSize / 2
        let r = radius + 12
        let progress = alertMarkerProgress(offsetSeconds: offsetSeconds)
        let angle = Angle.degrees(-90 + (360 * progress))
        let x = cos(angle.radians) * r
        let y = sin(angle.radians) * r
        return CGSize(width: x, height: y)
    }
}
