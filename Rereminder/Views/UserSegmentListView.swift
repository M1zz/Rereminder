//
//  UserSegmentListView.swift
//  Rereminder
//
//  개발자(마스터 모드) 전용 — 설치(=사용자)를 **결제까지의 거리**로 나눠 한 명씩 본다.
//
//  통계 화면의 합계는 "몇 명"까지만 말해 준다. 여기서는 그 몇 명이 각각 어떤 사람인지를 본다:
//  알림을 몇 개까지 켰고, 몇 번 막혔고, 체험이 얼마나 남았고, 마지막으로 언제 썼는지.
//  구분 규칙과 근접도 점수는 전부 `UsageInsights`에 있다 — 여기서 다시 계산하지 않는다.
//
//  ⚠️ 익명 설치 UUID 앞 8자리만 보여준다. 사람을 특정할 수 있는 값은 애초에 수집하지 않는다.
//  ⚠️ 개발자 전용이라 문구는 한국어 그대로 두되 `Text(verbatim:)`으로 쓴다 —
//     문자열 카탈로그에 추출되면 다국어 검사(predeploy)가 막힌다.
//

import SwiftUI

struct UserSegmentListView: View {
    let profiles: [UsageInsights.UserProfile]
    /// 어느 구분으로 들어왔는지 — 눌러서 온 칸이 먼저 선택돼 있어야 헤맬 일이 없다.
    let initialStage: UsageInsights.PaymentStage?

    /// nil = 전체.
    @State private var selectedStage: UsageInsights.PaymentStage?

    init(profiles: [UsageInsights.UserProfile], initialStage: UsageInsights.PaymentStage? = nil) {
        self.profiles = profiles
        self.initialStage = initialStage
        _selectedStage = State(initialValue: initialStage)
    }

    /// 결제에 가까운 순서(근접도)로 정렬 — 먼저 봐야 할 사람이 위에 온다.
    private var visible: [UsageInsights.UserProfile] {
        guard let selectedStage else { return profiles }
        return profiles.filter { $0.stage == selectedStage }
    }

    /// 실제로 사람이 있는 구분만 고르게 한다(빈 칸을 골라 놓고 "왜 아무도 없지" 하지 않게).
    private var availableStages: [UsageInsights.PaymentStage] {
        UsageInsights.PaymentStage.allCases.filter { stage in
            profiles.contains { $0.stage == stage }
        }
    }

    var body: some View {
        List {
            filterSection
            if let selectedStage {
                Section {
                    Text(verbatim: selectedStage.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                if visible.isEmpty {
                    Text(verbatim: "이 구분에 해당하는 설치가 없어요.").foregroundStyle(.secondary)
                } else {
                    ForEach(visible) { profile in row(profile) }
                }
            } header: {
                Text(verbatim: "\(visible.count)명")
            } footer: {
                Text(verbatim: "익명 설치 ID 앞 8자리예요. 재설치하면 다른 사람으로 잡히고, 이 값으로 사람을 특정할 수는 없어요. 근접도는 명단을 세우는 순서값이지 결제 확률이 아니에요.")
            }
        }
        .navigationTitle(Text(verbatim: "사용자 구분"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 필터

    private var filterSection: some View {
        Section {
            Picker(selection: $selectedStage) {
                Text(verbatim: "전체 (\(profiles.count))").tag(UsageInsights.PaymentStage?.none)
                ForEach(availableStages) { stage in
                    Text(verbatim: "\(stage.label) (\(profiles.filter { $0.stage == stage }.count))")
                        .tag(UsageInsights.PaymentStage?.some(stage))
                }
            } label: {
                Text(verbatim: "구분")
            }
        }
    }

    // MARK: - 한 사람

    private func row(_ profile: UsageInsights.UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: profile.shortID)
                    .font(.body.monospaced().weight(.semibold))
                Spacer()
                Text(verbatim: profile.stage.label)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(color(for: profile.stage).opacity(0.18)))
                    .foregroundStyle(color(for: profile.stage))
            }

            // 결제 판단에 직접 쓰이는 값만 — 알림 수요, 막힌 횟수, 남은 체험.
            Text(verbatim: demandLine(profile))
                .font(.caption)
                .foregroundStyle(.secondary)

            // 이 사람이 앱을 실제로 쓰는 사람인지 — 안 쓰는 사람에게 파는 건 계산이 아니다.
            Text(verbatim: usageLine(profile))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text(verbatim: "근접도 \(profile.readiness)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.quaternary)
                        Capsule().fill(color(for: profile.stage))
                            .frame(width: max(2, geo.size.width * Double(profile.readiness) / 100))
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private func demandLine(_ profile: UsageInsights.UserProfile) -> String {
        var parts: [String] = []
        parts.append(profile.alertsMax > 0 ? "알림 최대 \(profile.alertsMax)개" : "알림 기록 없음")
        if profile.multiAlertRuns > 0 { parts.append("2개 이상 실행 \(profile.multiAlertRuns)회") }
        if profile.limitHits > 0 { parts.append("막힘 \(profile.limitHits)회") }
        if profile.isPro {
            parts.append("결제함")
        } else if profile.trialUsed > 0 || profile.limitHits > 0 {
            parts.append("체험 \(profile.trialUsed)회 사용 · 남은 \(profile.trialRemaining)회")
        }
        if profile.paywallViews > 0 { parts.append("페이월 \(profile.paywallViews)회") }
        return parts.joined(separator: " · ")
    }

    private func usageLine(_ profile: UsageInsights.UserProfile) -> String {
        var parts: [String] = ["완주 \(profile.completions)회", "시작 \(profile.starts)회"]
        if profile.focusMinutes > 0 { parts.append("관리 \(profile.focusMinutes)분") }
        switch profile.daysSinceActive {
        case .some(0):          parts.append("오늘 활동")
        case .some(let days):   parts.append("\(days)일 전 활동")
        case .none:             parts.append("활동 기록 없음")
        }
        parts.append("\(profile.platform) \(profile.appVersion)")
        return parts.joined(separator: " · ")
    }

    /// 구분마다 색을 달리해 명단을 훑을 때 눈으로 먼저 갈리게 한다
    /// (결제에 가까울수록 뜨거운 색).
    private func color(for stage: UsageInsights.PaymentStage) -> Color {
        switch stage {
        case .pro:       return .green
        case .blocked:   return .red
        case .nearLimit: return .orange
        case .trialing:  return .yellow
        case .demand:    return .accentColor
        case .freeFit:   return .secondary
        case .dormant:   return .secondary
        }
    }
}
