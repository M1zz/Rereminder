//
//  PaywallView.swift
//  Rereminder
//
//  요금제 Paywall UI (2026-10 개편: 무료 · 기억(Plus) · Pro 세 칸)
//  - 칸마다 연 구독 / 평생 고르기(`LeeoTermPicker`)와 그 칸의 구매 버튼
//  - 세 칸 아래 언제나 평생 패스 한 줄(`LeeoForeverPassLine`), 평생 가격 인상 안내(`LeeoLifetimePriceNotice`)
//  - 기능 비교 테이블
//  - 제한 도달 시 자연스럽게 노출
//
//  ⚠️ **들어온 순간에 맞는 칸을 앞에 세운다**(`ProTier`, 2.3.3). 기억 자리(다시 연 순간·반복 감지·
//     잠긴 템플릿)에서는 기억 칸이, 세션 자리(세션 모드·기록·전날 안내)에서는 Pro 칸이 테두리로 선다.
//     칸 순서는 사다리 그대로(무료 · 기억 · Pro) 두고, 고르는 건 사용자다.
//  ⚠️ 상품이 로드되지 않으면 그 길의 버튼은 눌리지 않는다. 다른 상품을 대신 사게 하지 않는다.
//  ⚠️ 맨 위에는 기능 목록보다 **이 사람이 해 온 것**을 먼저 적는다(`PaywallReceipt`).
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreManager.shared

    /// Paywall을 열게 된 기능 (nil이면 일반 업그레이드)
    var triggeredBy: ProGate.Feature?

    /// 페이월 단계 (5+5 모델)
    var stage: ProGate.PaywallStage = .second

    /// "5번 더 체험" 수락 시 호출 (stage == .first 일 때만 노출)
    var onAcceptExtension: (() -> Void)?

    /// 앞에 세울 트림. nil 이면 들어온 기능이 여는 트림, 그것도 없으면 Pro.
    /// 기능은 기억인데 사람은 세션 사용자인 자리(전날 안내)가 이걸 넘긴다.
    var focus: ProTier?

    @State private var didPurchaseDuringSession = false
    /// 칸마다 고른 길. 처음 보는 사람은 연 구독(첫 해 할인)이 먼저 보인다.
    @State private var plusTerm: LeeoPlanTerm = .yearly
    @State private var proTerm: LeeoPlanTerm = .yearly
    /// 이 화면에서 마지막으로 결제를 시작한 상품. 기억을 산 직후를 알아보는 데 쓴다.
    @State private var lastPurchase: StoreManager.ProductID?
    /// App Store 의 코드 사용 시트(오퍼 코드·인앱결제 프로모션 코드).
    @State private var showRedeemCode = false

    /// 설정 줄에서 **화면으로 넘어와** 열렸다 — 내비게이션 · 닫기 단추는 바깥 것을 쓴다(클립키보드와 같다).
    var embedded = false

    /// 고른 칸. 처음에는 들어온 자리의 칸(기억 자리는 기억, 세션 자리는 Pro). 이미 가진 칸은 고를 수 없다.
    @State private var chosenTier: ProTier?

    var body: some View {
        Group {
            if embedded {
                // 아래 떠 있는 구매 단추를 탭 막대가 가리지 않게
                page.toolbar(.hidden, for: .tabBar)
            } else {
                NavigationStack {
                    page
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { dismiss() } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.title3)
                                }
                                .accessibilityLabel(String(localized: "Close"))
                            }
                        }
                }
            }
        }
        .onAppear {
            // 기억 평생을 산 사람은 Pro 평생(차액)으로 올리는 길이 먼저다.
            if store.ownsLifetimeRemember { proTerm = .lifetime }
        }
        .task {
            // ⚠️ 호출부가 한 곳도 없어 상품이 로드되지 않았다 — 가격이 빈 문자열로
            //    뜨는 페이월은 "얼마인지 모르고 누르라"는 화면이다.
            //    권한도 함께 확인한다: 페이월을 여는 순간이 "이미 샀는데 왜 또"를 잡을 마지막 기회다.
            await store.loadProducts()
            await store.verifyCurrentEntitlements()
        }
        .onAppear {
            AnalyticsManager.log(.paywallShown(trigger: triggeredBy))
        }
        .onDisappear {
            AnalyticsManager.log(.paywallDismissed(
                trigger: triggeredBy,
                didPurchase: didPurchaseDuringSession
            ))
        }
        .onChange(of: store.purchaseState) { _, newValue in
            if newValue == .purchased {
                didPurchaseDuringSession = true
                // ⚠️ 기억을 산 직후에는 `canRemember` 가 참이 되어 같은 화면이 곧바로 Pro 를 권하는 화면으로
                //    바뀐다. 방금 돈을 낸 사람에게 또 권하는 화면이 된다. 완료 표시를 잠깐 보이고 닫는다.
                if let lastPurchase, lastPurchase.tier == .plus {
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        dismiss()
                    }
                }
            }
        }
    }

    private var page: some View {
            // 그림으로 파는 틀(LeeoKit `LeeoShowcasePaywall`, 골드위크 · 클립키보드와 같다):
            // 기억 | Pro → 기능 그림(옆으로 넘김) → 연 구독 · 평생 → 늘 떠 있는 구매 단추.
            // 머리말(왕관 · 앱 이름 · 미사여구)은 두지 않는다. 지금까지 한 것 · 비교표 · 복원 · 약관은 스크롤한 아래에.
            LeeoShowcasePaywall(showcases: showcases) {
                if purchasableTiers.count > 1 { tierSwitch }
            } plans: {
                plans
            } button: {
                if !store.isPro, let tier = selectedTier {
                    buyButton(tier, product: offer(tier, termBinding(tier).wrappedValue))
                }
            } details: {
                VStack(spacing: 24) {
                    purchaseSection
                    if let receipt = PaywallReceipt.pick(
                        completions: Int(UsageMetrics.value(.timerCompletions)),
                        sessions: Int(UsageMetrics.value(.presentationRuns)),
                        focus: focusTier
                    ), !store.isPro {
                        receiptLine(receipt)
                    }
                    // 언제나 평생 패스. 이미 Pro 인 사람도 다른 앱까지 열고 싶을 수 있다.
                    LeeoForeverPassLine(pass: store.foreverPass, ownsLifetimePro: StoreManager.storedPurchaseFlag)
                    // 다 가진 사람이 더 내고 싶을 때 갈 곳(응원). 팁 상품이 와 있을 때만(클립키보드와 같다).
                    if store.isPro, let tipJar = store.tipJar, tipJar.isAvailable {
                        NavigationLink {
                            LeeoTipJarView<RereminderSpec>(tipJar: tipJar)
                        } label: {
                            Label(LeeoTipText.entry, systemImage: "heart.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    restoreSection
                    legalSection
                    // 사는 사람에게는 접어 둔다 — 고를 것은 위에 다 있다. 이미 가진 사람은 무엇이 열렸는지 보러 왔으니 편다.
                    if store.isPro {
                        featureComparisonSection
                    } else {
                        DisclosureGroup {
                            featureComparisonSection.padding(.top, 12)
                        } label: {
                            Text("Compare Plans")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .tint(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 칸

    private var focusTier: ProTier { focus ?? triggeredBy?.tier ?? .session }

    /// 살 수 있는 칸(기억 · Pro). 이미 가진 칸은 빠진다.
    private var purchasableTiers: [ProTier] { [.plus, .session].filter { !owns($0) } }

    /// 지금 보고 있는 칸. 고른 것이 없으면 들어온 자리의 칸, 그것도 살 수 없으면 살 수 있는 첫 칸.
    private var selectedTier: ProTier? {
        if let chosenTier, purchasableTiers.contains(chosenTier) { return chosenTier }
        if purchasableTiers.contains(focusTier) { return focusTier }
        return purchasableTiers.first
    }

    private func owns(_ tier: ProTier) -> Bool {
        switch tier {
        case .free: return false
        case .plus: return store.canRemember
        case .session: return store.isPro
        }
    }

    private func termBinding(_ tier: ProTier) -> Binding<LeeoPlanTerm> {
        tier == .plus ? $plusTerm : $proTerm
    }

    /// 이 칸에서 고른 길(연 구독 · 평생)에 실제로 결제할 상품.
    /// 기억 평생을 이미 산 사람에게 Pro 평생은 올리기(차액) 상품이다.
    private func offer(_ tier: ProTier, _ term: LeeoPlanTerm) -> StoreManager.ProductID {
        switch (tier, term) {
        case (.plus, .yearly): return .plusYearly
        case (.plus, .lifetime): return .remember
        case (_, .yearly): return .proYearly
        case (_, .lifetime): return store.proLifetimeOffer
        }
    }

    private func planName(_ tier: ProTier) -> String {
        switch tier {
        case .free: return String(localized: "Free")
        case .plus: return String(localized: "Remember")
        case .session: return AppName.pro
        }
    }

    /// 기억 | Pro. 고른 칸의 그림과 요금이 아래에 선다.
    private var tierSwitch: some View {
        HStack(spacing: 4) {
            ForEach(purchasableTiers, id: \.self) { tier in
                let selected = tier == selectedTier
                Button {
                    withAnimation(.snappy(duration: 0.25)) { chosenTier = tier }
                } label: {
                    Text(planName(tier))
                        .font(.body.weight(.bold))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if selected {
                                Capsule().fill(Color(uiColor: .systemBackground))
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
    }

    /// 고른 칸의 연 구독 · 평생. 이미 Pro 면 파는 말 대신 지금 자리를 말한다.
    @ViewBuilder
    private var plans: some View {
        if store.isPro {
            Text("All Pro features are unlocked")
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else if let tier = selectedTier {
            VStack(alignment: .leading, spacing: 12) {
                let term = termBinding(tier)
                let lifetime = offer(tier, .lifetime)
                LeeoTermPicker(term: term,
                               yearly: store.product(offer(tier, .yearly)),
                               lifetime: store.product(lifetime))
                if tier == .session, term.wrappedValue == .lifetime, lifetime == .proUpgrade {
                    Text("You already have Remember, so you pay only the difference.")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LeeoLifetimePriceNotice()
            }
        }
    }

    // MARK: - 그림 장

    /// 넘겨 볼 장 — 고른 칸에서 열리는 것만. 들어온 기능이 있으면 그 장이 맨 앞. 이미 Pro 면 전부.
    private var showcases: [LeeoShowcase] {
        let remember = [
            LeeoShowcase(id: ProGate.Feature.unlimitedTemplates.rawValue, title: String(localized: "Saved setups"),
                         detail: String(localized: "Keep every timer setup you use, ready in one tap")) { SetupsArt() },
            LeeoShowcase(id: ProGate.Feature.timerHistory.rawValue, title: String(localized: "Timer History"),
                         detail: String(localized: "See all your past timers and stats, with no time limit")) { HistoryArt() },
        ]
        let pro = [
            LeeoShowcase(id: ProGate.Feature.presentationMode.rawValue, title: String(localized: "Session Mode"),
                         detail: String(localized: "Run a talk or class section by section, each with its own time")) { SessionArt() },
            LeeoShowcase(id: "scripts", title: String(localized: "Section Scripts"),
                         detail: String(localized: "Keep the notes for each section on screen as you go")) { ScriptsArt() },
        ]
        var pages: [LeeoShowcase]
        switch selectedTier {
        case .plus: pages = remember
        case .session: pages = pro
        default: pages = remember + pro
        }
        if let lead = triggeredBy?.rawValue, let i = pages.firstIndex(where: { $0.id == lead }) {
            pages.insert(pages.remove(at: i), at: 0)
        }
        return pages
    }

    private func buyButton(_ tier: ProTier, product: StoreManager.ProductID) -> some View {
        let title = tier == .plus ? String(localized: "Get Remember") : String(localized: "Upgrade to Pro")
        let buying = store.purchaseState == .purchasing && lastPurchase == product
        return Button {
            lastPurchase = product
            Task { await store.purchase(product) }
        } label: {
            Group {
                if buying {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(store.purchaseState == .purchasing || store.product(product) == nil)
        .accessibilityLabel(title)
        .accessibilityValue(store.price(of: product) ?? "")
    }

    // MARK: - 지금까지 한 것

    private func receiptLine(_ receipt: PaywallReceipt) -> some View {
        HStack(spacing: 8) {
            Image(systemName: receipt.icon)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(receipt.text)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.08)))
    }

    // MARK: - Feature Comparison

    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare Plans")
                .font(.title3.weight(.bold))

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Feature")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Free")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: columnWidth)
                    Text("Remember")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: columnWidth)
                    Text("Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: columnWidth)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))

                Divider()

                // Rows
                // ⚠️ 맨 위 줄이 이 페이월의 문장이다 — **무엇을 사는지**가 먼저 와야 한다.
                comparisonRow("Saved setups", free: String(ProGate.freeSavedSetups), remember: "∞", pro: "∞")
                comparisonRow("Timer History", free: String(FreeUse.recentHistoryDays), remember: "∞", pro: "∞")
                Divider()
                comparisonRow("Remembers your last timer", free: true, remember: true, pro: true)
                comparisonRow("Timer", free: true, remember: true, pro: true)
                // 알림은 이제 양쪽 다 무제한이다 — 이 줄이 곧 이번 변경의 문장이다.
                comparisonRow("Pre-alerts", free: "∞", remember: "∞", pro: "∞")
                comparisonRow("Overtime Tracking", free: true, remember: true, pro: true)
                comparisonRow("Live Activity", free: true, remember: true, pro: true)
                comparisonRow("Watch / Widget", free: true, remember: true, pro: true)
                Divider()
                comparisonRow("Custom Messages", free: true, remember: true, pro: true)
                Divider()
                comparisonRow("Session Mode", free: false, remember: false, pro: true)
                comparisonRow("Section Scripts", free: false, remember: false, pro: true)
            }
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// 칸이 셋이라 좁힌다. 기능 이름 칸이 먼저 숨을 쉬어야 한다.
    private let columnWidth: CGFloat = 56

    private func comparisonRow(_ feature: String, free: Any, remember: Any, pro: Any) -> some View {
        HStack {
            // ⚠️ `Text(String)` 은 번역하지 않는다 — 한국어 화면에 "Saved setups" 가 그대로 나갔다.
            Text(LocalizedStringKey(feature))
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            comparisonCell(free)
                .frame(width: columnWidth)
            comparisonCell(remember)
                .frame(width: columnWidth)
            comparisonCell(pro)
                .frame(width: columnWidth)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: String.LocalizationValue(feature))): \(String(localized: "Free")) \(accessibilityValue(free)), \(String(localized: "Remember")) \(accessibilityValue(remember)), \(String(localized: "Pro")) \(accessibilityValue(pro))")
    }

    private func accessibilityValue(_ value: Any) -> String {
        if let bool = value as? Bool {
            return bool ? String(localized: "available") : String(localized: "not available")
        } else if let text = value as? String {
            return text
        }
        return ""
    }

    @ViewBuilder
    private func comparisonCell(_ value: Any) -> some View {
        if let bool = value as? Bool {
            Image(systemName: bool ? "checkmark.circle.fill" : "minus.circle")
                .foregroundStyle(bool ? .green : .secondary.opacity(0.5))
        } else if let text = value as? String {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(text == "∞" ? Color.accentColor : .primary)
        }
    }

    // MARK: - Purchase Button

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            if store.isPro {
                // 이미 Pro
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("You're already a Pro member!")
                            .font(.headline)
                    }
                    // 값을 먼저 치른 사람은 여기서도 그 사실이 보여야 한다.
                    if FoundingSupporter.isFounder {
                        FounderBadge()
                        Text("Every future Pro feature is included for you.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 16)

            } else {
                // 1차 페이월 — "5번 더 체험" 옵션
                if stage == .first,
                   let feature = triggeredBy,
                   feature.supportsTrial {
                    Button {
                        AnalyticsManager.log(.paywallOneMoreClicked(trigger: feature))
                        ProGate.acceptExtendedTrial(feature)
                        onAcceptExtension?()
                        dismiss()
                    } label: {
                        Text("Try 5 more times")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(Color.accentColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel(String(localized: "Try 5 more times"))
                }

                // 에러 메시지
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // 성공 메시지
                if store.purchaseState == .purchased || store.purchaseState == .restored {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(store.purchaseState == .purchased ? "Purchase successful!" : "Restored successfully!")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Restore

    private var restoreSection: some View {
        HStack(spacing: 24) {
            Button {
                Task { await store.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            // 할인·선물로 받은 코드를 앱 안에서 바로 쓴다. App Store 앱을 거쳐 돌아오는 길은
            // 돌아온 뒤 권한을 다시 읽어야 풀리는데(CLAUDE.md "전경 복귀마다"), 여기서는 시트가 닫히는 즉시 읽는다.
            if !store.isPro {
                Button {
                    showRedeemCode = true
                } label: {
                    Text("Redeem Code")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
            Task { await store.verifyCurrentEntitlements() }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("Lifetime is a one-time purchase. Yearly plans renew automatically unless you cancel at least 24 hours before the renewal date. Manage them in your App Store account settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://m1zz.github.io/Rereminder/privacy.html")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Paywall Trigger Modifier

/// 사용법: .paywallGate(isPresented: $showPaywall, feature: .presentationMode)
struct PaywallGateModifier: ViewModifier {
    @Binding var isPresented: Bool
    var feature: ProGate.Feature?
    var stage: ProGate.PaywallStage = .second
    var onAcceptExtension: (() -> Void)?
    var focus: ProTier?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PaywallView(
                    triggeredBy: feature,
                    stage: stage,
                    onAcceptExtension: onAcceptExtension,
                    focus: focus
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func paywallGate(
        isPresented: Binding<Bool>,
        feature: ProGate.Feature? = nil,
        stage: ProGate.PaywallStage = .second,
        onAcceptExtension: (() -> Void)? = nil,
        focus: ProTier? = nil
    ) -> some View {
        modifier(PaywallGateModifier(
            isPresented: isPresented,
            feature: feature,
            stage: stage,
            onAcceptExtension: onAcceptExtension,
            focus: focus
        ))
    }
}

// MARK: - 지금까지 한 것

/// 페이월 맨 위의 한 줄 — 기능 목록보다 먼저 **이 사람이 이 앱으로 해 온 것**을 말한다.
/// 체험이 끝나 막힌 순간에도 "막혔다"보다 "이만큼 썼다"가 먼저 읽히게 하려는 것이다.
///
/// ⚠️ 숫자가 작으면 띄우지 않는다 — "타이머 1번을 마쳤어요"는 영수증이 아니라 놀림이다.
///    그래서 복수형 처리도 필요 없다(늘 2 이상).
enum PaywallReceipt: Equatable {
    case sessions(Int)
    case timers(Int)

    static let minSessions = 2
    static let minTimers = 3

    /// 판정 (순수 함수 — 테스트 대상). Pro 자리에서는 세션 기록이 먼저다.
    static func pick(completions: Int, sessions: Int, focus: ProTier) -> PaywallReceipt? {
        if focus == .session, sessions >= minSessions { return .sessions(sessions) }
        if completions >= minTimers { return .timers(completions) }
        return nil
    }

    var icon: String {
        switch self {
        case .sessions: return "text.rectangle.page"
        case .timers: return "checkmark.circle.fill"
        }
    }

    var text: String {
        switch self {
        case .sessions(let n): return String(localized: "You've run \(n) sessions so far.")
        case .timers(let n): return String(localized: "You've finished \(n) timers so far.")
        }
    }
}

// MARK: - Pro Badge (재사용 컴포넌트)

/// Pro 뱃지 — 잠금 표시 등에 활용
struct ProBadge: View {
    var small: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(small ? .caption2 : .caption)
            Text("PRO")
                .font(small ? .caption2.weight(.bold) : .caption.weight(.bold))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, small ? 6 : 8)
        .padding(.vertical, small ? 2 : 4)
        .background(
            Capsule().fill(Color.orange.opacity(0.15))
        )
    }
}

#Preview("Paywall") {
    PaywallView(triggeredBy: .presentationMode)
}

#Preview("Pro Badge") {
    ProBadge()
}

// MARK: - 그림 장 (LeeoKit `LeeoShowcase`)
//
// 그 기능이 적용된 화면을 SwiftUI 로 줄여 그린다. 스크린샷이 아니라 언어 · 다크 모드를 따라가고 용량이 들지 않는다.
// ⚠️ 그림 속 글자는 숫자 · 기호만. 문장은 그림 아래 한 줄이 맡는다.

private struct ArtCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(12)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

/// 저장한 설정: 시간과 미리 알림이 담긴 줄들
private struct SetupsArt: View {
    private let rows: [(String, [String])] = [("25:00", ["5:00", "1:00"]), ("10:00", ["2:00"]), ("45:00", ["10:00", "5:00", "1:00"])]
    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { i in
                ArtCard {
                    HStack(spacing: 10) {
                        Image(systemName: "bookmark.fill").foregroundStyle(Color.accentColor)
                        Text(verbatim: rows[i].0).font(.headline.monospacedDigit())
                        Spacer()
                        ForEach(rows[i].1, id: \.self) { alert in
                            Label { Text(verbatim: alert) } icon: { Image(systemName: "bell.fill") }
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color.orange.opacity(0.14), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

/// 기록: 한 주의 막대와 끝낸 타이머 수
private struct HistoryArt: View {
    private let bars: [CGFloat] = [0.4, 0.7, 0.55, 0.9, 0.6, 1, 0.35]
    var body: some View {
        ArtCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill").foregroundStyle(Color.accentColor)
                    Spacer()
                    Label { Text(verbatim: "42") } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        .font(.headline.monospacedDigit())
                }
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(bars.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(i == 5 ? 1 : 0.4))
                            .frame(width: 20, height: 100 * bars[i])
                    }
                }
                .frame(height: 100, alignment: .bottom)
            }
        }
        .padding(16)
    }
}

/// 세션 모드: 구간마다 나뉜 막대와 지금 구간의 남은 시간
private struct SessionArt: View {
    private let parts: [CGFloat] = [0.2, 0.35, 0.3, 0.15]
    var body: some View {
        VStack(spacing: 16) {
            Text(verbatim: "04:12")
                .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
            GeometryReader { g in
                HStack(spacing: 4) {
                    ForEach(parts.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(i < 1 ? Color.secondary.opacity(0.3) : i == 1 ? Color.accentColor : Color.accentColor.opacity(0.25))
                            .frame(width: (g.size.width - 12) * parts[i])
                            .overlay {
                                Text(verbatim: "\(i + 1)").font(.caption.weight(.bold))
                                    .foregroundStyle(i == 1 ? .white : .secondary)
                            }
                    }
                }
            }
            .frame(height: 30)
        }
        .padding(20)
    }
}

/// 구간 대본: 지금 구간의 할 말이 시간 아래에
private struct ScriptsArt: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(verbatim: "2/4").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Color.accentColor, in: Capsule())
                Spacer()
                Text(verbatim: "02:30").font(.title2.weight(.bold).monospacedDigit())
            }
            ArtCard {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "text.alignleft").foregroundStyle(Color.accentColor)
                    ForEach([0.9, 0.75, 0.85, 0.5], id: \.self) { w in
                        Capsule().fill(Color.secondary.opacity(0.35)).frame(height: 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: w, anchor: .leading)
                    }
                }
            }
        }
        .padding(16)
    }
}
