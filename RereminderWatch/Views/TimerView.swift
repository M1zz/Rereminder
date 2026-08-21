//
//  TimerView.swift
//  Rereminder
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
        VStack(spacing: DSSpacing.sm) {
            // 상태 표시 (색 + 텍스트로 함께 전달)
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: timerViewModel.isPaused ? "pause.fill" : "play.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(timerViewModel.isPaused ? DSColor.statePaused : DSColor.stateRunning)
                Text(timerViewModel.isPaused ? String(localized: "Pause") : String(localized: "In Progress"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, DSSpacing.xxs)
            .accessibilityElement(children: .combine)

            Spacer(minLength: 4)

            ZStack {
                // 배경 원
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: Self.ringWidth)
                    .frame(width: Self.ringSize, height: Self.ringSize)

                // 진행 원 (바깥 = 전체 남은 시간)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round)
                    )
                    .frame(width: Self.ringSize, height: Self.ringSize)
                    .rotationEffect(.degrees(-90))
                    .dsAnimation(.linear(duration: 1), value: progress)

                // 안쪽 = 지금 지나는 구간이 얼마 남았나 (이중 링, iPhone 과 같은 규칙)
                if let section = sectionProgress {
                    SectionInnerRing(progress: section,
                                     diameter: Self.sectionRingSize,
                                     lineWidth: Self.sectionRingWidth,
                                     // 4pt 링 위의 흰 점은 먼지처럼 보인다
                                     showsEdgeDot: false)
                }

                // 진행 방향 화살표 (3min 이상 남았을 때만)
                if !timerViewModel.isPaused && timerViewModel.timeRemaining > 180 {
                    progressIndicator
                        .accessibilityHidden(true)
                }

                // Pre-alerts 마커들 (다중)
                ForEach(timerViewModel.prealertOffsets, id: \.self) { offset in
                    if timerViewModel.mainDuration > offset {
                        Circle()
                            .fill(DSColor.marker)
                            .frame(width: 8, height: 8)
                            .offset(alertMarkerOffset(offsetSeconds: offset, ringSize: Self.ringSize))

                        Text("\(offset / 60)min")
                            .dsScaledFont(9, weight: .bold, design: .rounded, relativeTo: .caption2, maxSize: 13)
                            .foregroundColor(DSColor.marker)
                            .offset(alertLabelOffset(offsetSeconds: offset, ringSize: Self.ringSize))
                    }
                }

                // 단일 알림 마커 (하위 호환성)
                if timerViewModel.notificationTime > 0 && timerViewModel.prealertOffsets.isEmpty {
                    Circle()
                        .fill(DSColor.marker)
                        .frame(width: 8, height: 8)
                        .offset(alertMarkerOffset(offsetSeconds: timerViewModel.notificationTime, ringSize: Self.ringSize))

                    Text("\(timerViewModel.notificationTime / 60)min")
                        .dsScaledFont(9, weight: .bold, design: .rounded, relativeTo: .caption2, maxSize: 13)
                        .foregroundColor(DSColor.marker)
                        .offset(alertLabelOffset(offsetSeconds: timerViewModel.notificationTime, ringSize: Self.ringSize))
                }

                // 중앙 시간 표시 — 이중 링이면 큰 숫자는 **이 구간**의 남은 시간,
                // 전체는 그 아래 작은 줄로 내려간다(iPhone 다이얼과 같은 문법).
                VStack(spacing: 1) {
                    Text((sectionProgress?.remainingSec ?? timerViewModel.timeRemaining).formattedTimeString)
                        .dsScaledFont(36, weight: .bold, design: .rounded, relativeTo: .title, maxSize: 48)
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)

                    if sectionProgress != nil {
                        Text("Total: \(timerViewModel.timeRemaining.formattedTimeString)")
                            .dsScaledFont(11, weight: .medium, design: .rounded, relativeTo: .caption2, maxSize: 15)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                }
                // 안쪽 링·바깥 링·종 마커를 다 덮지 않도록 원 안쪽으로 가둔다
                .frame(maxWidth: Self.ringSize - Self.ringWidth * 3)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(sectionProgress == nil
                ? String(localized: "Remaining time: \(timerViewModel.timeRemaining.formattedTimeString)")
                : String(localized: "Section time remaining"))
            .accessibilityValue(sectionProgress.map {
                "\($0.remainingSec.formattedTimeString), \(String(localized: "Total time remaining")) \(timerViewModel.timeRemaining.formattedTimeString)"
            } ?? timerViewModel.timeRemaining.formattedTimeString)

            Spacer(minLength: 4)

            // 버튼 (아이콘만)
            HStack(spacing: DSSpacing.md) {
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
                .accessibilityLabel(String(localized: "Stop timer"))

                Button {
                    timerViewModel.togglePause()
                } label: {
                    Image(systemName: timerViewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .frame(height: 20)
                .accessibilityLabel(timerViewModel.isPaused ? String(localized: "Resume timer") : String(localized: "Pause timer"))
            }
            .padding(.bottom, DSSpacing.xs)
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .onAppear { timerViewModel.start() }
        .onDisappear { timerViewModel.stop() }
        .navigationBarBackButtonHidden(true)
    }

    /// 바깥 링(전체)과 안쪽 링(구간)이 같은 기하를 쓰도록 한 곳에 둔다.
    private static let ringSize: CGFloat = 120
    private static let ringWidth: CGFloat = 8
    /// 안쪽 구간 링의 두께·지름은 iPhone 과 **같은 규칙**을 쓴다(`SectionInnerRing`).
    private static let sectionRingWidth = SectionInnerRing.lineWidth(ringLineWidth: ringWidth)
    private static let sectionRingSize = SectionInnerRing.diameter(ringSize: ringSize, lineWidth: ringWidth)

    /// 지금 지나는 중인 구간 — 알림으로 나뉜 구간이 둘 이상일 때만 뜻이 있다.
    /// 계산은 iPhone 과 **같은 함수**(`TimerSections`)를 쓴다. 따로 세면 두 기기가 다른 구간을 가리킨다.
    private var sectionProgress: TimerSections.Progress? {
        let total = timerViewModel.mainDuration
        guard total > 0 else { return nil }
        let offsets = timerViewModel.prealertOffsets.isEmpty
            ? (timerViewModel.notificationTime > 0 ? [timerViewModel.notificationTime] : [])
            : timerViewModel.prealertOffsets
        guard let progress = TimerSections.progress(mainSeconds: total,
                                                    alertOffsets: Set(offsets),
                                                    elapsedSec: total - timerViewModel.timeRemaining),
              progress.isDivided else { return nil }
        return progress
    }

    private var progress: Double {
        guard timerViewModel.mainDuration > 0 else { return 0 }
        let raw = Double(timerViewModel.timeRemaining) / Double(timerViewModel.mainDuration)
        return max(0, min(1, raw))
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
