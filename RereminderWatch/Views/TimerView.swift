//
//  TimerView.swift
//  Rereminder
//
//  워치 실행 화면 — **링이 화면 테두리를 따라가는 둥근 사각형**이다.
//
//  왜: 애플워치 화면이 둥근 사각형이라 원을 그리면 네 모서리가 통째로 남는다. 예전에는 지름
//  120pt 원을 고정으로 그렸는데, 40mm(162×197pt)에서는 그 낭비 때문에 **아래 동작 버튼 두 개가
//  화면 밖으로 잘려 있었고** 알림 라벨("10분")도 오른쪽 가장자리에 걸쳤다.
//  링을 테두리로 밀어내면 가운데가 통째로 남아 시간·버튼이 다 들어간다.
//
//  ⚠️ 링 경로와 알림 종 위치는 **`RoundedRectRing` 하나**에서 나온다(`trim` 과
//     `point(atFraction:)` 이 같은 좌표계). 따로 계산하면 줄어드는 호의 끝과 종이 어긋난다.
//

import SwiftUI

public struct TimerView: View {
    @StateObject private var timerViewModel: TimerViewModel
    @Binding var path: [NavigationTarget]

    /// 이 화면을 닫는 법 — 정지 버튼이 부른다.
    ///
    /// ⚠️ 닫는 방법이 두 가지라 부르는 쪽이 넘긴다. 설정에서 밀어 넣은 화면은 `path` 를 비우면
    ///    닫히지만, **cold launch 로 복원한 타이머는 `fullScreenCover` 로 뜨고 `path` 가
    ///    `.constant([])`** 라 아무리 비워도 닫히지 않는다(정지를 눌러도 화면에 갇혀 있었다).
    private let onExit: (() -> Void)?

    init(timerViewModel: TimerViewModel,
         path: Binding<[NavigationTarget]>,
         onExit: (() -> Void)? = nil) {
        self._timerViewModel = StateObject(wrappedValue: timerViewModel)
        self._path = path
        self.onExit = onExit
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                ringLayer(in: geo.size)
                markerLayer(in: geo.size)
                // ⚠️ **링은 가장자리까지, 글자는 안전 영역 안으로.** 둘 다 가장자리로 내보내면
                //    상태 줄이 시스템 시계와 겹쳐 읽을 수 없게 된다(실제로 그랬다).
                //    바깥에서 `ignoresSafeArea` 를 걸었으므로 여기서 그 몫을 되돌려 받는다.
                centerContent
                    .padding(.horizontal, Self.contentInset)
                    .padding(.top, max(geo.safeAreaInsets.top, Self.lineWidth + DSSpacing.sm))
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, Self.lineWidth + DSSpacing.sm))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // 링은 **화면 테두리**를 따라가야 값을 한다 — 안전 영역 안에만 그리면 위(시계 자리)에
        // 45pt 가 통째로 비어 원형 시절과 크게 다르지 않다. 애플의 기본 타이머도 가장자리까지 그린다.
        .ignoresSafeArea()
        .onAppear { timerViewModel.start() }
        .onDisappear { timerViewModel.stop() }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - 링

    /// 선 두께. 테두리를 따라가므로 원형 시절(8pt)보다 얇아도 충분히 읽힌다.
    private static let lineWidth: CGFloat = 6
    /// 모서리 반지름 — 짧은 변에 비례시켜 어떤 워치에서도 화면 곡률과 비슷하게 앉는다.
    private static let cornerRatio: CGFloat = 0.28
    /// 가운데 내용이 링에 닿지 않게 두는 좌우 여백.
    private static let contentInset: CGFloat = 22

    private func ringGeometry(in size: CGSize) -> (size: CGSize, radius: CGFloat) {
        // 선 두께의 절반만큼 안으로 들여야 획이 화면 밖으로 잘리지 않는다.
        let ringSize = CGSize(width: max(0, size.width - Self.lineWidth),
                              height: max(0, size.height - Self.lineWidth))
        let radius = RoundedRectRing.clampedRadius(min(ringSize.width, ringSize.height) * Self.cornerRatio,
                                                   in: ringSize)
        return (ringSize, radius)
    }

    private func ringLayer(in size: CGSize) -> some View {
        let geometry = ringGeometry(in: size)
        return ZStack {
            RoundedRectRing.Ring(cornerRadius: geometry.radius)
                .stroke(DSColor.plain.opacity(DSOpacity.track),
                        style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))

            // 남은 시간 — 알림 경계로 나뉜 **구간 색** 그대로 (iPhone 과 같은 규칙)
            ForEach(ringPieces) { piece in
                RoundedRectRing.Ring(cornerRadius: geometry.radius)
                    .trim(from: piece.start, to: piece.end)
                    .stroke(piece.color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .butt))
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .dsAnimation(.linear(duration: 1), value: progress)
    }

    /// 알림 종 — 테두리 위에는 라벨을 놓을 자리가 없으므로 **점만** 찍는다.
    /// 몇 분 남았는지는 가운데 큰 숫자가 말한다(그 숫자가 곧 다음 알림까지다).
    private func markerLayer(in size: CGSize) -> some View {
        let geometry = ringGeometry(in: size)
        return ZStack {
            ForEach(effectiveOffsets, id: \.self) { offset in
                if timerViewModel.mainDuration > offset {
                    let fraction = Double(offset) / Double(timerViewModel.mainDuration)
                    let point = RoundedRectRing.point(atFraction: fraction,
                                                      in: geometry.size,
                                                      cornerRadius: geometry.radius)
                    Circle()
                        .fill(DSColor.marker)
                        .frame(width: 7, height: 7)
                        .position(point)
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .accessibilityHidden(true)
    }

    private struct RingPiece: Identifiable {
        let id: Int
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    /// 남은 호를 알림 경계에서 잘라 구간 색을 입힌다.
    ///
    /// ⚠️ 구간 번호는 **`TimerSections.ringSectionIndex`** 로 센다. 링은 "남은 시간" 좌표라
    ///    경과 순서와 반대이고, 진행 중에는 지나간 경계가 호에서 빠져 조각 수가 줄어든다 —
    ///    자리 번호로 세면 그 순간 남은 구간의 색이 통째로 한 칸씩 밀린다.
    private var ringPieces: [RingPiece] {
        let total = timerViewModel.mainDuration
        guard total > 0 else { return [] }
        let end = progress
        guard end > 0 else { return [] }

        let markers = effectiveOffsets
            .map { Double($0) / Double(total) }
            .filter { $0 > 0 && $0 < 1 }
            .sorted()
        let cuts = [0] + markers.filter { $0 < end } + [end]

        return zip(cuts, cuts.dropFirst()).enumerated().compactMap { index, pair in
            guard pair.1 > pair.0 else { return nil }
            let sectionIndex = TimerSections.ringSectionIndex(segmentEnd: pair.1, markers: markers)
            return RingPiece(id: index,
                             start: CGFloat(pair.0),
                             end: CGFloat(pair.1),
                             color: SectionPalette.color(sectionIndex))
        }
    }

    // MARK: - 가운데

    /// ⚠️ 위아래로 **늘리지 않는다.** Spacer 로 채우면 상태 줄이 화면 맨 위로 올라붙어
    ///    시스템 시계와 겹친다(안전 영역 여백만으로는 부족했다). 가운데에 모아 두면 시계와
    ///    아래 링 사이의 빈 자리에 자연스럽게 앉는다.
    private var centerContent: some View {
        VStack(spacing: DSSpacing.sm) {
            statusRow
            timeStack
            buttonRow
        }
    }

    private var statusRow: some View {
        HStack(spacing: DSSpacing.xxs) {
            Image(systemName: statusSymbol)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(statusColor)
            Text(statusText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            if let label = sectionLabel {
                // 숫자 표기라 번역할 것이 없다 — 카탈로그에 끌려 들어가지 않게 verbatim.
                Text(verbatim: label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// 큰 숫자는 **이 구간**이 얼마 남았나(= 다음 알림까지), 작은 줄이 전체다.
    /// 구간이 하나뿐이면 큰 숫자가 곧 전체이므로 작은 줄을 세우지 않는다(같은 말을 두 번 하지 않는다).
    private var timeStack: some View {
        VStack(spacing: 1) {
            // ⚠️ 0 아래로 내려가면 `formattedTimeString` 이 "-1:-5" 같은 값을 낸다(분·초를 따로
            //    나눠서 둘 다 음수가 된다). 끝난 뒤에는 0:00 에 서고, 알림이 대신 되풀이한다.
            Text(max(0, sectionProgress?.remainingSec ?? timerViewModel.timeRemaining).formattedTimeString)
                .dsScaledFont(34, weight: .bold, design: .rounded, relativeTo: .title, maxSize: 44)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if sectionProgress != nil {
                Text("Total: \(max(0, timerViewModel.timeRemaining).formattedTimeString)")
                    .dsScaledFont(11, weight: .medium, design: .rounded, relativeTo: .caption2, maxSize: 15)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sectionProgress == nil
            ? String(localized: "Remaining time: \(timerViewModel.timeRemaining.formattedTimeString)")
            : String(localized: "Section time remaining"))
        .accessibilityValue(sectionProgress.map {
            "\($0.remainingSec.formattedTimeString), \(String(localized: "Total time remaining")) \(timerViewModel.timeRemaining.formattedTimeString)"
        } ?? timerViewModel.timeRemaining.formattedTimeString)
    }

    /// 링 안쪽에 들어가야 하므로 글자 없는 **작은 동그란 버튼**이다.
    @ViewBuilder
    private var buttonRow: some View {
        if isFinished {
            // 끝난 뒤에 일시정지는 뜻이 없다. 남은 할 일은 **되풀이 알림을 끄는 것** 하나뿐이라
            // 버튼도 하나다(누르면 다른 기기의 알림까지 함께 멈춘다 — `stop()` → 확인).
            Button { exitTimer() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
            }
            .buttonStyle(WatchRoundButtonStyle(tint: DSColor.positive))
            .accessibilityLabel(String(localized: "Stop"))
        } else {
            HStack(spacing: DSSpacing.lg) {
                Button { exitTimer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(WatchRoundButtonStyle(tint: DSColor.plain))
                .accessibilityLabel(String(localized: "Stop timer"))

                Button {
                    timerViewModel.togglePause()
                } label: {
                    Image(systemName: timerViewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(WatchRoundButtonStyle(tint: timerViewModel.isPaused
                                                   ? DSColor.positive
                                                   : DSColor.negativeSoft))
                .accessibilityLabel(timerViewModel.isPaused
                                    ? String(localized: "Resume timer")
                                    : String(localized: "Pause timer"))
            }
        }
    }

    private func exitTimer() {
        path = []
        onExit?()
        timerViewModel.stop()
    }

    // MARK: - 값

    /// 다중 알림이 기본이고, 단일 알림은 하위 호환 경로다.
    private var effectiveOffsets: [Int] {
        timerViewModel.prealertOffsets.isEmpty
            ? (timerViewModel.notificationTime > 0 ? [timerViewModel.notificationTime] : [])
            : timerViewModel.prealertOffsets
    }

    /// 지금 지나는 중인 구간 — 알림으로 나뉜 구간이 둘 이상일 때만 뜻이 있다.
    /// 계산은 iPhone 과 **같은 함수**(`TimerSections`)를 쓴다. 따로 세면 두 기기가 다른 구간을 가리킨다.
    private var sectionProgress: TimerSections.Progress? {
        let total = timerViewModel.mainDuration
        guard total > 0 else { return nil }
        guard let progress = TimerSections.progress(mainSeconds: total,
                                                    alertOffsets: Set(effectiveOffsets),
                                                    elapsedSec: total - timerViewModel.timeRemaining),
              progress.isDivided else { return nil }
        return progress
    }

    /// 시간이 다 됐나 — 여기서부터는 화면도 알림도 "확인해 주세요" 한 가지만 말한다.
    private var isFinished: Bool { timerViewModel.timeRemaining <= 0 }

    private var statusSymbol: String {
        if isFinished { return "bell.fill" }
        return timerViewModel.isPaused ? "pause.fill" : "play.fill"
    }

    private var statusColor: Color {
        if isFinished { return DSColor.marker }
        return timerViewModel.isPaused ? DSColor.statePaused : DSColor.stateRunning
    }

    private var statusText: String {
        if isFinished { return String(localized: "Time is up") }
        return timerViewModel.isPaused ? String(localized: "Pause") : String(localized: "In Progress")
    }

    /// "2/4" — 구간이 둘 이상일 때만.
    private var sectionLabel: String? {
        guard let progress = sectionProgress else { return nil }
        return "\(progress.index + 1)/\(progress.totalCount)"
    }

    private var progress: Double {
        guard timerViewModel.mainDuration > 0 else { return 0 }
        let raw = Double(timerViewModel.timeRemaining) / Double(timerViewModel.mainDuration)
        return max(0, min(1, raw))
    }
}

/// 링 안쪽에 들어가는 작은 동그란 버튼.
private struct WatchRoundButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Circle().fill(tint))
            .opacity(configuration.isPressed ? DSOpacity.pressed : 1)
    }
}
