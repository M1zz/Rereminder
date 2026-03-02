//
//  PresentationDisplayView.swift
//  Rereminder
//
//  Created by Claude on 2/28/26.
//

import SwiftUI

struct PresentationDisplayView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel

    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?

    private var remaining: TimeInterval { screenVM.remaining }
    private var totalSeconds: Int {
        screenVM.presentationSections.reduce(0) { $0 + $1.durationSeconds }
    }

    /// 현재 어떤 섹션에 있는지 계산
    private var currentSectionInfo: (index: Int, name: String, sectionRemaining: TimeInterval, sectionDuration: Int) {
        let sections = screenVM.presentationSections
        guard !sections.isEmpty else {
            return (0, "", remaining, 0)
        }

        var accumulated = 0
        for (i, section) in sections.enumerated() {
            accumulated += section.durationSeconds
            let sectionEndRemaining = TimeInterval(totalSeconds - accumulated)

            if remaining > sectionEndRemaining || i == sections.count - 1 {
                let sectionRemaining = remaining - sectionEndRemaining
                return (i, section.name, sectionRemaining, section.durationSeconds)
            }
        }
        return (sections.count - 1, sections.last?.name ?? "", remaining, sections.last?.durationSeconds ?? 0)
    }

    /// 긴급도 기반 색상
    private var urgencyColor: Color {
        guard totalSeconds > 0 else { return .green }
        let ratio = remaining / TimeInterval(totalSeconds)
        if remaining <= 0 { return .red }
        if ratio <= 0.10 { return .red }
        if ratio <= 0.25 { return .orange }
        return .green
    }

    /// 섹션 내 진행률
    private var sectionProgress: Double {
        let info = currentSectionInfo
        guard info.sectionDuration > 0 else { return 0 }
        return max(0, min(1, 1.0 - info.sectionRemaining / TimeInterval(info.sectionDuration)))
    }

    var body: some View {
        ZStack {
            // 배경 그라데이션
            urgencyBackground
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: urgencyColor)

            VStack(spacing: 0) {
                Spacer()

                // 섹션 정보
                sectionHeader
                    .padding(.bottom, 12)

                // 대형 카운트다운
                countdownDisplay
                    .padding(.bottom, 16)

                // 섹션 프로그레스 바
                sectionProgressBar
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)

                // 총 남은 시간
                totalRemainingDisplay
                    .padding(.bottom, 8)

                // 다음 섹션 미리보기
                nextSectionPreview
                    .padding(.bottom, 20)

                Spacer()

                // 컨트롤 (3초 후 자동 숨김)
                if controlsVisible {
                    controlButtons
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            scheduleHideControls()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            hideTask?.cancel()
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                controlsVisible = true
            }
            scheduleHideControls()
        }
        .statusBarHidden(true)
    }

    // MARK: - Background

    private var urgencyBackground: some View {
        LinearGradient(
            colors: [urgencyColor.opacity(0.15), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        let info = currentSectionInfo
        let sections = screenVM.presentationSections
        return VStack(spacing: 4) {
            if !sections.isEmpty {
                Text("Section \(info.index + 1)/\(sections.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(info.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    // MARK: - Countdown

    private var countdownDisplay: some View {
        let info = currentSectionInfo
        let displayTime = max(0, info.sectionRemaining)
        let minutes = Int(displayTime) / 60
        let seconds = Int(displayTime) % 60

        return Text(String(format: "%d:%02d", minutes, seconds))
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(urgencyColor)
            .contentTransition(.numericText())
            .animation(.linear(duration: 0.3), value: Int(displayTime))
    }

    // MARK: - Progress Bar

    private var sectionProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: 4)
                    .fill(urgencyColor)
                    .frame(width: geo.size.width * sectionProgress)
                    .animation(.linear(duration: 0.5), value: sectionProgress)
            }
        }
        .frame(height: 8)
    }

    // MARK: - Total Remaining

    private var totalRemainingDisplay: some View {
        let total = max(0, remaining)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60

        return HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
            Text("Total: \(String(format: "%d:%02d", minutes, seconds))")
                .font(.subheadline.monospacedDigit())
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Next Section Preview

    @ViewBuilder
    private var nextSectionPreview: some View {
        let info = currentSectionInfo
        let sections = screenVM.presentationSections
        let nextIndex = info.index + 1

        if nextIndex < sections.count {
            let next = sections[nextIndex]
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle")
                    .font(.caption)
                Text("Next: \(next.name) (\(next.formattedDuration))")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary.opacity(0.8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - Controls

    private var controlButtons: some View {
        HStack(spacing: 40) {
            // 중지
            Button {
                screenVM.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(tint: Color.plain, size: 60))

            // 일시정지/재개
            switch screenVM.state {
            case .running, .overtime:
                Button {
                    screenVM.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.bitNegative, size: 60))
            case .paused:
                Button {
                    screenVM.resume()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: Color.positive, size: 60))
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Auto-hide Controls

    private func scheduleHideControls() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if screenVM.state == .running {
                withAnimation(.easeInOut(duration: 0.3)) {
                    controlsVisible = false
                }
            }
        }
    }
}
