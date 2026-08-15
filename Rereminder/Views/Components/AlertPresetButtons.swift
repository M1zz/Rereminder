//
//  AlertPresetButtons.swift
//  Rereminder
//
//  종료 전 알림 시점을 켜고 끄는 토글 버튼 행
//  프리셋(기본 1·3·5분)은 설정에서 사용자가 변경 가능
//

import SwiftUI
import TipKit

/// 미리 알림 프리셋 저장 (UserDefaults, "60,180,300" 형태)
enum AlertPresets {
    static let storageKey = "alertPresetOffsets"
    static let defaultRaw = "60,180,300"

    static func decode(_ raw: String) -> [Int] {
        let list = raw.split(separator: ",").compactMap { Int($0) }.filter { $0 > 0 }
        return list.isEmpty ? [60, 180, 300] : Array(Set(list)).sorted()
    }

    static func encode(_ list: [Int]) -> String {
        Array(Set(list.filter { $0 > 0 })).sorted().map(String.init).joined(separator: ",")
    }

    /// 칩 줄에 늘어놓을 순서 — **켜져 있는 알림이 먼저, 그 뒤에 나머지**(각 묶음 안에서는 시간순).
    ///
    /// 예: 프리셋 1:00·3:00 에 1:30 을 켜 두면 → `[90, 60, 180]` (1:30, 1:00, 3:00)
    ///
    /// 지금 무엇이 걸려 있는지가 이 줄에서 가장 중요한 정보인데, 시간순으로만 늘어놓으면
    /// 프리셋이 늘어날수록 켜 둔 칩이 오른쪽으로 밀려 스크롤해야 보인다.
    static func displayOrder(presets: [Int], selected: Set<Int>) -> [Int] {
        let all = Set(presets).union(selected)
        return all.filter { selected.contains($0) }.sorted() + all.subtracting(selected).sorted()
    }
}

/// 프리셋을 설정에서 바꿀 수 있다는 안내 팁
@available(iOS 17.0, *)
struct AlertPresetTip: Tip {
    var title: Text {
        Text("Customize alert presets")
    }
    var message: Text? {
        Text("You can set your own alert times in Settings.")
    }
    var image: Image? {
        Image(systemName: "bell.fill")
    }
}

struct AlertPresetButtons: View {
    @ObservedObject var screenVM: TimerScreenViewModel

    @AppStorage(AlertPresets.storageKey) private var presetsRaw = AlertPresets.defaultRaw

    // 5+5 trial 페이월 (2번째 알림부터 unlimitedPrealerts 평가)
    @State private var showPaywall = false
    @State private var paywallStage: ProGate.PaywallStage = .second
    /// 페이월에서 연장 체험 수락 시 이어서 추가할 시점
    @State private var pendingGatedOffset: Int?

    /// 프리셋 + 현재 선택된 시점 — 켜진 알림이 앞, 나머지가 뒤(규칙은 `AlertPresets.displayOrder`).
    private var displayOffsets: [Int] {
        AlertPresets.displayOrder(presets: AlertPresets.decode(presetsRaw),
                                  selected: screenVM.selectedOffsets)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // 팝오버는 첫 탭을 "닫기"로 소비해 + 버튼 첫 클릭을 막으므로 인라인 팁 사용
            presetTipView

            ScrollViewReader { proxy in
                chipRow(proxy: proxy)
            }
        }
        .paywallGate(
            isPresented: $showPaywall,
            feature: .unlimitedPrealerts,
            stage: paywallStage,
            onAcceptExtension: insertPendingGatedOffset
        )
    }

    @ViewBuilder
    private var presetTipView: some View {
        if #available(iOS 17.0, *) {
            TipView(AlertPresetTip())
                .padding(.horizontal, DSSpacing.md)
        }
    }

    private func chipRow(proxy: ScrollViewProxy) -> some View {
            HStack(spacing: DSSpacing.sm) {
                // 텍스트 설명 대신 심볼 — 링 위 알림 마커와 같은 색
                Image(systemName: "bell.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSColor.marker)
                    .accessibilityHidden(true)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.sm) {
                        ForEach(displayOffsets, id: \.self) { offset in
                            let selected = screenVM.selectedOffsets.contains(offset)
                            Button {
                                if selected {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        _ = screenVM.selectedOffsets.remove(offset)
                                    }
                                } else {
                                    insertGated(offset)
                                }
                            } label: {
                                HStack(spacing: 2) {
                                    Text(offsetLabel(offset))
                                        .font(DSFont.callout.weight(.medium))
                                    if isLocked(offset: offset, selected: selected) {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                                .padding(.horizontal, DSSpacing.xs)
                                .frame(minWidth: 48, minHeight: 34)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            // 링 위의 알림 마커(주황)와 같은 색으로 선택 상태 표시
                            .tint(selected ? DSColor.marker : .gray)
                            .accessibilityLabel(String(localized: "Alert \(offset / 60) minutes before end"))
                            .accessibilityHint(String(localized: "Double tap to toggle this alert."))
                            .accessibilityAddTraits(selected ? [.isSelected] : [])
                            // 커스텀 칩이 꺼질 때 축소+페이드로 사라지도록
                            .transition(.scale.combined(with: .opacity))
                            .id(offset)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: displayOffsets)
                }
                // 알림이 새로 켜지면 그 칩이 보이도록 스크롤한다.
                // + 버튼뿐 아니라 링에서 종을 끌어 만든 알림·템플릿 적용까지 전부 여기서 처리한다.
                // ⚠️ 켜진 칩은 항상 맨 앞 묶음으로 가므로 **왼쪽 끝**을 보여준다. 목록(displayOffsets)이
                //    아니라 선택 자체를 봐야 이미 있던 프리셋을 켠 경우(목록은 그대로, 자리만 앞으로
                //    이동)에도 따라간다.
                // 실제로 칩이 레이아웃된 다음 프레임에 스크롤해야 "아직 없는 id로 scrollTo"가
                // 무시되는 타이밍 레이스를 피할 수 있다.
                .onChange(of: screenVM.selectedOffsets) { previous, current in
                    // 여러 개가 한꺼번에 켜지면(템플릿 적용 등) 가장 왼쪽 것을 기준으로 삼는다
                    guard let target = current.subtracting(previous).min() else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(target, anchor: .leading)
                        }
                    }
                }

                // 스크롤과 무관하게 항상 트레일링에 고정
                Button {
                    addMidpointAlert()
                } label: {
                    Image(systemName: "plus")
                        .font(DSFont.callout.weight(.semibold))
                        .frame(minWidth: 34, minHeight: 34)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.gray)
                .accessibilityLabel(String(localized: "Add alert time"))
                .accessibilityHint(String(localized: "Adds an alert halfway between the last alert and the end."))
            }
            .padding(.horizontal, DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 타이머 시작과 가장 먼저 울리는 알림 사이의 중간 지점에 알림 추가
    /// → 새 알림이 항상 가장 먼저 울리는 알림이 된다
    /// 예: 10분 타이머에 5분 전 알림만 있으면 → 7:30 전(경과 2:30 시점) 추가
    /// 알림이 없으면 타이머 전체의 중간 지점에 추가
    /// (추가된 칩으로의 스크롤은 `displayOffsets` 변화를 보고 알아서 따라간다)
    private func addMidpointAlert() {
        let mainSec = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        guard mainSec > 0 else { return }

        let firstOffset = screenVM.selectedOffsets
            .filter { $0 < mainSec }
            .max()
        let rawOffset = firstOffset.map { (mainSec + $0) / 2 } ?? mainSec / 2
        // 5초 단위로 반올림, 최소 5초
        let newOffset = max(5, Int((Double(rawOffset) / 5.0).rounded()) * 5)

        guard newOffset < mainSec,
              !screenVM.selectedOffsets.contains(newOffset) else { return }

        insertGated(newOffset)
    }

    // MARK: - Pro Gate (unlimitedPrealerts)

    /// 1번째 알림은 항상 free, 2번째부터 5+5 trial 평가 (PrealertSettingsView와 동일 정책)
    private func insertGated(_ offset: Int) {
        if screenVM.selectedOffsets.count >= ProGate.freePrealertLimit {
            switch ProGate.evaluate(.unlimitedPrealerts) {
            case .allowed, .allowedWithTrial:
                break
            case .blocked(let stage):
                paywallStage = stage
                pendingGatedOffset = offset
                showPaywall = true
                AnalyticsManager.log(.premiumTrialExhausted(
                    feature: .unlimitedPrealerts,
                    stage: stage
                ))
                return
            }
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            _ = screenVM.selectedOffsets.insert(offset)
        }
    }

    /// 페이월에서 연장 체험 수락 시, 막혔던 시점을 이어서 추가
    private func insertPendingGatedOffset() {
        guard let offset = pendingGatedOffset else { return }
        pendingGatedOffset = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            _ = screenVM.selectedOffsets.insert(offset)
        }
    }

    /// 잠금 아이콘 표시 여부 — 미선택 칩이고, 추가하려면 Pro/trial 이 필요한데 소진된 경우
    private func isLocked(offset: Int, selected: Bool) -> Bool {
        !selected
            && !StoreManager.isProUser
            && screenVM.selectedOffsets.count >= ProGate.freePrealertLimit
            && !ProGate.evaluate(.unlimitedPrealerts).isAllowed
    }

    /// 항상 "M:SS" 표기 (예: 1:00, 2:30)
    private func offsetLabel(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }
}
