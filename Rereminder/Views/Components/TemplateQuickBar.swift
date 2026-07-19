//
//  TemplateQuickBar.swift
//  Rereminder
//
//  타이머 다이얼 아래 빠른 템플릿 바
//  - 왼쪽: 최근 사용한 템플릿 이름 칩 (탭하면 설정만 다이얼에 반영, 시작하지 않음)
//  - 오른쪽: 저장 버튼 (다이얼을 수정해 마지막 저장본과 달라졌을 때만 표시)
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

    /// 현재 다이얼이 마지막 저장 템플릿과 다른가 — 저장 버튼 노출 조건
    /// (TimerConfigService.saveIfNeeded의 중복 판정과 동일 기준)
    private var isModified: Bool {
        guard let top = allTemplates.first else { return true }
        let cfg = screenVM.normalizedCurrentConfig
        let normalizedFinish = screenVM.finishMessage.isEmpty ? nil : screenVM.finishMessage
        return !(top.mainSeconds == cfg.mainSec
            && top.prealertOffsetsSec == cfg.offsets
            && top.prealertMessages == screenVM.prealertMessages
            && top.finishMessage == normalizedFinish)
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

            if isModified {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        screenVM.saveCurrentAsTemplate()
                    }
                } label: {
                    Label(String(localized: "Save"), systemImage: "square.and.arrow.down")
                        .font(DSFont.callout.weight(.medium))
                        .lineLimit(1)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isModified)
    }

    /// 이름이 비어있으면 M:SS 시간 표기
    private func displayName(_ template: Timer) -> String {
        if !template.name.isEmpty { return template.name }
        return String(format: "%d:%02d", template.mainSeconds / 60, template.mainSeconds % 60)
    }
}
