//
//  ThemeSettingView.swift
//  Rereminder
//
//  키 컬러 테마 프리셋 선택 화면
//

import SwiftUI

struct ThemeSettingView: View {
    @ObservedObject private var theme = ThemeManager.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)

    var body: some View {
        Form {
            Section {
                Text("Choose your accent color for the entire app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Theme")) {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(ThemeManager.Theme.presets) { preset in
                        themeButton(preset)
                    }
                }
                .padding(.vertical, 12)
            }

            Section {
                // 미리보기
                VStack(spacing: 16) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        // 버튼 미리보기
                        Button("Start") {}
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accentColor)

                        Button("Pause") {}
                            .buttonStyle(.bordered)
                            .tint(theme.accentColor)

                        Spacer()

                        // 원형 프로그레스 미리보기
                        ZStack {
                            Circle()
                                .stroke(theme.accentColor.opacity(0.2), lineWidth: 4)
                                .frame(width: 44, height: 44)
                            Circle()
                                .trim(from: 0, to: 0.7)
                                .stroke(theme.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(-90))
                            Text("70%")
                                .font(.caption2.weight(.medium))
                        }
                    }

                    // 토글 미리보기
                    Toggle("Pre-alert", isOn: .constant(true))
                        .tint(theme.accentColor)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func themeButton(_ preset: ThemeManager.Theme) -> some View {
        let isSelected = theme.currentTheme.id == preset.id

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                theme.select(preset)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(preset.color)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 3)
                        )
                        .shadow(color: isSelected ? preset.color.opacity(0.5) : .clear, radius: 6)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(preset.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(String(localized: "Tap to select theme"))
    }
}

#Preview {
    NavigationStack {
        ThemeSettingView()
    }
}
