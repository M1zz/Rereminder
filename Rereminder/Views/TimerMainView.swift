//
//  TimerMainView.swift
//  Rereminder
//
//  Created by Oh Seojin on 9/24/25.
//

import SwiftUI

struct TimerMainView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    private var remaining: TimeInterval { screenVM.remaining }

    @State private var showTimeInput = false
    @State private var isDragging = false

    /// 구간 이름 입력 포커스 (키보드 내리기 제어용)
    @FocusState private var focusedSectionIndex: Int?
    @State private var dragTooltipAngle: Double = 0
    @State private var draggingMarkerOffset: Int? = nil
    @State private var markerDragAngle: Double = 0

    /// 자르지 않은 손가락 각도 — 종이 끝에 걸려도 손가락은 계속 따라가야 튀지 않는다
    @State private var markerFingerAngle: Double = 0
    /// 잡은 순간 종과 손가락이 어긋나 있던 만큼. 이걸 유지해야 집는 순간 종이 손끝으로 순간이동하지 않는다
    @State private var markerGrabDelta: Double = 0
    @State private var mainFingerAngle: Double = 0
    @State private var mainGrabDelta: Double = 0

    /// 다이얼 중심을 알아야 각도를 계산할 수 있어, 회전에 휘둘리지 않는 고정 좌표계를 따로 둔다
    private static let dialSpace = "rereminder.dial"
    private static let alertSpace = "rereminder.alerts"

    // 드래그를 놓은 뒤에도 툴팁을 잠시 유지
    @State private var showDragTooltip = false
    @State private var dragTooltipLingerTask: Task<Void, Never>?
    @State private var lingeringMarkerOffset: Int? = nil
    @State private var markerLingerTask: Task<Void, Never>?

    /// 손을 놓고 이만큼 지나면 배지·링 강조·흐려진 종이 한꺼번에 원래대로 돌아온다
    private static let tooltipLingerSeconds: Double = 3
    /// 사라질 땐 뚝 끊지 않고 녹여서 — 들어올 땐 빠르게, 나갈 땐 천천히
    private static let dissolveDuration: Double = 0.35

    /// 실행/일시정지/오버타임: 설정 시간을 100%로 보는 비율 모드
    private var isProgressMode: Bool {
        screenVM.state == .running || screenVM.state == .paused || screenVM.state == .overtime
    }

    /// 발표 모드: 섹션이 시간을 결정하므로 다이얼 직접 편집 대신 구간 편집 모달 사용
    private var isPresentationMode: Bool {
        screenVM.currentMode == .presentation
    }

    private var ratio: CGFloat {
        if isProgressMode {
            // 설정 시간 = 100%에서 감소
            let total = TimeInterval(max(1, screenVM.configuredMainSeconds))
            return CGFloat(max(0, min(1, remaining / total)))
        }
        return CGFloat(max(0, min(1, remaining / TimeInterval(TimeMapper.maxSeconds))))
    }
    private var markers: [CGFloat] {
        let offsets = screenVM.sortedOffsetsDesc.reversed()
        if isProgressMode {
            // 비율 좌표: 10분 타이머의 1분 전 알림 = 링의 10% 지점
            let total = CGFloat(max(1, screenVM.configuredMainSeconds))
            return offsets.map { CGFloat($0) / total }
        }
        return offsets.map { offset in
            CGFloat(offset) / TimeMapper.secondsPerDegree / 360.0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            // 발표 모드: 하단 구간 리스트 공간 확보를 위해 원을 축소
            let clockSize = min(availableWidth * 0.85, availableHeight * 0.55)
                * (isPresentationMode ? 0.72 : 1.0)
            let lineWidth = clockSize * 0.083
            let spacing = availableHeight * 0.01
            let buttonSize = clockSize * 0.18

            VStack(spacing: 0) {
                // 빠른Settings 영역 — 알림 프리셋(종) 칩은 타이머 모드 전용.
                // 발표 모드에서는 구간(=알림 지점)을 아래 구간 리스트에서 관리하므로 숨긴다.
                Group {
                    if !isPresentationMode && screenVM.state != .running {
                        AlertPresetButtons(screenVM: screenVM)
                            .padding(.top, spacing * 2)
                    } else {
                        // 발표 모드 / 실행 중일 때 빈 공간으로 높이 유지
                        Color.clear
                            .frame(height: availableHeight * 0.08)
                    }
                }

                Spacer()

                // 드래그 배지가 원 밖으로 나가므로 아래쪽 템플릿 바·구간 리스트보다 위에 그린다
                clockView(size: clockSize, lineWidth: lineWidth, geometry: geometry, buttonSize: buttonSize)
                    .zIndex(1)

                Spacer()

                if isPresentationMode {
                    // 알림 지점 기준 파생 구간 리스트 (원 밖 아래쪽)
                    // 이름을 편집하는 동안에는 키보드가 화면을 절반 가까이 먹으므로 리스트 몫을 늘린다
                    // (원은 그만큼 작아지지만, 그때 중요한 건 지금 고치는 구간이 보이는 것이다)
                    derivedSectionList(maxHeight: availableHeight * (focusedSectionIndex == nil ? 0.4 : 0.55))
                        .padding(.bottom, spacing * 2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !screenVM.nextAlertText.isEmpty {
                    // Next 알림 Info (원 밖 아래쪽)
                    nextAlertInfo
                        .padding(.vertical, spacing * 3)
                } else if screenVM.state == .idle || screenVM.state == .finished {
                    // 대기 상태: 최근 템플릿 칩 + 수정 시 저장 버튼 (원 밖 아래쪽)
                    TemplateQuickBar(screenVM: screenVM)
                        .padding(.horizontal)
                        .padding(.bottom, spacing * 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // ⚠️ 이게 없으면 Spacer·여백처럼 아무것도 그리지 않은 자리는 탭이 잡히지 않아
            //    "화면 아무 데나 눌러 키보드 내리기"가 원·카드 위에서만 동작한다.
            .contentShape(Rectangle())
        }
        // 빈 곳을 탭하면 키보드 내림 (버튼·제스처는 그대로 동작)
        .simultaneousGesture(TapGesture().onEnded {
            focusedSectionIndex = nil
        })
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedSectionIndex = nil
                }
            }
        }
        .sheet(isPresented: $showTimeInput) {
            TimeInputSheet(screenVM: screenVM, isPresented: $showTimeInput)
                .presentationDetents([.height(300)])
        }
        .fullScreenCover(isPresented: $screenVM.showTimerAlert) {
            TimerAlertView {
                screenVM.showTimerAlert = false
            }
        }
        .alert("Notification permission is required", isPresented: $screenVM.showPermissionWarning) {
            Button("Go to Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Later", role: .cancel) {
                // 권한 없이 Start Timer
                screenVM.showToast?("⚠️ Started without notification permission")
                withAnimation(.easeInOut(duration: 0.4)) {
                    screenVM.timerVM.start()
                }
            }
        } message: {
            Text("Notification permission is required for timer alerts.\n\nWithout permission:\n• You won't receive pre-alerts\n• You won't receive end alerts\n• Notifications won't work in background\n\nPlease enable notifications in Settings.")
        }
    }

    private func clockView(size: CGFloat, lineWidth: CGFloat, geometry: GeometryProxy, buttonSize: CGFloat) -> some View {
        ZStack {
            backgroundCircle(size: size, lineWidth: lineWidth)
            progressCircle(size: size, lineWidth: lineWidth)

            // 얇은 바깥 구간 링은 **진행 중에만**.
            // 대기 중에는 본 링이 이미 알림 경계로 구간 색이라(alertSectionRing) 같은 정보가
            // 두 겹으로 겹쳐 보인다. 진행 중에는 본 링이 남은 시간만 그리므로 이 링이 필요하다.
            if isPresentationMode && isProgressMode {
                sectionOuterRing(size: size, lineWidth: lineWidth)
                    .transition(.opacity)
            }

            // 실행/일시정지 중: 줄어드는 호의 끝점을 동그라미로 표시
            if screenVM.state == .running || screenVM.state == .paused {
                progressEdgeDot(size: size, lineWidth: lineWidth)
            }

            // 종을 잡고 있는 동안 링을 "시작 후 / 종료 전" 두 색으로 가른다
            if isTimeEditable, let marker = highlightedMarker {
                alertSplitArc(size: size, lineWidth: lineWidth, angle: marker.angle)
                    .transition(.opacity)
            }

            clockMarkers(size: size, lineWidth: lineWidth)

            // 시간 조절 드래그는 대기/Done 상태에서만 (실행·일시정지·오버타임 중에는 불가)
            if isTimeEditable {
                dragPointer(size: size, lineWidth: lineWidth)
            }

            // 알림 노브: 대기 중엔 드래그 핸들, 실행/일시정지 중엔 알림 시점 표시
            alertKnobs(size: size, lineWidth: lineWidth)

            // 드래그 중 뜨는 배지는 언제나 최상단이다.
            // 3시·9시 방향 종은 배지가 가운데 시간 글자와 같은 높이에 오는데,
            // 시간+버튼 묶음이 이 ZStack 의 마지막 자식이라 zIndex 없이는 배지를 덮는다.
            if showDragTooltip && isTimeEditable {
                dragTooltip(size: size)
                    .zIndex(2)
            }

            if isTimeEditable, let marker = highlightedMarker {
                markerDragTooltip(size: size, marker: marker, availableWidth: geometry.size.width)
                    .transition(.opacity)
                    .zIndex(2)
            }

            let fontSize = isPresentationMode
                ? size * 0.17
                : min(geometry.size.width, geometry.size.height) * 0.16

            // 시간 + 버튼 묶음을 원의 세로 중앙에 배치 (모든 모드 공통)
            VStack(spacing: fontSize * 0.45) {
                if let segment = currentSegment {
                    // 발표 모드 실행 중: 현재 구간 이름 + 구간 색 점
                    HStack(spacing: DSSpacing.xs) {
                        Circle()
                            .fill(sectionColor(segment.index))
                            .frame(width: fontSize * 0.22, height: fontSize * 0.22)
                        Text(segment.name)
                            .font(.system(size: fontSize * 0.45, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .animation(.easeInOut(duration: 0.3), value: segment.index)
                } else if isProgressMode && !screenVM.timerVM.currentLabel.isEmpty {
                    // 타이머 라벨(예: "Mentoring")만 표시 — 상태 텍스트는 표시하지 않음
                    Text(screenVM.timerVM.currentLabel)
                        .font(.system(size: fontSize * 0.45, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                centerTimeDisplay(fontSize: fontSize)
                buttonRow(buttonSize: buttonSize)
            }
        }
        .onChange(of: screenVM.state) { _, newState in
            let announcement: String
            switch newState {
            case .running:
                announcement = String(localized: "Timer started")
            case .paused:
                announcement = String(localized: "Timer paused")
            case .overtime:
                announcement = String(localized: "Timer finished, overtime counting")
            case .finished:
                announcement = String(localized: "Timer stopped")
            case .idle:
                announcement = String(localized: "Timer ready")
            }
            AccessibilityNotification.Announcement(announcement).post()
        }
    }

    /// 지금 주목해야 할 알림 — 끌고 있는 종, 없으면 방금 놓은 종.
    /// 배지·링 강조·다른 종 흐리기가 모두 이 값 하나를 따라간다.
    private var highlightedMarker: (seconds: Int, angle: Double)? {
        if draggingMarkerOffset != nil {
            return (TimeMapper.angleToSeconds(from: markerDragAngle), markerDragAngle)
        }
        if let sec = lingeringMarkerOffset {
            return (sec, Double(sec) / TimeMapper.secondsPerDegree)
        }
        return nil
    }

    /// 종 위치를 경계로 링의 "종료 전" 쪽(0° ~ 종)만 주황으로 덮어 배지의 두 줄과 색을 맞춘다.
    /// 나머지(종 ~ 설정 시간)는 원래 강조색으로 남아 "시작 후" 구간이 된다.
    private func alertSplitArc(size: CGFloat, lineWidth: CGFloat, angle: Double) -> some View {
        let fraction = angle / 360.0
        let innerSize = innerRingSize(size, lineWidth: lineWidth)
        return ZStack {
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, max(0, fraction))))
                .stroke(
                    DSColor.marker,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size, height: size)

            // 60분을 넘겨 두 번째 바퀴에 걸친 알림 — 그 시간이 그려진 안쪽 줄에 얹는다
            if fraction > 1 {
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, fraction - 1)))
                    .stroke(
                        DSColor.marker,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: innerSize, height: innerSize)
            }
        }
        .rotationEffect(.degrees(-90))
        .accessibilityHidden(true)
    }

    /// 줄어드는 호의 움직이는 끝점 표시 — 대기 중 드래그 핸들과 같은 시각 언어(흰 원)
    private func progressEdgeDot(size: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth * 0.9, height: lineWidth * 0.9)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
            .offset(x: size / 2)
            .rotationEffect(.degrees(Double(ratio) * 360.0))
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }

    /// 링을 알림 경계로 나눠 구간 색으로 칠할 때인가.
    ///
    /// 종을 잡고 있는 동안에는 **끄고** 단색 + `alertSplitArc`(시작 후/종료 전 2색)로 돌아간다.
    /// 그때 화면의 주인공은 드래그 배지 두 줄이고, 배지 줄 색과 링 구간 색이 어긋나면
    /// 어느 숫자가 어디인지 읽히지 않기 때문이다(CLAUDE.md의 배지·링 색 규칙).
    private var showsAlertSectionColors: Bool {
        isTimeEditable
            && !isProgressMode
            && highlightedMarker == nil
            && !screenVM.selectedOffsets.isEmpty
    }

    /// 한 바퀴(60분)를 넘어간 시간은 **안쪽 줄**에 그린다.
    /// 다이얼 최대가 2바퀴(120분, `TimeMapper.maxAngle`)라 줄은 둘이면 충분하다.
    private func innerRingSize(_ size: CGFloat, lineWidth: CGFloat) -> CGFloat {
        size - lineWidth * 2.6
    }

    /// 이 각도가 놓일 줄의 지름 — 호·종 노브·드래그 핸들이 **모두 이 하나를 따라야**
    /// 60분을 넘겼을 때 종만 바깥에 남는 식으로 어긋나지 않는다.
    private func ringSize(forAngle angle: Double, size: CGFloat, lineWidth: CGFloat) -> CGFloat {
        angle >= 360 ? innerRingSize(size, lineWidth: lineWidth) : size
    }

    /// 전체 호를 알림 경계로 자른 지점들 (1.0 = 한 바퀴, 바퀴 구분 없는 절대 좌표)
    private func sectionBounds(arcEnd: CGFloat) -> [CGFloat] {
        [0] + markers.filter { $0 > 0 && $0 < arcEnd }.sorted() + [arcEnd]
    }

    /// 알림 지점을 경계로 링 자체를 구간 색으로 나눈다.
    /// (발표 모드의 바깥 얇은 링 `sectionOuterRing` 과 같은 색 규칙 — 같은 구간은 어디서나 같은 색)
    ///
    /// - Parameters:
    ///   - arcEnd: 설정 시간까지의 전체 길이(바퀴 수 포함, 예: 90분 = 1.5)
    ///   - lap: 이 줄이 맡는 바퀴 (0 = 바깥, 1 = 안쪽)
    /// 구간이 바퀴 경계를 걸치면 잘라서 양쪽 줄에 나눠 그린다.
    private func alertSectionRing(size: CGFloat, lineWidth: CGFloat, arcEnd: CGFloat, lap: Int = 0) -> some View {
        let bounds = sectionBounds(arcEnd: arcEnd)
        let lapStart = CGFloat(lap)

        return ZStack {
            ForEach(0..<max(0, bounds.count - 1), id: \.self) { i in
                // 링은 "종료까지 남은 시간" 좌표라 경과 순서와 반대 → 구간 인덱스로 역매핑
                let sectionIndex = bounds.count - 2 - i
                let isEditingThis = focusedSectionIndex == sectionIndex
                let from = max(bounds[i], lapStart) - lapStart
                let to = min(bounds[i + 1], lapStart + 1) - lapStart
                if to > from {
                    // 이름을 편집 중인 구간은 링에서도 도드라진다 (리스트 카드의 테두리와 같은 문법)
                    if isEditingThis {
                        Circle()
                            .trim(from: from, to: to)
                            .stroke(Color.primary.opacity(0.85),
                                    style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .butt))
                            .frame(width: size, height: size)
                            .rotationEffect(.degrees(-90))
                    }

                    Circle()
                        .trim(from: from, to: to)
                        .stroke(
                            sectionColor(sectionIndex),
                            // 이어 붙는 경계라 round 캡을 쓰면 서로 겹쳐 부풀어 보인다
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                        )
                        // 다른 구간을 편집 중이면 이 호는 한 발 물러난다 (리스트 행과 같은 값)
                        .opacity(focusedSectionIndex == nil || isEditingThis ? 1.0 : 0.55)
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: screenVM.sortedOffsetsDesc)
        .animation(.easeInOut(duration: 0.2), value: focusedSectionIndex)
        .accessibilityHidden(true)
    }

    /// 구간별 고유 색 팔레트 (주황은 알림 마커 전용이라 제외)
    private static let sectionPalette: [Color] = [.blue, .green, .purple, .teal, .pink, .indigo]

    /// 구간 인덱스(경과 순서 기준) → 색
    private func sectionColor(_ index: Int) -> Color {
        Self.sectionPalette[index % Self.sectionPalette.count]
    }

    /// 알림 지점을 경계로 분할된 바깥 구간 링 (발표용 토글)
    /// 각 구간은 리스트와 같은 고유 색으로 표시된다
    private func sectionOuterRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        let ringWidth = lineWidth * 0.45
        let ringSize = size + lineWidth * 1.9
        let arcEnd: CGFloat = isProgressMode
            ? 1.0
            : CGFloat(min(1.0, max(0, screenVM.mainAngle) / 360.0))
        let bounds = [0] + markers.filter { $0 > 0 && $0 < arcEnd }.sorted() + [arcEnd]
        let gap: CGFloat = 0.004

        return ZStack {
            ForEach(0..<(bounds.count - 1), id: \.self) { i in
                // 링은 "남은 시간" 좌표라 경과 순서와 반대 → 리스트 인덱스로 역매핑
                let sectionIndex = bounds.count - 2 - i
                let isEditingThis = focusedSectionIndex == sectionIndex
                let trimFrom = bounds[i] + gap
                let trimTo = max(bounds[i] + gap, bounds[i + 1] - gap)

                // 편집 중인 호는 리스트 행과 같은 문법의 테두리를 두른다
                if isEditingThis {
                    Circle()
                        .trim(from: trimFrom, to: trimTo)
                        .stroke(
                            Color.primary.opacity(0.85),
                            style: StrokeStyle(lineWidth: ringWidth * 1.8 + 4, lineCap: .butt)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                }

                Circle()
                    .trim(from: trimFrom, to: trimTo)
                    .stroke(
                        sectionColor(sectionIndex).opacity(isEditingThis ? 1.0 : 0.85),
                        // 편집 중인 구간의 호는 굵어져서 위치가 바로 보임
                        style: StrokeStyle(lineWidth: ringWidth * (isEditingThis ? 1.8 : 1.0), lineCap: .butt)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: focusedSectionIndex)
        .accessibilityHidden(true)
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
            .accessibilityHidden(true)
    }

    private func progressCircle(size: CGFloat, lineWidth: CGFloat) -> some View {
        let primaryFraction: CGFloat
        let secondaryFraction: CGFloat  // 대기 중 60분 초과 설정 시 2바퀴째
        let circleColor: Color

        if screenVM.state == .running || screenVM.state == .paused {
            // 실행/Pause 중: 설정 시간 = 100% 링이 비율로 감소
            primaryFraction = ratio
            secondaryFraction = 0
            circleColor = Color.accentColor
        } else if screenVM.state == .overtime {
            // 오버타임: 빨간색 원형 (음수 시간은 각도로 변환하지 않고 0으로 표시)
            primaryFraction = 0
            secondaryFraction = 0
            circleColor = Color.red
        } else {
            // 대기/Done 상태: Settings된 시간을 절대 각도(1° = 10초)로 표시
            let angle = screenVM.mainAngle
            primaryFraction = CGFloat(min(1.0, max(0, angle) / 360.0))
            secondaryFraction = CGFloat(max(0, min(1.0, (angle - 360) / 360.0)))
            circleColor = Color.accentColor
        }

        // 설정 시간 전체 길이(바퀴 수 포함) — 구간 색 분할이 바퀴를 걸쳐도 이어지도록
        let totalFraction = isProgressMode
            ? primaryFraction
            : CGFloat(max(0, screenVM.mainAngle) / 360.0)
        let innerSize = innerRingSize(size, lineWidth: lineWidth)

        return ZStack {
            // 바깥 줄 = 첫 바퀴
            if showsAlertSectionColors {
                alertSectionRing(size: size, lineWidth: lineWidth, arcEnd: totalFraction, lap: 0)
            } else {
                Circle()
                    .trim(from: 0, to: primaryFraction)
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
            }

            // 안쪽 줄 = 60분을 넘어간 시간.
            // 예전에는 같은 원 위에 연두색으로 겹쳐 그려서 두 바퀴가 서로를 덮었다.
            if secondaryFraction > 0 {
                // 얼마나 더 갈 수 있는지 보이도록 안쪽에도 옅은 바탕 링
                Circle()
                    .stroke(.plain.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: innerSize, height: innerSize)

                if showsAlertSectionColors {
                    alertSectionRing(size: innerSize, lineWidth: lineWidth, arcEnd: totalFraction, lap: 1)
                } else {
                    Circle()
                        .trim(from: 0, to: secondaryFraction)
                        .stroke(
                            circleColor,
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: innerSize, height: innerSize)
                        .rotationEffect(.init(degrees: -90))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func clockMarkers(size: CGFloat, lineWidth: CGFloat) -> some View {
        let sortedOffsets = Array(screenVM.selectedOffsets.sorted())
        let draggingIdx: Int? = if let offset = draggingMarkerOffset {
            sortedOffsets.firstIndex(of: offset)
        } else {
            nil
        }
        let dragRatio: CGFloat? = if draggingMarkerOffset != nil {
            CGFloat(markerDragAngle * TimeMapper.secondsPerDegree)
                / (TimeMapper.secondsPerDegree * 360.0)
        } else {
            nil
        }
        // 작대기 마커도 종 노브와 함께 물러난다 — 하나만 흐려지면 따로 노는 것처럼 보인다
        let dimmed: Set<Int>
        if highlightedMarker != nil,
           let focused = draggingMarkerOffset ?? lingeringMarkerOffset,
           let focusedIndex = sortedOffsets.firstIndex(of: focused) {
            dimmed = Set(sortedOffsets.indices).subtracting([focusedIndex])
        } else {
            dimmed = []
        }

        return ClockMarkers(
            remaining: ratio,
            markers: markers,
            markerOffsets: sortedOffsets,
            draggingIndex: draggingIdx,
            draggingRatio: dragRatio,
            dotSize: lineWidth,
            inset: 0,
            upcoming: true,
            // 상시 라벨은 제거 — 드래그 중/직후 툴팁이 대신함
            showLabels: false,
            dimmedIndices: dimmed
        )
        .frame(width: size, height: size)
        .animation(highlightAnimation, value: dimmed)
        .accessibilityHidden(true)
    }

    /// 물러날 땐 빠르게, 돌아올 땐 배지가 녹는 속도에 맞춰 천천히
    private var highlightAnimation: Animation {
        highlightedMarker != nil
            ? .easeInOut(duration: 0.2)
            : .easeOut(duration: Self.dissolveDuration)
    }

    private func dragPointer(size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: lineWidth, height: lineWidth)
                // 설정 시간이 60분을 넘으면 호가 안쪽 줄로 넘어가므로 핸들도 같이 간다
                .offset(x: ringSize(forAngle: screenVM.mainAngle, size: size, lineWidth: lineWidth) / 2)
                .rotationEffect(.degrees(screenVM.mainAngle))
                .gesture(dragGesture(size: size))
                .rotationEffect(.init(degrees: -90))
        }
        .frame(width: size, height: size)
        .coordinateSpace(name: Self.dialSpace)
        .accessibilityHidden(true)
    }

    private func dragGesture(size: CGFloat) -> some Gesture {
        let center = CGPoint(x: size / 2, y: size / 2)

        // 좌표계만 고정 좌표계로 바꾼다 — 인식 거리는 그대로 둬야 좌우 스와이프 페이지 넘김을 안 뺏는다
        return DragGesture(coordinateSpace: .named(Self.dialSpace))
            .onChanged { value in
                showDragTooltip = true
                dragTooltipLingerTask?.cancel()

                if !isDragging {
                    isDragging = true
                    // 손가락은 핸들 한가운데를 짚지 않는다. 그 차이를 기억해 두면 집는 순간 안 튄다
                    let grabbed = TimeMapper.ringAngle(at: value.startLocation, center: center)
                    mainFingerAngle = grabbed
                    mainGrabDelta = screenVM.mainAngle - grabbed
                }

                let finger = TimeMapper.ringAngle(at: value.location, center: center)
                mainFingerAngle = TimeMapper.unwrappedAngle(finger, continuing: mainFingerAngle)
                let angle = mainFingerAngle + mainGrabDelta
                // 자르는 건 여기서만 — 잘린 값은 다음 계산에 되먹이지 않는다
                screenVM.mainAngle = max(0, min(angle, TimeMapper.maxAngle))

                dragTooltipAngle = screenVM.mainAngle - 90
            }
            .onEnded { _ in
                isDragging = false
                let snapped = snappedAngle(from: screenVM.mainAngle)
                screenVM.mainAngle = snapped
                dragTooltipAngle = snapped - 90
                // 손을 놓은 뒤에도 잠시 유지
                dragTooltipLingerTask = Task {
                    try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: Self.dissolveDuration)) {
                        showDragTooltip = false
                    }
                }
            }
    }

    private func dragTooltip(size: CGFloat) -> some View {
        let timeText = mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes)
        let xOffset = cos(dragTooltipAngle * .pi / 180) * (size / 2 + 32)
        let yOffset = sin(dragTooltipAngle * .pi / 180) * (size / 2 + 32)

        return Text(timeText)
            .font(.body.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(10)
            .offset(x: xOffset, y: yOffset)
            .accessibilityHidden(true)
    }

    /// 알림 노브 — 상태에 따라 역할이 달라진다:
    /// - 대기/Done: 크게 표시 + 드래그로 알림 시점 조절
    /// - 실행/일시정지/오버타임: 작게 표시만 (비율 위치), 이미 울린 알림은 흐리게
    private func alertKnobs(size: CGFloat, lineWidth: CGFloat) -> some View {
        let sortedOffsets = Array(screenVM.selectedOffsets.sorted())
        let total = CGFloat(max(1, screenVM.configuredMainSeconds))
        let isHighlighting = highlightedMarker != nil
        return ZStack {
            ForEach(sortedOffsets, id: \.self) { offsetSec in
                let baseAngle: Double = isProgressMode
                    ? Double(CGFloat(offsetSec) / total) * 360.0
                    : Double(offsetSec) / TimeMapper.secondsPerDegree
                let displayAngle = draggingMarkerOffset == offsetSec ? markerDragAngle : baseAngle
                let isDraggingThis = draggingMarkerOffset == offsetSec
                // 방금 놓은 종도 배지가 남아 있는 동안은 계속 주인공이다
                let isFocused = isDraggingThis
                    || (draggingMarkerOffset == nil && lingeringMarkerOffset == offsetSec)
                // 하나를 옮기는 동안 나머지는 물러나 있어야 어느 종을 만지는지 헷갈리지 않는다
                let dimmed = isHighlighting && !isFocused
                let fired = isProgressMode && ratio <= CGFloat(offsetSec) / total
                let knobScale: CGFloat = isTimeEditable ? (isDraggingThis ? 2.0 : 1.6) : 1.15

                ZStack {
                    Circle()
                        .fill(DSColor.marker)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                    Image(systemName: fired ? "bell.slash.fill" : "bell.fill")
                        .font(.system(size: lineWidth * 0.7 * (isTimeEditable ? 1.0 : 0.8), weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: lineWidth * knobScale, height: lineWidth * knobScale)
                .opacity(fired ? 0.35 : (dimmed ? 0.25 : 1.0))
                // 링을 따라 돌아도 종 아이콘은 똑바로 서 있도록 역회전
                .rotationEffect(.degrees(90 - displayAngle))
                .frame(width: lineWidth * 2.8, height: lineWidth * 2.8)
                .contentShape(Circle())
                // 60분을 넘어간 종은 그 시간이 그려진 안쪽 줄에 붙는다
                .offset(x: ringSize(forAngle: displayAngle, size: size, lineWidth: lineWidth) / 2)
                .rotationEffect(.degrees(displayAngle))
                    .gesture(
                        DragGesture(coordinateSpace: .named(Self.alertSpace))
                            .onChanged { value in
                                let center = CGPoint(x: size / 2, y: size / 2)

                                if draggingMarkerOffset != offsetSec {
                                    draggingMarkerOffset = offsetSec
                                    // 손가락은 종 한가운데를 짚지 않는다. 그 차이를 기억해 두면 집는 순간 안 튄다
                                    let grabbed = TimeMapper.ringAngle(
                                        at: value.startLocation,
                                        center: center
                                    )
                                    markerFingerAngle = grabbed
                                    markerGrabDelta =
                                        Double(offsetSec) / TimeMapper.secondsPerDegree - grabbed
                                }
                                markerLingerTask?.cancel()
                                lingeringMarkerOffset = nil

                                let finger = TimeMapper.ringAngle(at: value.location, center: center)
                                markerFingerAngle = TimeMapper.unwrappedAngle(
                                    finger,
                                    continuing: markerFingerAngle
                                )

                                let mainSec = screenVM.mainMinutes * 60 + screenVM.mainSeconds
                                let maxAngle = Double(mainSec - 10) / TimeMapper.secondsPerDegree
                                // 자르는 건 여기서만 — 잘린 값은 다음 계산에 되먹이지 않는다
                                markerDragAngle = max(
                                    0,
                                    min(markerFingerAngle + markerGrabDelta, max(0, maxAngle))
                                )
                            }
                            .onEnded { _ in
                                guard let dragOffset = draggingMarkerOffset else { return }
                                let newSec = TimeMapper.angleToSeconds(from: markerDragAngle)
                                let mainSec = screenVM.mainMinutes * 60 + screenVM.mainSeconds
                                screenVM.selectedOffsets.remove(dragOffset)
                                if newSec > 0 && newSec < mainSec {
                                    screenVM.selectedOffsets.insert(newSec)
                                    // 놓은 자리의 라벨을 잠시 유지
                                    lingeringMarkerOffset = newSec
                                    markerLingerTask = Task {
                                        try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                                        guard !Task.isCancelled else { return }
                                        withAnimation(.easeOut(duration: Self.dissolveDuration)) {
                                            lingeringMarkerOffset = nil
                                        }
                                    }
                                }
                                draggingMarkerOffset = nil
                            },
                        including: isTimeEditable ? .all : .none
                    )
                    .rotationEffect(.init(degrees: -90))
                    // 알림 토글 시 노브가 축소+페이드로 나타나고 사라지도록
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .coordinateSpace(name: Self.alertSpace)
        .animation(.easeInOut(duration: 0.25), value: screenVM.sortedOffsetsDesc)
        // 흐려지고 돌아오는 것만 부드럽게 — 각도는 손가락을 그대로 따라가야 한다
        .animation(highlightAnimation, value: draggingMarkerOffset)
        .animation(highlightAnimation, value: lingeringMarkerOffset)
        .allowsHitTesting(isTimeEditable)
        .accessibilityHidden(true)
    }

    /// 배지 반너비 어림값 — 화면 밖으로 나가지 않게 x 오프셋을 자를 때 쓴다.
    /// 글꼴이나 여백을 키우면 이 값도 같이 올려야 한다
    private static let markerBadgeHalfWidth: CGFloat = 58

    /// 알림 배지 — 한 지점을 두 가지로 읽어준다.
    /// 위: 종료까지 얼마나 남았는지, 아래: 시작 후 얼마나 지났는지.
    /// (5분 발표에서 종료 1분 전에 종을 두면 1:00 / 4:00)
    /// 각 줄의 색은 링에서 강조되는 구간 색과 같아 어느 숫자가 어디인지 바로 보인다.
    private func markerDragTooltip(
        size: CGFloat,
        marker: (seconds: Int, angle: Double),
        availableWidth: CGFloat
    ) -> some View {
        let total = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        let beforeEnd = max(0, marker.seconds)
        let afterStart = max(0, total - beforeEnd)

        let tooltipAngle = marker.angle - 90
        // 두 줄 배지는 높이 절반이 34pt 쯤 되므로, 12시·6시에서 링을 덮지 않을 만큼 띄운다
        let distance = size / 2 + 52
        let rawX = cos(tooltipAngle * .pi / 180) * distance
        // 3시·9시 방향에서 배지가 화면 밖으로 밀려나지 않도록 가둔다
        let limit = max(0, availableWidth / 2 - Self.markerBadgeHalfWidth - 4)
        let xOffset = min(max(rawX, -limit), limit)
        let yOffset = sin(tooltipAngle * .pi / 180) * distance

        return VStack(spacing: 0) {
            markerBadgeRow(
                icon: "flag.checkered",
                text: mmss(from: beforeEnd),
                background: DSColor.marker
            )
            markerBadgeRow(
                icon: "play.fill",
                text: mmss(from: afterStart),
                background: Color.accentColor
            )
        }
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        .offset(x: xOffset, y: yOffset)
        .accessibilityHidden(true)
    }

    private func markerBadgeRow(icon: String, text: String, background: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
            Text(text)
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        // 배지가 원 위로 겹치므로 대비를 확실히 준다
        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 0)
    }

    private func centerTimeDisplay(fontSize: CGFloat) -> some View {
        Text((screenVM.state == .running || screenVM.state == .overtime) ? screenVM.timeString(from: screenVM.timerVM.remaining) : mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes))
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .onTapGesture {
                if isTimeEditable {
                    showTimeInput = true
                }
            }
            // VoiceOver: 다이얼 전체를 "상태 + 시간" 한 덩어리로 안내하고,
            // 드래그 대신 위/아래 스와이프로 시간을 조정할 수 있게 한다.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stateLabel)
            .accessibilityValue(accessibilityTimeValue)
            .accessibilityHint(isTimeEditable
                ? String(localized: "Swipe up or down to adjust the time. Double tap to enter an exact time.")
                : "")
            .accessibilityAddTraits(isTimeEditable ? [.isButton, .updatesFrequently] : .updatesFrequently)
            .accessibilityAdjustableAction { direction in
                guard isTimeEditable else { return }
                switch direction {
                case .increment:
                    adjustTime(by: 60)
                case .decrement:
                    adjustTime(by: -60)
                @unknown default:
                    break
                }
            }
    }

    /// 실행/일시정지/오버타임이 아닐 때만 시간 편집 가능
    /// (발표 모드에서도 다이얼·알림 편집 가능 — 알림이 구간 경계를 정의한다)
    private var isTimeEditable: Bool {
        screenVM.state != .running && screenVM.state != .overtime && screenVM.state != .paused
    }

    /// VoiceOver가 읽어줄 시간 값 (편집 중이면 설정값, 진행 중이면 남은 시간)
    private var accessibilityTimeValue: String {
        if screenVM.state == .running || screenVM.state == .overtime {
            return spokenTime(totalSeconds: max(0, Int(screenVM.timerVM.remaining)))
        }
        return spokenTime(totalSeconds: screenVM.mainMinutes * 60 + screenVM.mainSeconds)
    }

    /// 초를 "N분 M초" 형태의 음성 친화 문자열로 변환
    private func spokenTime(totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 && seconds > 0 {
            return String(localized: "\(minutes) min \(seconds) sec")
        } else if minutes > 0 {
            return String(localized: "\(minutes) min")
        } else {
            return String(localized: "\(seconds) sec")
        }
    }

    /// VoiceOver 위/아래 스와이프 시 시간을 1분 단위로 증감 (0 ~ 최대 120분)
    private func adjustTime(by deltaSeconds: Int) {
        let total = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        let newTotal = max(0, min(TimeMapper.maxSeconds, total + deltaSeconds))
        screenVM.mainMinutes = newTotal / 60
        screenVM.mainSeconds = newTotal % 60
    }

    // MARK: - Derived Section List (발표 모드)

    /// 알림 지점을 경계로 타이머를 구간으로 나눈 리스트
    /// 예: 15분 타이머 + 5분 전 알림 → Section 1 (0:00–10:00), Section 2 (10:00–15:00)
    private var derivedSegments: [(index: Int, startSec: Int, endSec: Int)] {
        let mainSec = isProgressMode
            ? screenVM.configuredMainSeconds
            : screenVM.mainMinutes * 60 + screenVM.mainSeconds
        guard mainSec > 0 else { return [] }
        let boundaries = screenVM.selectedOffsets
            .filter { $0 > 0 && $0 < mainSec }
            .map { mainSec - $0 }
            .sorted()
        let points = [0] + boundaries + [mainSec]
        return (0..<(points.count - 1)).map { i in
            (index: i, startSec: points[i], endSec: points[i + 1])
        }
    }

    private func derivedSectionList(maxHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: DSSpacing.sm) {
                    ForEach(derivedSegments, id: \.index) { seg in
                        derivedSectionRow(seg)
                            .id(seg.index)
                    }
                }
                .padding(.horizontal, 16)
                // 알림 토글로 구간이 나뉘거나 합쳐질 때 부드럽게
                .animation(.easeInOut(duration: 0.25), value: screenVM.sortedOffsetsDesc)
                // 편집 포커스 이동 시 하이라이트 전환
                .animation(.easeInOut(duration: 0.2), value: focusedSectionIndex)
            }
            .frame(maxHeight: maxHeight)
            // 리스트를 끌면 키보드가 따라 내려감
            .scrollDismissesKeyboard(.interactively)
            // 편집을 시작하면 그 카드를 보이는 자리로 끌어온다.
            // 두 번 스크롤하는 이유: 누른 즉시 한 번(반응이 바로 보이게), 키보드가 다 올라와
            // 리스트 높이가 줄어든 뒤에 또 한 번(줄어든 창 기준으로 다시 맞춰야 실제로 보인다).
            .onChange(of: focusedSectionIndex) { _, index in
                guard let index else { return }
                scrollToSection(index, using: proxy)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard focusedSectionIndex == index else { return }
                    scrollToSection(index, using: proxy)
                }
            }
        }
    }

    private func scrollToSection(_ index: Int, using proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(index, anchor: .center)
        }
    }

    /// 한 구간 카드 — 2단 구성(이름+길이 배지 / 시간 범위)으로 빼곡함을 덜어 한눈에 들어오게
    @ViewBuilder
    private func derivedSectionRow(_ seg: (index: Int, startSec: Int, endSec: Int)) -> some View {
        let isEditingThis = focusedSectionIndex == seg.index
        HStack(alignment: .top, spacing: DSSpacing.md) {
            // 링의 해당 구간과 같은 색 — 어느 호가 이 구간인지 연결
            Circle()
                .fill(sectionColor(seg.index))
                .frame(width: 12, height: 12)
                .padding(.top, DSSpacing.xs)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                // 1단: 구간 이름 + 길이 배지
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.sm) {
                    TextField(
                        String(localized: "Section \(seg.index + 1)"),
                        text: sectionNameBinding(seg.index)
                    )
                    .font(DSFont.body.weight(.semibold))
                    .disabled(!isTimeEditable)
                    .focused($focusedSectionIndex, equals: seg.index)
                    .submitLabel(.done)
                    .accessibilityLabel(String(localized: "Section name"))

                    Spacer(minLength: DSSpacing.sm)

                    Text(durationText(seg.endSec - seg.startSec))
                        .font(DSFont.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(DSColor.marker)
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xxs)
                        .background(Capsule().fill(DSColor.marker.opacity(DSOpacity.subtle)))
                }

                // 2단: 시간 범위 (보조 정보)
                Text("\(rangeText(seg.startSec)) – \(rangeEndText(seg.endSec))")
                    .font(DSFont.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(isEditingThis
                    ? sectionColor(seg.index).opacity(DSOpacity.subtle)
                    : Color(.systemGray6))
        )
        .overlay(
            // 편집 중인 구간은 구간색 테두리로 포커싱
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(
                    isEditingThis ? sectionColor(seg.index) : .clear,
                    lineWidth: 1.5
                )
        )
        // 다른 구간을 편집 중이면 이 행은 한 발 물러남
        .opacity(focusedSectionIndex == nil || isEditingThis ? 1.0 : 0.55)
        .accessibilityElement(children: .combine)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    /// 초 → "10:00" 형태 (M:SS 표기 통일)
    private func durationText(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }

    /// 구간 범위 시작 표기 — 타이머의 처음이면 "시작", 경계는 알림 칩과 같은 "종료 기준 N 전"
    private func rangeText(_ sec: Int) -> String {
        guard sec != 0 else { return String(localized: "Start") }
        return boundaryText(sec)
    }

    /// 구간 범위 끝 표기 — 타이머의 끝이면 "종료", 경계는 알림 칩과 같은 "종료 기준 N 전"
    private func rangeEndText(_ sec: Int) -> String {
        guard sec != derivedSegments.last?.endSec else { return String(localized: "End") }
        return boundaryText(sec)
    }

    /// 경계 시각을 알림 칩과 같은 좌표(종료까지 남은 시간)로 표기 — "5:00 전"
    private func boundaryText(_ elapsedSec: Int) -> String {
        let total = derivedSegments.last?.endSec ?? 0
        let remaining = max(0, total - elapsedSec)
        return String(localized: "\(mmss(from: remaining)) left")
    }

    /// 실행 중 현재 진행 중인 구간 (경과 시간 기준)
    /// 발표 모드: 항상 표시 (placeholder 포함)
    /// 타이머 모드: 사용자가 직접 이름을 지은 구간만 표시
    private var currentSegment: (index: Int, name: String)? {
        guard isProgressMode else { return nil }
        let segments = derivedSegments
        guard !segments.isEmpty else { return nil }

        let total = Double(screenVM.configuredMainSeconds)
        let elapsed = total - max(0, screenVM.remaining)
        let seg = segments.first(where: { Double($0.endSec) > elapsed }) ?? segments[segments.count - 1]

        let custom = (screenVM.sectionNames[seg.index] ?? "").trimmingCharacters(in: .whitespaces)
        if !isPresentationMode && custom.isEmpty { return nil }
        return (seg.index, custom.isEmpty ? sectionDisplayName(seg.index) : custom)
    }

    /// 구간 표시 이름 — 사용자 지정 이름이 있으면 그것, 없으면 placeholder
    private func sectionDisplayName(_ index: Int) -> String {
        let custom = (screenVM.sectionNames[index] ?? "").trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? String(localized: "Section \(index + 1)") : custom
    }

    /// 구간 이름 바인딩 — 빈 값이면 저장하지 않고 placeholder로 복귀
    private func sectionNameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { screenVM.sectionNames[index] ?? "" },
            set: { screenVM.sectionNames[index] = $0.isEmpty ? nil : $0 }
        )
    }

    @ViewBuilder
    private var nextAlertInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bell.badge")
                    .dsScaledFont(16, weight: .semibold, relativeTo: .body, maxSize: 22)
                Text(screenVM.nextAlertText)
                    .dsScaledFont(17, weight: .semibold, design: .rounded, relativeTo: .body, maxSize: 24)
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

    private func mmss(from sec: Int) -> String {
        let t = max(0, sec)
        return TimeMapper.formatTime(minutes: t / 60, seconds: t % 60)
    }

    private func mmss(sec: Int, min: Int) -> String {
        TimeMapper.formatTime(minutes: min, seconds: sec)
    }
    
    func snappedAngle(from rawAngle: Double) -> Double {
        TimeMapper.snappedAngle(from: rawAngle)
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
            return "Ready"
        case .running:
            return "In Progress"
        case .paused:
            return "Paused"
        case .finished:
            return "Done"
        case .overtime:
            return "Overtime"
        }
    }

    /// VoiceOver 라벨용 상태 문자열 ("Timer, 준비됨" 형태로 시간 값과 결합)
    private var stateLabel: String {
        let state: String
        switch screenVM.state {
        case .idle:
            state = String(localized: "Ready")
        case .running:
            state = String(localized: "In Progress")
        case .paused:
            state = String(localized: "Paused")
        case .finished:
            state = String(localized: "Done")
        case .overtime:
            state = String(localized: "Overtime")
        }
        return String(localized: "Timer, \(state)")
    }

    // 왼쪽 버튼 (Cancel) - Start Timer 후에만 표시
    @ViewBuilder
    private func leftButton(buttonSize: CGFloat) -> some View {
        if screenVM.state != .idle {
            Button(action: {
                // 비율 링 → 절대 각도 다이얼로 역모핑
                withAnimation(.easeInOut(duration: 0.4)) {
                    screenVM.cancel()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.plain,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Cancel Timer"))
        }
    }

    // 오른쪽 버튼 (재생/Pause)
    @ViewBuilder
    private func rightButton(buttonSize: CGFloat) -> some View {
        switch screenVM.state {
        case .idle, .finished:
            Button(action: {
                if isPresentationMode {
                    // 알림 경계로부터 구간을 생성한 뒤 발표 시작
                    screenVM.syncSectionsFromAlerts()
                    withAnimation(.easeInOut(duration: 0.4)) {
                        screenVM.startPresentation()
                    }
                    return
                }
                screenVM.applyCurrentSettings()
                // 설정 호(절대 각도)가 100% 링으로 차오르는 모핑
                withAnimation(.easeInOut(duration: 0.4)) {
                    screenVM.start()
                }
            }) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.positive,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Start Timer"))

        case .running, .overtime:
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    screenVM.pause()
                }
            }) {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.negativeSoft,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Pause Timer"))

        case .paused:
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    screenVM.resume()
                }
            }) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(
                tint: DSColor.positive,
                size: buttonSize
            ))
            .accessibilityLabel(String(localized: "Resume Timer"))
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

#Preview {
    TimerMainView()
        .environmentObject(TimerScreenViewModel())
}
