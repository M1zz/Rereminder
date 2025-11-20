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
        VStack(spacing: 16) {
            // 상태 표시
            HStack(spacing: 4) {
                Circle()
                    .fill(timerViewModel.isPaused ? Color.orange : Color.green)
                    .frame(width: 6, height: 6)
                Text(timerViewModel.isPaused ? "일시정지" : "진행 중")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Spacer(minLength: 0)

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

                // 진행 방향 화살표 (원 안쪽, 12시 방향)
                if !timerViewModel.isPaused {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.3))
                        .offset(y: -35)
                }

                // 알림 마커 (주황색 점 + 라벨)
                if timerViewModel.notificationTime > 0 {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(alertMarkerOffset(ringSize: 120, lineWidth: 8))

                    Text("\(timerViewModel.notificationTime / 60)분")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                        .offset(alertLabelOffset(ringSize: 120))
                }

                // 중앙 시간 표시
                Text(timerViewModel.timeRemaining.formattedTimeString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
            }

            Spacer(minLength: 0)

            // 버튼 (아이콘 + 텍스트)
            HStack(spacing: 12) {
                Button {
                    path = []
                    timerViewModel.stop()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                        Text("취소")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .frame(height: 50)

                Button {
                    timerViewModel.togglePause()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: timerViewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(timerViewModel.isPaused ? "재개" : "일시정지")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(height: 50)
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
    
    private var alertMarkerProgress: Double {
        guard timerViewModel.mainDuration > 0 else { return 0 }
        // Elapsed fraction when the alert should fire. Example: 10m total, alert at 3m remaining -> 0.7
        let value = 1.0 - (Double(timerViewModel.notificationTime) / Double(timerViewModel.mainDuration))
        return min(max(value, 0.0), 1.0)
    }
    
    private func alertMarkerOffset(ringSize: CGFloat, lineWidth: CGFloat) -> CGSize {
        let radius = ringSize / 2
        let r = radius
        let angle = Angle.degrees(-90 - (360 * alertMarkerProgress))
        let x = cos(angle.radians) * r
        let y = sin(angle.radians) * r
        return CGSize(width: x, height: y)
    }

    private func alertLabelOffset(ringSize: CGFloat) -> CGSize {
        let radius = ringSize / 2
        let r = radius + 12
        let angle = Angle.degrees(-90 - (360 * alertMarkerProgress))
        let x = cos(angle.radians) * r
        let y = sin(angle.radians) * r
        return CGSize(width: x, height: y)
    }
}

