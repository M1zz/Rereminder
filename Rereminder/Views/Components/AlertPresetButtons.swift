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

    /// + 로 추가된 칩으로 스크롤할 대상 — 칩이 레이아웃된 뒤(onChange) 스크롤해야
    /// "아직 없는 id로 scrollTo"가 무시되는 타이밍 레이스를 피한다
    @State private var pendingScrollOffset: Int?

    /// 프리셋 + 현재 선택된 시점의 합집합 (오름차순)
    private var displayOffsets: [Int] {
        Array(Set(AlertPresets.decode(presetsRaw)).union(screenVM.selectedOffsets)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            // 팝오버는 첫 탭을 "닫기"로 소비해 + 버튼 첫 클릭을 막으므로 인라인 팁 사용
            presetTipView

            ScrollViewReader { proxy in
                chipRow(proxy: proxy)
            }
        }
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
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if selected {
                                        screenVM.selectedOffsets.remove(offset)
                                    } else {
                                        screenVM.selectedOffsets.insert(offset)
                                    }
                                }
                            } label: {
                                Text(offsetLabel(offset))
                                    .font(DSFont.callout.weight(.medium))
                                    .padding(.horizontal, DSSpacing.sm)
                                    .frame(minWidth: 56, minHeight: 44)
                            }
                            .buttonStyle(.bordered)
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
                // 새 칩이 실제로 추가된 다음 프레임에 끝으로 스크롤
                .onChange(of: displayOffsets) { _, _ in
                    guard let target = pendingScrollOffset else { return }
                    pendingScrollOffset = nil
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo(target, anchor: .trailing)
                        }
                    }
                }

                // 스크롤과 무관하게 항상 트레일링에 고정
                Button {
                    addMidpointAlert()
                } label: {
                    Image(systemName: "plus")
                        .font(DSFont.callout.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
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
    /// 추가 후 새 칩이 보이도록 스크롤 이동
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

        pendingScrollOffset = newOffset
        withAnimation(.easeInOut(duration: 0.25)) {
            _ = screenVM.selectedOffsets.insert(newOffset)
        }
    }

    /// 항상 "M:SS" 표기 (예: 1:00, 2:30)
    private func offsetLabel(_ sec: Int) -> String {
        String(format: "%d:%02d", sec / 60, sec % 60)
    }
}
