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

    // 클립은 스크롤 없는 한 화면이다. 나머지 요소가 제 높이를 먼저 가져가고,
    // 남는 자리는 전부 원이 쓴다 — 원 크기가 이 화면의 최우선이다.
    var body: some View {
        VStack(spacing: DSSpacing.md) {
            header

            clockArea
                // 알림 배지가 원 밖으로 나가므로 이웃보다 위에 그린다
                .zIndex(1)

            alertChips

            if viewModel.isEditable {
                durationPresets
            }

            controls

            fullAppLink
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DSSpacing.xl)
        .padding(.vertical, DSSpacing.lg)
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

    /// 알림 배지가 원 위·아래로 삐져나오는 몫.
    /// 배지 중심이 반지름+52, 높이 절반이 34pt인데 `ClipClock` 프레임이 이미
    /// 노브 히트 영역(선 두께 × 1.4)만큼 커져 있어 그만큼은 빼고 잡은 값이다.
    private static let badgeMargin: CGFloat = 48

    /// 자리가 아무리 없어도 이보다 작아지면 다이얼을 손으로 조작할 수 없다
    private static let minClockSide: CGFloat = 150

    /// 종 노브(지름 1.6 × 선 두께)가 링 바깥으로 나가는 만큼을 뺀 비율.
    /// 이걸 안 빼면 3시·9시 방향 종이 화면 가장자리에서 잘린다.
    /// (링 반지름 + 노브 반지름 = 지름 × 0.5664 → 화면 폭의 88%가 한계)
    private static let widthRatio: CGFloat = 0.88

    /// 나머지 요소를 뺀 자리를 전부 원에 준다.
    /// 세로가 남아도는 화면에서는 가로가 한계라 원이 화면 폭을 거의 꽉 채운다.
    private func clockSide(in available: CGSize) -> CGFloat {
        max(
            Self.minClockSide,
            min(available.width * Self.widthRatio, available.height - Self.badgeMargin * 2)
        )
    }

    private var clockArea: some View {
        GeometryReader { proxy in
            clock(size: clockSide(in: proxy.size))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // 원만은 화면 좌우 여백까지 되찾아 쓴다 — 이 화면에서 가장 중요한 게 원이다
        .padding(.horizontal, -DSSpacing.xl)
    }

    private func clock(size: CGFloat) -> some View {
        ZStack {
            // 가운데 시간이 먼저다. 뒤에 오는 `ClipClock` 의 드래그 배지가 언제나 위에 그려져야
            // 하는데, 3시·9시 방향 종은 배지가 이 글자와 같은 높이에 온다.
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

            ClipClock(size: size)
        }
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
            Text("Session mode, templates, and history in the full app")
                .font(DSFont.caption)
                .multilineTextAlignment(.center)
                .underline()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
