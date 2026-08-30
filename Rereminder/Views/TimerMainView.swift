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

    /// 이름을 편집하는 중인가.
    ///
    /// ⚠️ `focusedSectionIndex != nil` 을 그대로 쓰면 안 된다. 구간 1 → 구간 2 로 포커스를 옮길 때
    ///    그 사이에 잠깐 nil 이 되는데, 그 한 프레임 때문에 리스트 높이(0.55 → 0.4 → 0.55)와
    ///    원 크기가 왕복하면서 화면이 통째로 흩어졌다 다시 조립되는 것처럼 보인다.
    ///    그래서 포커스가 풀려도 잠깐 붙잡아 두고, 정말 끝났을 때만 되돌린다.
    @State private var isEditingSectionName = false
    @State private var editingHoldTask: Task<Void, Never>?

    /// 구간 번호를 지금 보여도 되는지 — 움직임이 멎고 나서 켠다.
    @State private var sectionNumbersVisible = false
    @State private var sectionNumbersTask: Task<Void, Never>?

    /// 안쪽 줄(60분 초과)이 나타나고 사라질 때 12시부터 빙 둘러 차오르는 정도 (0 → 1).
    /// 없다가 통째로 그려지면 "뿅" 하고 튀어나온 것처럼 보인다.
    @State private var innerRingReveal: CGFloat = 0
    @State private var dragTooltipAngle: Double = 0
    @State private var draggingMarkerOffset: Int?
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
    @State private var lingeringMarkerOffset: Int?

    // 실행 중 원 아래에 서는 기기 연결 상태 — 워치는 실시간, 맥은 iCloud에 남긴 표시로 안다.
    @ObservedObject private var watchLink = WatchConnectivityManager.shared
    @State private var macLinkStatus: DevicePresence.Status = .away(lastSeen: nil)
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
    /// 링을 **절대 각도**(1° = 10초)로 그리는가. 아니면 비율(설정 시간 = 한 바퀴)이다.
    ///
    /// 진행 중에는 보통 비율로 그린다(10분 타이머도 링이 가득 차서 줄어드는 게 읽기 쉽다).
    /// 다만 60분을 넘는 타이머까지 비율로 누르면 90분이 한 바퀴로 압축돼, 방금 대기 화면에서 보던
    /// **두 줄이 사라진다.** 그래서 긴 타이머는 진행 중에도 절대 각도를 유지한다.
    private var usesAbsoluteRing: Bool {
        DialRing.usesAbsoluteCoordinates(isRunning: isProgressMode,
                                                configuredSeconds: screenVM.configuredMainSeconds)
    }

    /// 남은 시간을 링 좌표로 (1.0 = 한 바퀴). 절대 각도로 그릴 때 쓴다.
    private var remainingLaps: CGFloat { DialRing.laps(ofSeconds: remaining) }

    /// 지금 두 줄로 그려지는가 (60분을 넘겼는가)
    /// 링에 구간 번호를 붙일지.
    ///
    /// ⚠️ 움직이는 동안에는 붙이지 않는다. 호는 애니메이션으로 움직이는데 숫자는 계산이 끝난
    ///    자리에 곧바로 찍히기 때문에, 이동 중에 숫자만 먼저 가 있는 엉뚱한 그림이 된다.
    ///    드래그·줄 이동이 **다 멎은 뒤**(`sectionNumbersVisible`) 살짝 떠오른다.
    private var showsSectionNumbers: Bool {
        // 진행 중에는 숫자를 붙이지 않는다 — 구간이 하나씩 사라지면서 번호만 바뀌면 어지럽다.
        showsAlertSectionColors && sectionNumbersVisible && isTimeEditable
    }

    /// 무언가 움직였다 — 숫자를 감추고, 조용해지면 다시 띄운다.
    /// 드래그처럼 값이 계속 바뀌는 동안에는 예약이 계속 밀려 숫자가 뜨지 않는다.
    private func deferSectionNumbers() {
        sectionNumbersTask?.cancel()
        if sectionNumbersVisible {
            withAnimation(.easeOut(duration: 0.12)) { sectionNumbersVisible = false }
        }
        sectionNumbersTask = Task {
            // 줄 이동(0.22초)·바탕 링 차오르기(0.45초)가 끝나고 나서
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) { sectionNumbersVisible = true }
        }
    }

    private var hasSecondRow: Bool {
        DialRing.rows(laps: usesAbsoluteRing
                      ? (isProgressMode ? remainingLaps : CGFloat(max(0, screenVM.mainAngle) / 360.0))
                      : ratio).inner > 0
    }

    /// 가운데(시간·버튼)가 쓸 수 있는 지름 — 링 두께와 여유를 뺀 값.
    /// 두 줄이면 안쪽 줄 안쪽이 한계다.
    private func centerContentDiameter(size: CGFloat, lineWidth: CGFloat) -> CGFloat {
        if hasSecondRow {
            // 두 줄이면 안쪽 줄 안쪽이 한계
            return max(0, innerRingSize(size, lineWidth: lineWidth) - lineWidth * 2 - 24)
        }
        // 링 두께(양쪽) + 링에 닿지 않을 여백
        return max(0, size - lineWidth * 2 - 24)
    }

    /// 지금 화면에 보이는 알림 지점들 — 종을 끌고 있으면 그 종만 손끝 위치로 바꿔서 본다.
    /// 저장은 손을 뗄 때 이뤄지므로, 이걸 쓰지 않으면 드래그 중에 구간 색 경계가 따라오지 않는다.
    private var liveOffsets: Set<Int> {
        guard let dragging = draggingMarkerOffset else { return screenVM.selectedOffsets }
        var offsets = screenVM.selectedOffsets
        offsets.remove(dragging)
        let dragged = TimeMapper.angleToSeconds(from: markerDragAngle)
        if dragged > 0 { offsets.insert(dragged) }
        return offsets
    }

    private var markers: [CGFloat] {
        let offsets = liveOffsets.sorted()
        guard usesAbsoluteRing else {
            // 비율 좌표: 10분 타이머의 1분 전 알림 = 링의 10% 지점
            let total = CGFloat(max(1, screenVM.configuredMainSeconds))
            return offsets.map { CGFloat($0) / total }
        }
        return offsets.map { CGFloat($0) / CGFloat(TimeMapper.secondsPerLap) }
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
                clockView(size: clockSize,
                          lineWidth: lineWidth,
                          geometry: geometry,
                          buttonSize: buttonSize)
                    .zIndex(1)

                // **걸기 전에도 구간이 몇 분짜리인지 보인다.** 종을 옮기는 조작은 각도라
                // "그래서 첫 구간이 몇 분이지?"를 머리로 계산하게 되는데, 그 답을 바로 옆에 둔다.
                // 실행 중에는 세우지 않는다 — 그 자리는 원 아래 줄어드는 숫자(SectionCountdownList) 몫이다.
                if !isProgressMode, !isPresentationMode, derivedSegments.count > 1 {
                    SectionLengthBar(segments: derivedSegments)
                        .padding(.top, spacing * 2)
                        .transition(.opacity)
                }

                Spacer()

                // "손목에서도 볼 수 있나?"는 **걸기 전에** 알아야 고칠 수 있다.
                // 그래서 대기 중에도 그대로 둔다(설정 화면에만 두면 아무도 안 본다).
                // 발표 모드에서만 뺀다 — 구간 리스트가 화면 절반을 쓰는 자리라 한 줄이 아쉽다.
                if !isPresentationMode {
                    DeviceLinkChips(watchStatus: watchLink.linkStatus, macStatus: macLinkStatus)
                        .padding(.bottom, spacing)
                        .transition(.opacity)
                }

                if isPresentationMode, isProgressMode, let panel = currentScript {
                    // 발표 중에는 **지금 구간의 대본**이 그 자리를 쓴다 — 목록은 고칠 때 필요한 것이고,
                    // 도는 동안에는 읽을 것만 남는다.
                    PresentationScriptPanel(sectionIndex: panel.index,
                                            sectionName: panel.name,
                                            script: panel.script,
                                            nextName: panel.nextName,
                                            maxHeight: availableHeight * 0.26)
                        .padding(.bottom, spacing * 2)
                        .transition(.opacity)
                } else if isPresentationMode {
                    // 알림 지점 기준 파생 구간 리스트 (원 밖 아래쪽)
                    // 이름을 편집하는 동안에는 키보드가 화면을 절반 가까이 먹으므로 리스트 몫을 늘린다
                    // (원은 그만큼 작아지지만, 그때 중요한 건 지금 고치는 구간이 보이는 것이다)
                    PresentationSectionList(
                        screenVM: screenVM,
                        focusedSectionIndex: $focusedSectionIndex,
                        segments: derivedSegments,
                        maxHeight: availableHeight * (isEditingSectionName ? 0.55 : 0.4),
                        isEditable: isTimeEditable
                    )
                        .padding(.bottom, spacing * 2)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if isProgressMode && derivedSegments.count > 1 {
                    // 구간별 카운트다운 (원 밖 아래쪽) — 링이 "전체가 얼마나 남았나"라면
                    // 이건 "지금 이 구간이 얼마 남았나"다. 다음 알림까지의 시간이 곧 지금 구간의
                    // 남은 시간이라 `nextAlertInfo` 자리를 대신한다(둘 다 두면 같은 말이 두 번).
                    SectionCountdownList(
                        segments: derivedSegments,
                        elapsedSec: elapsedSec,
                        maxHeight: availableHeight * 0.22
                    )
                        .padding(.bottom, spacing * 2)
                        .transition(.opacity)
                } else if isProgressMode && !screenVM.nextAlertText.isEmpty {
                    // Next 알림 Info (원 밖 아래쪽) — 알림이 하나뿐이라 구간 리스트가 무의미할 때
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
            // 리스트가 커지면 원이 작아진다 — 두 변화가 한 몸으로 움직여야 매끄럽다
            .animation(.easeInOut(duration: 0.28), value: isEditingSectionName)
            // ⚠️ 이게 없으면 Spacer·여백처럼 아무것도 그리지 않은 자리는 탭이 잡히지 않아
            //    "화면 아무 데나 눌러 키보드 내리기"가 원·카드 위에서만 동작한다.
            .contentShape(Rectangle())
            .onAppear(perform: refreshDeviceLinks)
            // 타이머를 거는 순간 다시 확인한다 — 그 사이 워치가 꺼졌을 수도 있다.
            .onChange(of: screenVM.state) { _, newState in
                if newState == .running { refreshDeviceLinks() }
            }
            // 다른 기기가 iCloud에 표시를 남기면 그때 따라간다.
            .onReceive(NotificationCenter.default.publisher(
                for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
                macLinkStatus = DevicePresence.status(of: .mac)
            }
        }
        // 빈 곳을 탭하면 키보드 내림.
        // ⚠️ 편집 중이 아닐 때는 아예 인식하지 않는다(mask: .none) — 다이얼을 만지는 평상시에
        //    화면 전체를 덮는 제스처를 하나 더 얹어 둘 이유가 없다.
        .simultaneousGesture(
            TapGesture().onEnded { focusedSectionIndex = nil },
            including: focusedSectionIndex == nil ? .none : .all
        )
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

    private func clockView(size: CGFloat,
                           lineWidth: CGFloat,
                           geometry: GeometryProxy,
                           buttonSize: CGFloat) -> some View {
        ZStack {
            TimerDialRings(plan: ringPlan(size: size, lineWidth: lineWidth))

            // 얇은 바깥 구간 링은 **진행 중에만**.
            // 대기 중에는 본 링이 이미 알림 경계로 구간 색이라(alertSectionRing) 같은 정보가
            // 두 겹으로 겹쳐 보인다. 진행 중에는 본 링이 남은 시간만 그리므로 이 링이 필요하다.
            if isPresentationMode && isProgressMode {
                SectionOuterRing(size: size,
                                 lineWidth: lineWidth,
                                 arcEnd: isProgressMode
                                     ? 1.0
                                     : CGFloat(min(1.0, max(0, screenVM.mainAngle) / 360.0)),
                                 markers: markers,
                                 focusedSectionIndex: focusedSectionIndex)
                    .transition(.opacity)
            }

            // 실행/일시정지 중: 줄어드는 호의 끝점을 동그라미로 표시
            if screenVM.state == .running || screenVM.state == .paused {
                progressEdgeDot(size: size, lineWidth: lineWidth)
            }

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
                MarkerDragBadge(beforeEnd: max(0, marker.seconds),
                                afterStart: max(0, (screenVM.mainMinutes * 60 + screenVM.mainSeconds)
                                                - max(0, marker.seconds)),
                                angle: marker.angle,
                                size: size,
                                availableWidth: geometry.size.width,
                                colors: sectionColors(around: marker.seconds))
                    .transition(.opacity)
                    .zIndex(2)
            }

            // 가운데 시간·버튼이 들어갈 수 있는 실제 지름.
            // 두 줄일 때는 **안쪽 줄 안쪽**이 한계다 — 바깥 원 기준으로 잡으면 "110:00" 같은 긴 시간이
            // 안쪽 링을 덮어 버리고, 시간 묶음이 ZStack 의 마지막 자식이라 그 위에 그려지므로
            // 링 위의 종·핸들 터치까지 글자가 가로챈다(실제로 조작이 안 되던 원인).
            let centerDiameter = centerContentDiameter(size: size, lineWidth: lineWidth)

            // 원 크기를 따라가되, 안쪽에 실제로 들어갈 수 있는 크기를 넘지 않는다.
            // 0.22 는 "110:00"(6글자, 가장 긴 표기)이 그 지름 안에 **여유를 두고** 들어가는 비율이다
            // (글자폭 ≈ 0.6 × 크기 × 6글자 = 3.6배 → 0.22 면 폭이 지름의 80% 정도).
            let fontSize = min(size * 0.19, centerDiameter * 0.22)

            // 시간 + 버튼 묶음을 원의 세로 중앙에 배치 (모든 모드 공통)
            VStack(spacing: fontSize * 0.45) {
                if let segment = currentSegment {
                    // 발표 모드 실행 중: 현재 구간 이름 + 구간 색 점
                    HStack(spacing: DSSpacing.xs) {
                        Circle()
                            .fill(SectionPalette.color(segment.index))
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
            // 링 안쪽으로 가둔다 — 넘치면 그 부분이 링 위 조작을 먹는다
            .frame(maxWidth: centerDiameter)
        }
        // 안쪽 줄이 생기고 사라질 때 빙 둘러 차오르게 한다.
        // 처음 화면에 나올 때(이미 60분이 넘은 설정을 복원한 경우)는 애니메이션 없이 그려 둔다 —
        // 아무 조작도 하지 않았는데 링이 혼자 도는 건 이상하다.
        .onAppear {
            innerRingReveal = hasSecondRow ? 1 : 0
            deferSectionNumbers()
        }
        // 값이 바뀔 때마다 숫자를 감추고 다시 예약한다 (드래그 중엔 계속 밀린다)
        .onChange(of: screenVM.mainAngle) { _, _ in deferSectionNumbers() }
        .onChange(of: screenVM.sortedOffsetsDesc) { _, _ in deferSectionNumbers() }
        .onChange(of: markerDragAngle) { _, _ in deferSectionNumbers() }
        .onChange(of: focusedSectionIndex) { _, index in
            editingHoldTask?.cancel()
            guard index == nil else {
                isEditingSectionName = true
                return
            }
            // 옮겨 가는 중인지(곧 다른 구간이 잡힌다) 정말 끝난 것인지 잠깐 기다렸다 판단한다
            editingHoldTask = Task {
                try? await Task.sleep(for: .seconds(0.25))
                guard !Task.isCancelled, focusedSectionIndex == nil else { return }
                isEditingSectionName = false
            }
        }
        .onChange(of: draggingMarkerOffset) { _, _ in deferSectionNumbers() }
        .onChange(of: hasSecondRow) { _, appeared in
            withAnimation(.easeInOut(duration: 0.45)) {
                innerRingReveal = appeared ? 1 : 0
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

    /// 줄어드는 호의 움직이는 끝점 표시 — 대기 중 드래그 핸들과 같은 시각 언어(흰 원)
    private func progressEdgeDot(size: CGFloat, lineWidth: CGFloat) -> some View {
        let angle = Double(usesAbsoluteRing ? remainingLaps : ratio) * 360.0
        return Circle()
            .fill(.white)
            .frame(width: lineWidth * 0.9, height: lineWidth * 0.9)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 0)
            // 두 줄일 때는 끝점도 지금 줄어드는 줄 위에 있어야 한다
            .offset(x: ringSize(forAngle: angle, size: size, lineWidth: lineWidth) / 2)
            .animation(Self.lapChangeAnimation, value: isSecondLap(angle))
            .rotationEffect(.degrees(angle))
            .rotationEffect(.degrees(-90))
            .accessibilityHidden(true)
    }

    /// 링을 알림 경계로 나눠 구간 색으로 칠할 때인가.
    ///
    /// 종을 잡고 있는 동안에는 **끄고** 단색 + `alertSplitArc`(시작 후/종료 전 2색)로 돌아간다.
    /// 그때 화면의 주인공은 드래그 배지 두 줄이고, 배지 줄 색과 링 구간 색이 어긋나면
    /// 어느 숫자가 어디인지 읽히지 않기 때문이다(CLAUDE.md의 배지·링 색 규칙).
    /// 종을 잡고 있는 동안에도 **그대로 둔다**. 예전에는 잡는 순간 주황/강조색 2색 분할로 갈아탔는데,
    /// 이미 구간마다 색이 있는 링에서 굳이 다른 색 체계로 바꾸면 "지금 만지는 구간이 어디였더라"를
    /// 다시 찾아야 한다. 대신 드래그 배지 두 줄이 **그 구간들의 색**을 따라간다.
    /// **진행 중에도 그대로 유지한다.** 알림으로 나뉜 링이 시작하자마자 단색으로 바뀌면
    /// "지금 몇 번째 구간을 지나고 있나"가 사라진다 — 발표 중에 가장 알고 싶은 게 그건데.
    /// 남은 호만 줄어들고 색 경계는 그 자리에 그대로 있어서, 경계를 지날 때마다 색이 하나씩 없어진다.
    /// 오버타임에서는 그릴 호 자체가 없어(0) 빨간 단색 경로로 넘긴다.
    private var showsAlertSectionColors: Bool {
        !liveOffsets.isEmpty && screenVM.state != .overtime
    }

    /// 이중 링의 **안쪽 링** — "이 구간이 얼마 남았나".
    ///
    /// 바깥(본 링)은 전체가 얼마 남았나를, 안쪽은 지금 구간이 얼마 남았나를 말한다.
    /// 원은 각도라 서로 다른 자리에 놓인 두 호를 비교하는 걸 잘 못 하는데, 층을 나누면
    /// 두 질문이 각자 자기 자리를 갖는다.
    ///
    /// 지금 지나는 중인 구간. 구간이 하나뿐이거나(안쪽이 바깥과 같은 말) 오버타임이면 없다.
    private var sectionProgress: TimerSections.Progress? {
        guard isProgressMode, screenVM.state != .overtime else { return nil }
        guard let progress = TimerSections.progress(mainSeconds: screenVM.configuredMainSeconds,
                                                    alertOffsets: screenVM.selectedOffsets,
                                                    elapsedSec: elapsedSec),
              progress.isDivided else { return nil }
        return progress
    }

    /// 한 바퀴(60분)를 넘어간 시간은 **안쪽 줄**에 그린다.
    /// 다이얼 최대가 2바퀴(120분, `TimeMapper.maxAngle`)라 줄은 둘이면 충분하다.
    private func innerRingSize(_ size: CGFloat, lineWidth: CGFloat) -> CGFloat {
        size - lineWidth * 2.6
    }

    /// 60분 경계에서 줄이 바뀌는 순간, 반지름이 뚝 끊기면 손에서 튕겨 나간 것처럼 보인다.
    /// **각도는 손끝을 그대로 따라가고(애니메이션 금지 — 미끄러지는 느낌이 난다),
    /// 줄 사이를 옮겨 가는 이동만** 짧게 미끄러뜨린다.
    private static let lapChangeAnimation: Animation = .easeInOut(duration: 0.22)

    /// 이 각도가 두 번째 바퀴(안쪽 줄)에 속하는가 — 애니메이션 트리거 값
    private func isSecondLap(_ angle: Double) -> Bool { angle >= 360 }

    /// 이 각도가 놓일 줄의 지름 — 호·종 노브·드래그 핸들이 **모두 이 하나를 따라야**
    /// 60분을 넘겼을 때 종만 바깥에 남는 식으로 어긋나지 않는다.
    private func ringSize(forAngle angle: Double, size: CGFloat, lineWidth: CGFloat) -> CGFloat {
        angle >= 360 ? innerRingSize(size, lineWidth: lineWidth) : size
    }

    /// 전체 호를 알림 경계로 자른 지점들 (1.0 = 한 바퀴, 바퀴 구분 없는 절대 좌표)
    private func sectionBounds(arcEnd: CGFloat) -> [CGFloat] {
        [0] + markers.filter { $0 > 0 && $0 < arcEnd }.sorted() + [arcEnd]
    }

    /// 드래그 중인 종의 양옆 구간 색 — 배지 두 줄이 링과 같은 색을 쓰게 한다.
    /// (⚑ 종료까지 = 종 뒤쪽 구간, ▶ 시작 후 = 종 앞쪽 구간)
    private func sectionColors(around markerSeconds: Int) -> (beforeEnd: Color, afterStart: Color) {
        let total = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        let segments = TimerSections.derive(mainSeconds: total, alertOffsets: liveOffsets)
        let boundary = total - markerSeconds

        let afterStart = segments.first { $0.endSec == boundary }
        let beforeEnd = segments.first { $0.startSec == boundary }
        return (
            beforeEnd.map { SectionPalette.color($0.index) } ?? DSColor.marker,
            afterStart.map { SectionPalette.color($0.index) } ?? Color.accentColor
        )
    }

    /// 이번 프레임에 링을 **어떻게 그릴지** 정한다. 그리는 일은 `TimerDialRings` 가 한다 —
    /// 링이 이상해 보일 때 값이 틀렸는지(여기) 그림이 틀렸는지(저기)를 갈라 보기 위해서다.
    private func ringPlan(size: CGFloat, lineWidth: CGFloat) -> TimerDialRings.Plan {
        let outer: CGFloat
        let inner: CGFloat
        let color: Color

        if screenVM.state == .running || screenVM.state == .paused {
            // 실행/Pause 중: 남은 시간이 줄어드는 링.
            // 짧은 타이머는 비율(설정 시간 = 한 바퀴), 60분을 넘으면 절대 각도라 두 줄이 유지된다.
            let rows = DialRing.rows(laps: usesAbsoluteRing ? remainingLaps : ratio)
            (outer, inner, color) = (rows.outer, rows.inner, Color.accentColor)
        } else if screenVM.state == .overtime {
            // 오버타임: 빨간 원 (음수 시간은 각도로 바꾸지 않고 0으로 둔다)
            (outer, inner, color) = (0, 0, Color.red)
        } else {
            // 대기/Done: 설정한 시간을 절대 각도(1° = 10초)로
            let rows = DialRing.rows(laps: CGFloat(max(0, screenVM.mainAngle) / 360.0))
            (outer, inner, color) = (rows.outer, rows.inner, Color.accentColor)
        }

        return TimerDialRings.Plan(
            size: size,
            lineWidth: lineWidth,
            innerSize: innerRingSize(size, lineWidth: lineWidth),
            outerFraction: outer,
            innerFraction: inner,
            // 설정 시간 전체 길이(바퀴 수 포함) — 구간 색 분할이 바퀴를 걸쳐도 이어지도록
            totalFraction: isProgressMode
                ? outer + inner
                : CGFloat(max(0, screenVM.mainAngle) / 360.0),
            innerRingReveal: innerRingReveal,
            markers: markers,
            showsSectionColors: showsAlertSectionColors,
            plainColor: color,
            focusedSectionIndex: focusedSectionIndex,
            showsSectionNumbers: showsSectionNumbers
        )
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
                // 잡는 자리는 보이는 크기보다 넓게 — 선 두께(약 25pt)만으로는 손끝이 자꾸 빗나간다.
                // 종 노브(lineWidth * 2.8)와 같은 크기로 맞춘다.
                .frame(width: lineWidth * 2.8, height: lineWidth * 2.8)
                .contentShape(Circle())
                // 설정 시간이 60분을 넘으면 호가 안쪽 줄로 넘어가므로 핸들도 같이 간다.
                // 줄이 바뀌는 그 순간만 미끄러지듯 옮겨 간다(각도는 손끝 그대로).
                .offset(x: ringSize(forAngle: screenVM.mainAngle, size: size, lineWidth: lineWidth) / 2)
                .animation(Self.lapChangeAnimation, value: isSecondLap(screenVM.mainAngle))
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
                let baseAngle: Double = usesAbsoluteRing
                    ? Double(offsetSec) / TimeMapper.secondsPerDegree
                    : Double(CGFloat(offsetSec) / total) * 360.0
                let displayAngle = draggingMarkerOffset == offsetSec ? markerDragAngle : baseAngle
                let isDraggingThis = draggingMarkerOffset == offsetSec
                // 방금 놓은 종도 배지가 남아 있는 동안은 계속 주인공이다
                let isFocused = isDraggingThis
                    || (draggingMarkerOffset == nil && lingeringMarkerOffset == offsetSec)
                // 하나를 옮기는 동안 나머지는 물러나 있어야 어느 종을 만지는지 헷갈리지 않는다
                let dimmed = isHighlighting && !isFocused
                // 좌표계와 무관하게 "남은 시간이 이 알림 지점을 지났나"로 판단한다
                let fired = isProgressMode && remaining <= TimeInterval(offsetSec)
                // 손을 떼는 순간 크기가 2.0 → 1.6 으로 바뀌면 종이 한 번 튄다.
                // 배지가 남아 있는 동안(=주인공인 동안)은 크기도 그대로 두고,
                // 배지가 녹아 사라질 때 같이 작아진다.
                let knobScale: CGFloat = isTimeEditable ? (isFocused ? 2.0 : 1.6) : 1.15

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
                // 60분을 넘어간 종은 그 시간이 그려진 안쪽 줄에 붙는다(줄 이동만 부드럽게)
                .offset(x: ringSize(forAngle: displayAngle, size: size, lineWidth: lineWidth) / 2)
                .animation(Self.lapChangeAnimation, value: isSecondLap(displayAngle))
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
                                let keeps = newSec > 0 && newSec < mainSec

                                // ⚠️ 손을 뗄 때 **애니메이션을 걸지 않는다.**
                                //    ForEach 의 id 가 알림 초라서, 지웠다가 다시 넣는 순간
                                //    SwiftUI 는 "다른 종이 사라지고 새 종이 나타났다"고 보고
                                //    `.transition(.scale + .opacity)` 를 재생한다 — 종이 펑 튀어
                                //    보이던 정체가 이거다. 각도도 10초 스냅 때문에 조금 움직이는데,
                                //    그것까지 0.2초 동안 미끄러지면 손을 뗀 자리에서 벗어나 보인다.
                                //    (링 밖으로 끌어 **지우는** 경우는 그대로 페이드아웃시킨다.)
                                var transaction = Transaction()
                                transaction.disablesAnimations = keeps
                                withTransaction(transaction) {
                                    screenVM.selectedOffsets.remove(dragOffset)
                                    if keeps {
                                        screenVM.selectedOffsets.insert(newSec)
                                        // 놓은 자리의 배지를 잠시 유지 — 그동안 종도 큰 채로 남는다
                                        lingeringMarkerOffset = newSec
                                    }
                                    draggingMarkerOffset = nil
                                }

                                guard keeps else { return }
                                markerLingerTask = Task {
                                    try? await Task.sleep(for: .seconds(Self.tooltipLingerSeconds))
                                    guard !Task.isCancelled else { return }
                                    withAnimation(.easeOut(duration: Self.dissolveDuration)) {
                                        lingeringMarkerOffset = nil
                                    }
                                }
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

    /// 가운데 시간 — **전체가 크게, 그 아래 지금 구간이 따로 돈다.**
    ///
    /// 두 숫자를 원 안에 같이 두는 이유: 실행 중에 알고 싶은 건 "언제 끝나나"와 "이 구간이 얼마
    /// 남았나" 둘 다이고, 둘을 다른 자리(원 밖 안내 박스 같은 데)에 두면 시선이 두 번 움직인다.
    /// 아래 줄 앞의 점은 링의 그 구간 색이라 "저 링 = 이 숫자"가 이어진다.
    ///
    /// ⚠️ 버튼은 원 밖에 있다(`body`). 안에 두면 이 두 줄이 들어갈 자리가 없다.
    private func centerTimeDisplay(fontSize: CGFloat) -> some View {
        let isTicking = screenVM.state == .running || screenVM.state == .overtime
        return Text(isTicking
                    ? screenVM.timeString(from: screenVM.timerVM.remaining)
                    : mmss(sec: screenVM.mainSeconds, min: screenVM.mainMinutes))
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

    // MARK: - 동작 버튼 (원 안)
    //
    // ⚠️ 2.2.0 에서 원 밖 캡슐 한 줄로 뺐다가 되돌렸다.
    //    가운데 시간 바로 아래에 있어야 "이 타이머를 멈춘다"가 한 덩어리로 읽힌다.
    //    대신 원 안을 먹으므로 가운데는 **한 줄(전체 남은 시간)만** 둔다 — 두 줄을 넣으려다
    //    버튼을 밖으로 뺐던 것이고, 그 두 줄이 없어졌으니 버튼이 다시 안으로 들어온다.

    /// 왼쪽 버튼 (정지) — 대기 중에는 없다.
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
            .buttonStyle(TimerButtonStyle(tint: DSColor.plain, size: buttonSize))
            .accessibilityLabel(String(localized: "Cancel Timer"))
        }
    }

    /// 오른쪽 버튼 (시작 / 일시정지 / 재개)
    @ViewBuilder
    private func rightButton(buttonSize: CGFloat) -> some View {
        switch screenVM.state {
        case .idle, .finished:
            Button(action: startTapped) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(tint: DSColor.positive, size: buttonSize))
            .accessibilityLabel(isPresentationMode
                                ? String(localized: "Start Session")
                                : String(localized: "Start Timer"))

        case .running, .overtime:
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { screenVM.pause() }
            }) {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(tint: DSColor.negativeSoft, size: buttonSize))
            .accessibilityLabel(String(localized: "Pause Timer"))

        case .paused:
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) { screenVM.resume() }
            }) {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .imageScale(.medium)
            }
            .buttonStyle(TimerButtonStyle(tint: DSColor.positive, size: buttonSize))
            .accessibilityLabel(String(localized: "Resume Timer"))
        }
    }

    private func buttonRow(buttonSize: CGFloat) -> some View {
        HStack(spacing: buttonSize * 0.5) {
            leftButton(buttonSize: buttonSize)
            rightButton(buttonSize: buttonSize)
        }
    }

    /// 다음 알림 안내 — **알림이 하나뿐이라 구간 리스트가 무의미할 때만** 선다
    /// (둘 다 두면 같은 말을 두 번 한다).
    private var nextAlertInfo: some View {
        HStack(spacing: 6) {
            Image(systemName: "bell.badge")
                .dsScaledFont(16, weight: .semibold, relativeTo: .body, maxSize: 22)
            Text(screenVM.nextAlertText)
                .dsScaledFont(17, weight: .semibold, design: .rounded, relativeTo: .body, maxSize: 24)
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .padding(.horizontal, 16)
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
    /// 워치·맥이 지금 닿는지 다시 읽는다.
    private func refreshDeviceLinks() {
        watchLink.refreshLinkStatus()
        macLinkStatus = DevicePresence.status(of: .mac)
    }

    /// 시작 후 경과 시간(초) — 구간 리스트가 "지금 어느 구간인지"를 이걸로 정한다.
    /// 오버타임이면 설정 시간을 넘긴 값이 되고, 그러면 모든 구간이 끝난 것으로 보인다.
    private var elapsedSec: Int {
        max(0, screenVM.configuredMainSeconds - Int(remaining.rounded()))
    }

    private var derivedSegments: [TimerSections.Segment] {
        let mainSec = isProgressMode
            ? screenVM.configuredMainSeconds
            : screenVM.mainMinutes * 60 + screenVM.mainSeconds
        return TimerSections.derive(mainSeconds: mainSec, alertOffsets: screenVM.selectedOffsets)
    }

    /// 초 → "10:00" 형태 (M:SS 표기 통일)
    private func durationText(_ sec: Int) -> String { TimeMapper.mmss(sec) }

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

    /// 발표 중 화면에 펴 놓을 **지금 구간의 대본**. 적어 둔 글이 없으면 nil(그러면 구간 목록이 선다).
    private var currentScript: (index: Int, name: String, script: String, nextName: String?)? {
        guard let progress = sectionProgress ?? TimerSections.progress(
                mainSeconds: screenVM.configuredMainSeconds,
                alertOffsets: screenVM.selectedOffsets,
                elapsedSec: elapsedSec) else { return nil }

        let script = (screenVM.sectionScripts[progress.index] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty else { return nil }

        let next = progress.index + 1 < progress.totalCount
            ? sectionDisplayName(progress.index + 1)
            : nil
        return (progress.index, sectionDisplayName(progress.index), script, next)
    }

    /// 구간 표시 이름 — 사용자 지정 이름이 있으면 그것, 없으면 placeholder
    private func sectionDisplayName(_ index: Int) -> String {
        let custom = (screenVM.sectionNames[index] ?? "").trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? String(localized: "Section \(index + 1)") : custom
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
    /// 시작 버튼이 하는 일 — 발표 모드는 구간을 먼저 만들고 시작한다.
    private func startTapped() {
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
    }
}

#Preview {
    TimerMainView()
        .environmentObject(TimerScreenViewModel())
}
