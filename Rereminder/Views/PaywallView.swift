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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    if let receipt = PaywallReceipt.pick(
                        completions: Int(UsageMetrics.value(.timerCompletions)),
                        sessions: Int(UsageMetrics.value(.presentationRuns)),
                        focus: focusTier
                    ), !store.isPro {
                        receiptLine(receipt)
                    }
                    if let feature = triggeredBy {
                        triggerBanner(feature: feature)
                    }
                    if !store.isPro {
                        planCards
                    }
                    // 언제나 평생 패스. 이미 Pro 인 사람도 다른 앱까지 열고 싶을 수 있다.
                    LeeoForeverPassLine(pass: store.foreverPass, ownsLifetimePro: StoreManager.storedPurchaseFlag)
                    featureComparisonSection
                    purchaseSection
                    restoreSection
                    legalSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.05), Color(uiColor: .systemBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
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
        .onAppear {
            // 기억 평생을 산 사람은 Pro 평생(차액)으로 올리는 길이 먼저다.
            if store.ownsLifetimeRemember { proTerm = .lifetime }
        }
        .task {
            // ⚠️ 호출부가 한 곳도 없어 상품이 로드되지 않았다 — 가격(`proPrice`)이 빈 문자열로
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .dsScaledFont(56, relativeTo: .largeTitle, maxSize: 76)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 20)
                .accessibilityHidden(true)

            Text(AppName.pro)
                .dsScaledFont(32, weight: .bold, design: .rounded, relativeTo: .title, maxSize: 44)

            Text(headerSubtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 핵심 메시지 — 이미 Pro 인 사람에게는 파는 말을 하지 않는다(`ProBenefitsView` 의 "전체 보기"로 온다).
            if !store.isPro {
                purchasePromise
            }
        }
    }

    /// 이미 산 사람도 "무엇이 열려 있는지" 보러 온다(설정 ▸ 내 혜택 ▸ 전체 보기). 그 사람에게는 파는 말 대신
    /// 지금 자리를 말한다. 기억만 가진 사람에게는 여전히 Pro 를 고르는 화면이라 원래 문장을 둔다.
    private var headerSubtitle: LocalizedStringKey {
        store.isPro ? "All Pro features are unlocked" : "The app remembers your setups"
    }

    private var purchasePromise: some View {
            HStack(spacing: 8) {
                Image(systemName: "infinity")
                    .font(.headline)
                Text("Yearly or lifetime, your choice")
                    .font(.headline)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.1))
            )
    }

    // MARK: - 세 칸

    private var focusTier: ProTier { focus ?? triggeredBy?.tier ?? .session }

    /// 무료 · 기억(Plus) · Pro. 위 칸은 아래 칸을 전부 포함하므로 사다리 순서 그대로 둔다.
    /// 들어온 자리의 칸은 테두리로 앞에 세운다(기억 자리는 기억, 세션 자리는 Pro).
    private var planCards: some View {
        VStack(spacing: 12) {
            ForEach(ProTier.allCases, id: \.self) { tier in
                planCard(tier)
            }
            LeeoLifetimePriceNotice()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    @ViewBuilder
    private func planCard(_ tier: ProTier) -> some View {
        let owned = owns(tier)
        let highlighted = tier == focusTier && !owned

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(planName(tier))
                    .font(.headline)
                    .foregroundStyle(tier == .session ? Color.accentColor : .primary)
                if owned {
                    Text("Owned")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                }
                Spacer(minLength: 0)
            }
            Text(planSummary(tier))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if tier != .free, !owned {
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
                buyButton(tier, product: offer(tier, term.wrappedValue))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(highlighted ? Color.accentColor.opacity(0.08)
                                  : Color(uiColor: .secondarySystemBackground).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(highlighted ? Color.accentColor : Color(uiColor: .separator).opacity(0.3),
                              lineWidth: highlighted ? 2 : 1)
        )
    }

    private func planName(_ tier: ProTier) -> String {
        switch tier {
        case .free: return String(localized: "Free")
        case .plus: return String(localized: "Remember")
        case .session: return AppName.pro
        }
    }

    private func planSummary(_ tier: ProTier) -> String {
        switch tier {
        case .free: return String(localized: "Timer, unlimited pre-alerts, Live Activity, Apple Watch and widgets")
        case .plus: return String(localized: "Saved setups and your last timer")
        case .session: return String(localized: "Everything in Remember, plus Session Mode, scripts, overtime and history")
        }
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
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
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

    // MARK: - Trigger Banner

    private func triggerBanner(feature: ProGate.Feature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                // 기억 자리에서 "Pro 가 필요합니다"라고 하면 $2.99 카드와 말이 어긋난다.
                // 기능이 아니라 **앞에 세운 트림**으로 말한다 — 전날 안내는 기능은 기억이지만 Pro 를 앞에 세운다.
                Text(focusTier == .plus
                     ? String(localized: "Included in Remember")
                     : String(localized: "This feature requires Pro"))
                    .font(.subheadline.weight(.semibold))
                Text(LocalizedStringKey(feature.displayName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
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
                // ⚠️ 첫 두 줄이 이 페이월의 문장이다 — "당신 설정을 기억한다".
                //    기능 나열이 아니라 **무엇을 사는지**가 맨 위에 와야 한다.
                comparisonRow("Saved setups", free: false, remember: true, pro: true)
                comparisonRow("Remembers your last timer", free: false, remember: true, pro: true)
                Divider()
                comparisonRow("Timer", free: true, remember: true, pro: true)
                // 알림은 이제 양쪽 다 무제한이다 — 이 줄이 곧 이번 변경의 문장이다.
                comparisonRow("Pre-alerts", free: "∞", remember: "∞", pro: "∞")
                comparisonRow("Live Activity", free: true, remember: true, pro: true)
                comparisonRow("Watch / Widget", free: true, remember: true, pro: true)
                Divider()
                comparisonRow("Custom Messages", free: true, remember: true, pro: true)
                Divider()
                comparisonRow("Session Mode", free: false, remember: false, pro: true)
                comparisonRow("Section Scripts", free: false, remember: false, pro: true)
                comparisonRow("Overtime Tracking", free: false, remember: false, pro: true)
                comparisonRow("Timer History", free: false, remember: false, pro: true)
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
        case .sessions: return "person.and.background.dotted"
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
