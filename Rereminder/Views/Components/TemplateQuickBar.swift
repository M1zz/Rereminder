//
//  TemplateQuickBar.swift
//  Rereminder
//
//  타이머 다이얼 아래 빠른 템플릿 바
//  - 왼쪽: 최근 사용한 템플릿 이름 칩 (탭하면 설정만 다이얼에 반영, 시작하지 않음)
//  - 오른쪽: 초기화 + 템플릿 저장 버튼
//
//  두 버튼 다 **사용자가 뭔가 바꿨을 때만** 나온다.
//  갓 설치한 기본 설정 그대로면 저장할 것도 되돌릴 것도 없어서 바에는 템플릿 칩만 남는다.
//

import SwiftData
import SwiftUI

struct TemplateQuickBar: View {
    @ObservedObject var screenVM: TimerScreenViewModel

    @Query(sort: [SortDescriptor(\Timer.createdAt, order: .reverse)])
    private var allTemplates: [Timer]

    /// 최근 사용 순 (사용 기록이 없으면 생성일 기준)
    private var recentTemplates: [Timer] {
        allTemplates.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }

    /// 저장할 것이 있는가 — 버튼 노출 조건
    /// 시간·예비 알림·문구 중 하나라도 기존 템플릿과 다르면 true.
    /// 같은 설정의 템플릿이 이미 있거나 저장할 시간이 없으면 false (버튼 숨김).
    private var hasUnsavedChanges: Bool {
        // 갓 설치한 기본 설정 그대로면 사용자가 만든 게 없다 — 저장할 것도 없다
        guard !screenVM.isAtDefaultSetup else { return false }

        let cfg = screenVM.normalizedCurrentConfig
        guard cfg.mainSec > 0 else { return false }
        let messages: [Int: String] = screenVM.prealertMessages
        let finish: String? = screenVM.finishMessage.isEmpty ? nil : screenVM.finishMessage

        for template in allTemplates {
            guard template.mainSeconds == cfg.mainSec else { continue }
            guard template.prealertOffsetsSec == cfg.offsets else { continue }
            guard template.prealertMessages == messages else { continue }
            guard template.finishMessage == finish else { continue }
            return false
        }
        return true
    }

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    ForEach(recentTemplates) { template in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                screenVM.load(template: template)
                            }
                        } label: {
                            Text(displayName(template))
                                .font(DSFont.callout.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, DSSpacing.sm)
                                .frame(minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(String(localized: "Applies this template to the timer"))
                    }
                }
                .padding(.horizontal, 2)
            }

            // 저장 버튼 왼쪽 — 갓 설치했을 때의 설정으로 되돌린다
            if canReset {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        screenVM.resetToDefaultSetup()
                    }
                } label: {
                    Label(String(localized: "Reset"), systemImage: "arrow.counterclockwise")
                        .font(DSFont.callout.weight(.medium))
                        .lineLimit(1)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(String(localized: "Reset the timer to the default setup"))
                // 템플릿 칩 스크롤뷰보다 먼저 제 너비를 가져간다 (안 그러면 글자가 잘린다)
                .layoutPriority(1)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if hasUnsavedChanges {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        screenVM.saveCurrentAsTemplate()
                    }
                } label: {
                    Label(String(localized: "Save template"), systemImage: "square.and.arrow.down")
                        .font(DSFont.callout.weight(.medium))
                        .lineLimit(1)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(String(localized: "Save the current settings as a template"))
                .layoutPriority(1)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasUnsavedChanges)
        .animation(.easeInOut(duration: 0.2), value: canReset)
    }

    /// 되돌릴 것이 있는가 — 기본 설정 그대로면 눌러도 아무 일이 없으니 숨긴다
    private var canReset: Bool {
        !screenVM.isAtDefaultSetup
    }

    /// 이름이 비어있으면 M:SS 시간 표기
    private func displayName(_ template: Timer) -> String {
        if !template.name.isEmpty { return template.name }
        return TimeMapper.mmss(template.mainSeconds)
    }
}
