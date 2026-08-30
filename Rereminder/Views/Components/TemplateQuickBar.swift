//
//  TemplateQuickBar.swift
//  Rereminder
//
//  타이머 다이얼 아래 빠른 템플릿 바
//  - 왼쪽: 최근 사용한 템플릿 이름 칩 (탭하면 설정만 다이얼에 반영, 시작하지 않음)
//  - 오른쪽: 초기화(아이콘) + 저장(캡슐)
//
//  두 버튼 다 **사용자가 뭔가 바꿨을 때만** 나온다.
//  갓 설치한 기본 설정 그대로면 저장할 것도 되돌릴 것도 없어서 바에는 템플릿 칩만 남는다.
//
//  ⚠️ **저장·불러오기는 Pro 다**(`ProGate.canRememberSetup`) — 이 앱이 파는 한 문장이
//     "설정을 기억한다"이기 때문이다. 무료에서는 칩이 **사라지지 않고 잠긴 채로** 보인다:
//     예전에 저장해 둔 것이 소리 없이 없어지면 "잃어버렸다"가 되고, 그건 결제가 아니라 분노다.
//
//  ⚠️ 버튼 위계 — 초기화는 **아이콘만**(되돌리는 일은 자주 쓰지 않고, 글자를 달면 저장 버튼과
//     같은 무게로 보여 무엇이 주된 행동인지 흐려진다), 저장만 채운 캡슐로 남긴다.
//     아이콘만이라 예전의 글자 잘림 문제(layoutPriority)도 사라졌다.
//

import SwiftData
import SwiftUI

struct TemplateQuickBar: View {
    @ObservedObject var screenVM: TimerScreenViewModel

    @State private var showPaywall = false

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
            // 저장해 둔 템플릿이 없으면 스크롤뷰가 빈 자리를 다 먹어 버튼 둘이 오른쪽 끝에
            // 붙는다 — 바로 위의 연결 칩은 가운데라 축이 어긋나 보인다. 그때는 가운데로 모은다.
            if recentTemplates.isEmpty {
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.xs) {
                        ForEach(recentTemplates) { template in
                            templateChip(template)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            if canReset {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        screenVM.resetToDefaultSetup()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Reset the timer to the default setup"))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if hasUnsavedChanges {
                Button {
                    guard ProGate.canRememberSetup else {
                        showPaywall = true
                        return
                    }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        screenVM.saveCurrentAsTemplate()
                    }
                    // 한 번 저장해 본 사람에게는 더 권하지 않는다
                    FeatureTips.markTemplateSaved()
                } label: {
                    HStack(spacing: DSSpacing.xs) {
                        Image(systemName: ProGate.canRememberSetup ? "bookmark.fill" : "lock.fill")
                            .font(.caption2.weight(.semibold))
                        Text("Save")
                            .font(DSFont.callout.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Save the current settings as a template"))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                // 같은 설정을 여러 번 맞춰 본 뒤에야 뜬다 (타이머 3회 시작 + 저장 이력 없음)
                .modifier(SaveTemplateTipAnchor())
            }

            if recentTemplates.isEmpty {
                Spacer(minLength: 0)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasUnsavedChanges)
        .animation(.easeInOut(duration: 0.2), value: canReset)
        .paywallGate(isPresented: $showPaywall, feature: .unlimitedTemplates)
    }

    /// 저장해 둔 설정 하나. 무료에서는 **잠긴 채로 보인다** — 없애면 잃어버린 것이 된다.
    private func templateChip(_ template: Timer) -> some View {
        Button {
            guard ProGate.canRememberSetup else {
                showPaywall = true
                return
            }
            withAnimation(.easeInOut(duration: 0.25)) {
                screenVM.load(template: template)
            }
        } label: {
            HStack(spacing: DSSpacing.xs) {
                if !ProGate.canRememberSetup {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                Text(displayName(template))
                    .font(DSFont.callout.weight(.medium))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "Applies this template to the timer"))
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

/// popoverTip 은 iOS 17+ 전용이라 가용성 가드를 한 곳에 모은다.
private struct SaveTemplateTipAnchor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.popoverTip(SaveTemplateTip(), arrowEdge: .bottom)
        } else {
            content
        }
    }
}
