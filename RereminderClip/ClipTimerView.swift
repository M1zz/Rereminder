//
//  ClipTimerView.swift
//  RereminderClip
//
//  클립 단일 화면: 다이얼로 시간 정하기 → 종 옮겨 알림 지점 정하기 → 시작.
//

import SwiftUI
import StoreKit

struct ClipTimerView: View {
    @EnvironmentObject private var viewModel: ClipTimerViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: DSSpacing.lg) {
                header

                Spacer(minLength: 0)

                clock(size: clockSize(in: geometry.size))

                alertChips

                Spacer(minLength: 0)

                if viewModel.isEditable {
                    durationPresets
                }

                controls

                fullAppLink
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.vertical, DSSpacing.xl)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshOnForeground() }
        }
        .appStoreOverlay(isPresented: $viewModel.showAppStoreOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Drag the bells to get reminders before your talk ends")
            .font(DSFont.sectionHeader)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Clock

    /// 드래그 툴팁이 원 밖으로 나가는 여백. 툴팁 중심이 반지름+32, 높이 절반이 약 16pt다.
    /// `ClipClock` 이 이미 노브 히트 영역만큼(선 두께 × 1.4 ≈ 34pt) 프레임을 키워두므로 나머지만 둔다.
    private static let tooltipMargin: CGFloat = 16

    private func clockSize(in available: CGSize) -> CGFloat {
        min(available.width * 0.80, available.height * 0.38)
    }

    private func clock(size: CGFloat) -> some View {
        ZStack {
            ClipClock(size: size)

            VStack(spacing: DSSpacing.xxs) {
                Text(timeText)
                    .font(DSFont.timer(.largeTitle))
                    .monospacedDigit()

                if viewModel.state == .overtime {
                    Text("Overtime")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.stateOvertime)
                }
            }
            .allowsHitTesting(false)
        }
        // 툴팁이 알림 칩·헤더를 덮지 않도록 원 둘레에 자리를 비워둔다.
        .padding(.vertical, Self.tooltipMargin)
    }

    private var timeText: String {
        let value = viewModel.isEditable
            ? viewModel.totalSeconds
            : Int(abs(viewModel.remaining).rounded())
        let sign = (!viewModel.isEditable && viewModel.remaining < 0) ? "+" : ""
        return sign + String(format: "%02d:%02d", value / 60, value % 60)
    }

    // MARK: - Alert Chips

    private var alertChips: some View {
        HStack(spacing: DSSpacing.sm) {
            ForEach(viewModel.alertOffsets, id: \.self) { offset in
                let fired = !viewModel.isEditable
                    && viewModel.remainingRatio <= CGFloat(offset) / CGFloat(max(1, viewModel.totalSeconds))
                Label {
                    Text("\(ClipAlertPlanner.label(forOffset: offset)) left")
                } icon: {
                    Image(systemName: fired ? "bell.slash.fill" : "bell.fill")
                }
                .font(DSFont.caption.weight(.semibold))
                .foregroundStyle(fired ? Color.white : DSColor.marker)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xs)
                .background(
                    Capsule().fill(fired ? DSColor.marker : DSColor.marker.opacity(DSOpacity.subtle))
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.alertOffsets)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Duration Presets

    private var durationPresets: some View {
        HStack(spacing: DSSpacing.sm) {
            ForEach(ClipTimerViewModel.durationPresets, id: \.self) { seconds in
                let selected = viewModel.totalSeconds == seconds
                Button {
                    viewModel.selectDuration(seconds)
                } label: {
                    Text(ClipAlertPlanner.label(forOffset: seconds))
                        .font(DSFont.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DSRadius.md)
                                .fill(selected
                                      ? Color.accentColor
                                      : Color.accentColor.opacity(DSOpacity.subtle))
                        )
                        .foregroundStyle(selected ? Color.white : Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: DSSpacing.sm) {
            Button(action: primaryAction) {
                Label(primaryTitle, systemImage: primaryIcon)
                    .font(DSFont.sectionHeader)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if !viewModel.isEditable {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    viewModel.reset()
                }
                .font(DSFont.callout)
                .tint(DSColor.negative)
            }

            if viewModel.notificationsDenied {
                Text("Turn on notifications to get alerts while the app is in the background.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.negativeSoft)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var primaryTitle: LocalizedStringKey {
        switch viewModel.state {
        case .idle, .finished: return "Start"
        case .running, .overtime: return "Pause"
        case .paused: return "Resume"
        }
    }

    private var primaryIcon: String {
        switch viewModel.state {
        case .idle, .finished, .paused: return "play.fill"
        case .running, .overtime: return "pause.fill"
        }
    }

    private func primaryAction() {
        switch viewModel.state {
        case .idle, .finished: viewModel.start()
        case .running, .overtime: viewModel.pause()
        case .paused: viewModel.resume()
        }
    }

    // MARK: - Full App Upsell

    private var fullAppLink: some View {
        Button {
            viewModel.showAppStoreOverlay = true
        } label: {
            Text("Presentation mode, templates, and history in the full app")
                .font(DSFont.caption)
                .multilineTextAlignment(.center)
                .underline()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
