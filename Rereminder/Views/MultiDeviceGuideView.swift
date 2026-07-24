//
//  MultiDeviceGuideView.swift
//  Rereminder
//
//  기기별 활용 안내 — iPhone, Apple Watch, 위젯/Live Activity, Siri, Mac에서
//  두번알림을 어떻게 쓸 수 있는지 한 화면에서 스크롤로 소개한다.
//

import SwiftUI

// MARK: - Data Model

/// 한 기기(플랫폼)에 대한 안내 카드
private struct DeviceGuide: Identifiable {
    let id = UUID()
    let symbol: String          // 헤더 SF Symbol
    let tint: Color             // 기기 강조색
    let titleKey: String        // 기기 이름
    let subtitleKey: String     // 한 줄 요약
    let features: [GuideFeature]
}

/// 기기 안에서 "무엇을 / 어떻게" 한 항목
private struct GuideFeature: Identifiable {
    let id = UUID()
    let symbol: String
    let titleKey: String        // 무엇을 할 수 있는지
    let descKey: String         // 어떻게 쓰는지
}

// MARK: - View

struct MultiDeviceGuideView: View {

    private let devices: [DeviceGuide] = [
        // iPhone
        DeviceGuide(
            symbol: "iphone",
            tint: .blue,
            titleKey: "guide_iphone_title",
            subtitleKey: "guide_iphone_subtitle",
            features: [
                GuideFeature(symbol: "bell.badge.fill",
                             titleKey: "guide_iphone_f1_title",
                             descKey: "guide_iphone_f1_desc"),
                GuideFeature(symbol: "square.grid.2x2.fill",
                             titleKey: "guide_iphone_f2_title",
                             descKey: "guide_iphone_f2_desc"),
                GuideFeature(symbol: "hand.tap.fill",
                             titleKey: "guide_iphone_f3_title",
                             descKey: "guide_iphone_f3_desc")
            ]
        ),
        // Apple Watch
        DeviceGuide(
            symbol: "applewatch",
            tint: .pink,
            titleKey: "guide_watch_title",
            subtitleKey: "guide_watch_subtitle",
            features: [
                GuideFeature(symbol: "digitalcrown.horizontal.press.fill",
                             titleKey: "guide_watch_f1_title",
                             descKey: "guide_watch_f1_desc"),
                GuideFeature(symbol: "arrow.triangle.2.circlepath",
                             titleKey: "guide_watch_f2_title",
                             descKey: "guide_watch_f2_desc"),
                GuideFeature(symbol: "hand.wave.fill",
                             titleKey: "guide_watch_f3_title",
                             descKey: "guide_watch_f3_desc")
            ]
        ),
        // 위젯 & Live Activity
        DeviceGuide(
            symbol: "rectangle.stack.fill",
            tint: .orange,
            titleKey: "guide_widget_title",
            subtitleKey: "guide_widget_subtitle",
            features: [
                GuideFeature(symbol: "square.grid.3x3.fill",
                             titleKey: "guide_widget_f1_title",
                             descKey: "guide_widget_f1_desc"),
                GuideFeature(symbol: "lock.fill",
                             titleKey: "guide_widget_f2_title",
                             descKey: "guide_widget_f2_desc"),
                GuideFeature(symbol: "capsule.portrait.fill",
                             titleKey: "guide_widget_f3_title",
                             descKey: "guide_widget_f3_desc")
            ]
        ),
        // Siri & 단축어
        DeviceGuide(
            symbol: "waveform",
            tint: .purple,
            titleKey: "guide_siri_title",
            subtitleKey: "guide_siri_subtitle",
            features: [
                GuideFeature(symbol: "mic.fill",
                             titleKey: "guide_siri_f1_title",
                             descKey: "guide_siri_f1_desc"),
                GuideFeature(symbol: "timer",
                             titleKey: "guide_siri_f2_title",
                             descKey: "guide_siri_f2_desc"),
                GuideFeature(symbol: "square.stack.3d.up.fill",
                             titleKey: "guide_siri_f3_title",
                             descKey: "guide_siri_f3_desc")
            ]
        ),
        // Mac
        DeviceGuide(
            symbol: "laptopcomputer",
            tint: .gray,
            titleKey: "guide_mac_title",
            subtitleKey: "guide_mac_subtitle",
            features: [
                GuideFeature(symbol: "menubar.rectangle",
                             titleKey: "guide_mac_f1_title",
                             descKey: "guide_mac_f1_desc"),
                GuideFeature(symbol: "icloud.fill",
                             titleKey: "guide_mac_f2_title",
                             descKey: "guide_mac_f2_desc"),
                GuideFeature(symbol: "arrow.down.circle.fill",
                             titleKey: "guide_mac_f3_title",
                             descKey: "guide_mac_f3_desc")
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxxl) {
                header

                ForEach(devices) { device in
                    deviceCard(device)
                }

                footerNote
            }
            .padding(.horizontal, DSSpacing.xl)
            .padding(.vertical, DSSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("guide_nav_title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Image(systemName: "square.stack.3d.up.fill")
                .dsScaledFont(40, weight: .semibold, relativeTo: .largeTitle, maxSize: 60)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            Text("guide_header_title")
                .dsScaledFont(26, weight: .bold, design: .rounded, relativeTo: .title, maxSize: 40)
                .foregroundStyle(.primary)

            Text("guide_header_subtitle")
                .font(DSFont.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Device Card

    private func deviceCard(_ device: DeviceGuide) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            // 기기 헤더
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DSRadius.md)
                        .fill(device.tint.opacity(DSOpacity.faint))
                        .frame(width: 52, height: 52)
                    Image(systemName: device.symbol)
                        .dsScaledFont(26, weight: .semibold, relativeTo: .title2, maxSize: 40)
                        .foregroundStyle(device.tint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(device.titleKey))
                        .font(DSFont.sectionHeader)
                        .foregroundStyle(.primary)
                    Text(LocalizedStringKey(device.subtitleKey))
                        .font(DSFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            // 기능 목록
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                ForEach(device.features) { feature in
                    featureRow(feature, tint: device.tint)
                }
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func featureRow(_ feature: GuideFeature, tint: Color) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: feature.symbol)
                .font(DSFont.callout)
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(feature.titleKey))
                    .font(DSFont.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(LocalizedStringKey(feature.descKey))
                    .font(DSFont.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Footer

    private var footerNote: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "icloud.fill")
                .font(DSFont.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("guide_footer_note")
                .font(DSFont.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(Color.accentColor.opacity(DSOpacity.faint))
        )
    }
}

#Preview {
    NavigationStack {
        MultiDeviceGuideView()
    }
}
