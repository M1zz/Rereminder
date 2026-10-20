//
//  ProBenefitsView.swift
//  Rereminder
//
//  설정 ▸ (Pro 활성화 / 기억) 행을 누르면 열리는 **내 혜택** 화면.
//
//  ⚠️ 산 사람에게 "활성화됨" 한 줄은 영수증일 뿐이다. 알고 싶은 것은 **무엇이 열려 있고, 그걸
//     얼마나 쓰고 있는가**다. 그래서 무료였다면 어디까지였는지 옆에 지금 내 숫자를 세우고,
//     넘어선 만큼을 따로 짚는다.
//
//  ⚠️ 한도는 게이트(`ProGate`)와 **같은 셈법·같은 상수**를 쓴다.
//     - 저장한 설정: 무료 몫은 없다(`ProGate.freeSavedSetups` = 0, 저장 자체가 기억 트림).
//       첫 실행에 심어 준 시드(`LegacyFreeNotice.seedTemplateNames`)는 세지 않는다 —
//       세면 무료로도 가졌을 것을 산 덕으로 부풀리게 된다.
//     - 세션 모드: 무료 체험은 최대 `TrialCounter.secondStageLimit` 번(5+5).
//  ⚠️ 기능 목록 전체는 여기 따로 적지 않는다 — "전체 보기"는 페이월 비교표를 그대로 연다.
//     기억 트림의 "Pro 에서 더 열리는 것"도 `ProGate.Feature` 에서 뽑는다(두 곳에 적으면 한쪽만 고쳐진다).
//

import SwiftUI
import SwiftData

struct ProBenefitsView: View {
    @ObservedObject private var store = StoreManager.shared
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var usage = Usage()
    /// 페이월 비교표를 그대로 본다(산 트림은 구매 단추 대신 "활성화됨" / "보유").
    @State private var showAllFeatures = false
    /// 기억 → Pro 차액 업그레이드. 기존 페이월 흐름을 그대로 탄다.
    @State private var showUpgrade = false

    private var tier: ProTier { store.isPro ? .session : (store.canRemember ? .plus : .free) }

    var body: some View {
        List {
            heroSection
            limitsSection
            unlockedSection
            if tier == .plus {
                moreWithProSection
            }
            allFeaturesSection
        }
        .navigationTitle(Text("My Benefits"))
        .navigationBarTitleDisplayMode(.inline)
        // 들어올 때 한 번 센다 — 그릴 때마다 저장소를 읽지 않도록.
        .onAppear { usage = Usage.load(context: context) }
        .paywallGate(isPresented: $showAllFeatures)
        .paywallGate(isPresented: $showUpgrade, feature: .presentationMode, focus: .session)
    }

    // MARK: - 세는 것

    struct Usage: Equatable {
        /// 사용자가 직접 저장한 설정(시드 제외).
        var savedSetups = 0
        /// 세션 모드로 돌린 횟수(`UsageMetrics.presentationRuns`).
        var sessions = 0
        /// 대본을 적어 둔 구간 수.
        var scripts = 0
        /// 남은 타이머 기록 수.
        var records = 0

        static func load(context: ModelContext) -> Usage {
            let templates = (try? context.fetch(FetchDescriptor<Timer>())) ?? []
            var u = Usage()
            u.savedSetups = ownSetupCount(names: templates.map(\.name))
            u.scripts = templates.reduce(0) { sum, t in
                sum + t.sections.filter { !$0.script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            }
            u.sessions = Int(UsageMetrics.value(.presentationRuns))
            u.records = (try? context.fetchCount(FetchDescriptor<TimerRecord>())) ?? 0
            return u
        }

        /// 직접 저장한 설정 수 — 시드는 뺀다(순수 함수, 테스트 대상).
        static func ownSetupCount(names: [String]) -> Int {
            names.filter { !LegacyFreeNotice.seedTemplateNames.contains($0) }.count
        }
    }

    /// 무료에 한도가 있는 것 하나.
    struct LimitRow: Identifiable, Equatable {
        let id: String
        let title: LocalizedStringKey
        let symbol: String
        let freeLimit: Int
        let used: Int
        /// 무료 한도를 넘어 쓰고 있는 만큼 — 사지 않았다면 못 가졌을 것.
        var extra: Int { max(0, used - freeLimit) }

        static func == (a: LimitRow, b: LimitRow) -> Bool {
            a.id == b.id && a.freeLimit == b.freeLimit && a.used == b.used
        }
    }

    /// 이 트림으로 열린 한도들. 기억은 저장한 설정만, Pro 는 세션 모드까지.
    static func limitRows(tier: ProTier, usage: Usage) -> [LimitRow] {
        var rows: [LimitRow] = []
        if tier >= .plus {
            rows.append(LimitRow(id: "setups", title: "Saved setups", symbol: "bookmark.fill",
                                 freeLimit: ProGate.freeSavedSetups, used: usage.savedSetups))
        }
        if tier >= .session {
            rows.append(LimitRow(id: "sessions", title: "Session Mode", symbol: "person.and.background.dotted",
                                 freeLimit: TrialCounter.secondStageLimit, used: usage.sessions))
        }
        return rows
    }

    private var limitRows: [LimitRow] { Self.limitRows(tier: tier, usage: usage) }
    private var totalExtra: Int { limitRows.reduce(0) { $0 + $1.extra } }

    // MARK: - 섹션

    /// 한 줄 요약. 넘어선 만큼이 있으면 그 숫자부터 말한다.
    private var heroSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: tier == .session ? "checkmark.seal.fill" : "bookmark.fill")
                    .font(.largeTitle)
                    .foregroundStyle(tier == .session ? Color.green : Color.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tier == .session ? AppName.pro : String(localized: "Remember"))
                            .font(.headline)
                        if FoundingSupporter.isFounder {
                            FounderBadge()
                        }
                    }
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private var summary: String {
        if totalExtra > 0 {
            return String(localized: "You're using \(totalExtra) more than Free allows")
        }
        return tier == .session
            ? String(localized: "All Pro features are unlocked")
            : String(localized: "Your setups are remembered")
    }

    @ViewBuilder
    private var limitsSection: some View {
        if !limitRows.isEmpty {
            Section {
                ForEach(limitRows) { row in
                    limitRowView(row)
                }
            } header: {
                Text("Compared with Free")
            }
        }
    }

    private func limitRowView(_ row: LimitRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbol)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                Text(row.freeLimit == 0
                     ? String(localized: "Not in Free · You have \(row.used)")
                     : String(localized: "Free up to \(row.freeLimit) · You have \(row.used)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            // 넘어선 만큼만 따로 짚는다. 한도 안이면 아무것도 붙이지 않는다 — 0 을 달면 손해 본 것처럼 읽힌다.
            if row.extra > 0 {
                Text(verbatim: "+\(row.extra.formatted(.number))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// 켜지고 꺼지는 것·쌓이는 것. 쓰고 있는 모습을 값으로 보여 준다.
    private var unlockedSection: some View {
        Section {
            valueRow("Remembers your last timer", symbol: "arrow.counterclockwise",
                     value: String(localized: "On"))
            if tier == .session {
                valueRow("Section Scripts", symbol: "text.quote",
                         value: usage.scripts.formatted(.number))
                valueRow("Overtime Tracking", symbol: "timer.circle.fill",
                         value: String(localized: "On"))
                valueRow("Timer History", symbol: "chart.bar.fill",
                         value: usage.records.formatted(.number))
            }
        } header: {
            Text(tier == .session ? "Unlocked with Pro" : "Unlocked with Remember")
        }
    }

    /// 기억을 산 사람에게 — 위 트림에서 더 열리는 것을 차분히 한 칸. 목록은 게이트에서 뽑는다.
    private var moreWithProSection: some View {
        Section {
            ForEach(ProGate.Feature.allCases.filter { $0.tier == .session }, id: \.self) { feature in
                Label {
                    Text(LocalizedStringKey(feature.displayName))
                } icon: {
                    Image(systemName: feature.icon)
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                showUpgrade = true
            } label: {
                HStack {
                    Text("Upgrade to Pro")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        } header: {
            Text("More with Pro")
        } footer: {
            Text("You already have Remember — pay only the difference.")
        }
    }

    private var allFeaturesSection: some View {
        Section {
            Button {
                showAllFeatures = true
            } label: {
                HStack {
                    Label {
                        Text("See all features")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// 큰 글씨(접근성 크기)에서는 이름과 값을 위아래로 — 옆으로 두면 값이 잘린다.
    @ViewBuilder
    private func valueRow(_ title: LocalizedStringKey, symbol: String, value: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(Color.accentColor)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
