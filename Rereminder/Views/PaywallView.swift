//
//  PaywallView.swift
//  Rereminder
//
//  Pro 구매 Paywall UI
//  - 기능 비교 테이블
//  - "한번 구매, 평생 사용" 강조
//  - 제한 도달 시 자연스럽게 노출
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = StoreManager.shared

    /// Paywall을 열게 된 기능 (nil이면 일반 업그레이드)
    var triggeredBy: ProGate.Feature?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    if let feature = triggeredBy {
                        triggerBanner(feature: feature)
                    }
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
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 20)

            Text(AppName.pro)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text("Unlock all features")
                .font(.title3)
                .foregroundStyle(.secondary)

            // 핵심 메시지
            HStack(spacing: 8) {
                Image(systemName: "infinity")
                    .font(.headline)
                Text("Pay once, use forever")
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
    }

    // MARK: - Trigger Banner

    private func triggerBanner(feature: ProGate.Feature) -> some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("This feature requires Pro")
                    .font(.subheadline.weight(.semibold))
                Text(feature.displayName)
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
                        .frame(width: 60)
                    Text("Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 60)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemBackground))

                Divider()

                // Rows
                comparisonRow("Timer", free: true, pro: true)
                comparisonRow("Pre-alerts", free: true, pro: true)
                comparisonRow("Live Activity", free: true, pro: true)
                comparisonRow("Apple Watch", free: true, pro: true)
                Divider()
                comparisonRow("Templates", free: "3", pro: "∞")
                comparisonRow("Custom Messages", free: false, pro: true)
                comparisonRow("Label Colors", free: "1", pro: "8")
                comparisonRow("Timer History", free: false, pro: true)
            }
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func comparisonRow(_ feature: String, free: Any, pro: Any) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            comparisonCell(free)
                .frame(width: 60)
            comparisonCell(pro)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("You're already a Pro member!")
                        .font(.headline)
                }
                .padding(.vertical, 16)

            } else {
                Button {
                    Task { await store.purchase() }
                } label: {
                    VStack(spacing: 6) {
                        if store.purchaseState == .purchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Upgrade to Pro")
                                .font(.headline)
                            if !store.proPrice.isEmpty {
                                Text("\(store.proPrice) · One-time purchase")
                                    .font(.caption)
                                    .opacity(0.9)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                }
                .disabled(store.purchaseState == .purchasing)

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
        Button {
            Task { await store.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 8) {
            Text("One-time purchase. No subscription fees.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Paywall Trigger Modifier

/// 사용법: .paywallGate(isPresented: $showPaywall, feature: .customPrealertMessage)
struct PaywallGateModifier: ViewModifier {
    @Binding var isPresented: Bool
    var feature: ProGate.Feature?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PaywallView(triggeredBy: feature)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func paywallGate(isPresented: Binding<Bool>, feature: ProGate.Feature? = nil) -> some View {
        modifier(PaywallGateModifier(isPresented: isPresented, feature: feature))
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
    PaywallView(triggeredBy: .customPrealertMessage)
}

#Preview("Pro Badge") {
    ProBadge()
}
