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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    // MARK: - Urgency (색 + 형태 단서를 함께 제공해 색약 사용자도 구분 가능)

    private enum Urgency: Equatable {
        case normal, warning, critical
    }

    private var urgency: Urgency {
        guard totalSeconds > 0 else { return .normal }
        if remaining <= 0 { return .critical }
        let ratio = remaining / TimeInterval(totalSeconds)
        if ratio <= 0.10 { return .critical }
        if ratio <= 0.25 { return .warning }
        return .normal
    }

    private var urgencyColor: Color {
        switch urgency {
        case .normal: return DSColor.stateRunning
        case .warning: return DSColor.statePaused
        case .critical: return DSColor.stateOvertime
        }
    }

    /// 긴급도 단계의 형태 단서 (normal 은 표시 안 함)
    private var urgencySymbol: String? {
        switch urgency {
        case .normal: return nil
        case .warning: return "exclamationmark.circle.fill"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }

    private var urgencyAccessibilityPhrase: String {
        switch urgency {
        case .normal: return ""
        case .warning: return String(localized: "Time is running low")
        case .critical: return String(localized: "Time is almost up")
        }
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
                .dsAnimation(.easeInOut(duration: 1.0), value: urgency)

            VStack(spacing: 0) {
                Spacer()

                // 섹션 정보
                sectionHeader
                    .padding(.bottom, DSSpacing.md)

                // 대형 카운트다운
                countdownDisplay
                    .padding(.bottom, DSSpacing.lg)

                // 섹션 프로그레스 바
                sectionProgressBar
                    .padding(.horizontal, 40)
                    .padding(.bottom, DSSpacing.xl)

                // 총 남은 시간
                totalRemainingDisplay
                    .padding(.bottom, DSSpacing.sm)

                // 다음 섹션 미리보기
                nextSectionPreview
                    .padding(.bottom, DSSpacing.xl)

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
        .onChange(of: urgency) { _, newValue in
            // 긴급도 전환을 VoiceOver 로 즉시 안내
            guard newValue != .normal else { return }
            let phrase = newValue == .critical
                ? String(localized: "Time is almost up")
                : String(localized: "Time is running low")
            AccessibilityNotification.Announcement(phrase).post()
        }
        .onTapGesture {
            revealControls()
        }
        .statusBarHidden(true)
    }

    // MARK: - Background

    private var urgencyBackground: some View {
        LinearGradient(
            colors: [urgencyColor.opacity(DSOpacity.faint + 0.05), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        let info = currentSectionInfo
        let sections = screenVM.presentationSections
        return VStack(spacing: DSSpacing.xs) {
            if !sections.isEmpty {
                Text("Section \(info.index + 1)/\(sections.count)")
                    .font(DSFont.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(info.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sections.isEmpty
            ? ""
            : String(localized: "Section \(info.index + 1) of \(sections.count), \(info.name)"))
    }

    // MARK: - Countdown

    private var countdownDisplay: some View {
        let info = currentSectionInfo
        let displayTime = max(0, info.sectionRemaining)
        let minutes = Int(displayTime) / 60
        let seconds = Int(displayTime) % 60

        return HStack(spacing: DSSpacing.sm) {
            if let symbol = urgencySymbol {
                Image(systemName: symbol)
                    .dsScaledFont(40, weight: .bold, relativeTo: .largeTitle, maxSize: 56)
                    .foregroundStyle(urgencyColor)
                    .accessibilityHidden(true)
            }
            Text(String(format: "%d:%02d", minutes, seconds))
                .dsScaledFont(120, weight: .bold, design: .rounded, relativeTo: .largeTitle, maxSize: 150)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(urgencyColor)
                .contentTransition(.numericText())
                .dsAnimation(.linear(duration: 0.3), value: Int(displayTime))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Section time remaining"))
        .accessibilityValue(countdownAccessibilityValue(minutes: minutes, seconds: seconds))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func countdownAccessibilityValue(minutes: Int, seconds: Int) -> String {
        let base = String(localized: "\(minutes) minutes \(seconds) seconds")
        let phrase = urgencyAccessibilityPhrase
        return phrase.isEmpty ? base : "\(base), \(phrase)"
    }

    // MARK: - Progress Bar

    private var sectionProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DSSpacing.xs)
                    .fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: DSSpacing.xs)
                    .fill(urgencyColor)
                    .frame(width: geo.size.width * sectionProgress)
                    .dsAnimation(.linear(duration: 0.5), value: sectionProgress)
            }
        }
        .frame(height: DSSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Section progress"))
        .accessibilityValue(String(localized: "\(Int(sectionProgress * 100)) percent"))
    }

    // MARK: - Total Remaining

    private var totalRemainingDisplay: some View {
        let total = max(0, remaining)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60

        return HStack(spacing: DSSpacing.xs) {
            Image(systemName: "clock")
                .font(DSFont.caption)
            Text("Total: \(String(format: "%d:%02d", minutes, seconds))")
                .font(DSFont.callout.monospacedDigit())
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Total time remaining"))
        .accessibilityValue(String(localized: "\(minutes) minutes \(seconds) seconds"))
    }

    // MARK: - Next Section Preview

    @ViewBuilder
    private var nextSectionPreview: some View {
        let info = currentSectionInfo
        let sections = screenVM.presentationSections
        let nextIndex = info.index + 1

        if nextIndex < sections.count {
            let next = sections[nextIndex]
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "arrow.right.circle")
                    .font(DSFont.caption)
                Text("Next: \(next.name) (\(next.formattedDuration))")
                    .font(DSFont.caption.weight(.medium))
            }
            .foregroundStyle(.secondary.opacity(0.8))
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DSSpacing.sm)
                    .fill(Color(.systemGray6))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Next section: \(next.name), \(next.formattedDuration)"))
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
            .buttonStyle(TimerButtonStyle(tint: DSColor.plain, size: 60))
            .accessibilityLabel(String(localized: "Stop presentation"))

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
                .buttonStyle(TimerButtonStyle(tint: DSColor.negativeSoft, size: 60))
                .accessibilityLabel(String(localized: "Pause"))
            case .paused:
                Button {
                    screenVM.resume()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .imageScale(.medium)
                }
                .buttonStyle(TimerButtonStyle(tint: DSColor.positive, size: 60))
                .accessibilityLabel(String(localized: "Resume"))
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Auto-hide Controls

    private func revealControls() {
        if reduceMotion {
            controlsVisible = true
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                controlsVisible = true
            }
        }
        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if screenVM.state == .running {
                if reduceMotion {
                    controlsVisible = false
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        controlsVisible = false
                    }
                }
            }
        }
    }
}
