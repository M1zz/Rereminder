//
//  TimerTemplateView.swift
//  Toki
//
//  Created by POS on 8/26/25.
//

import Foundation
import SwiftData
import SwiftUI

struct TimerTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Timer.createdAt, order: .reverse)])
    private var allTemplates: [Timer]

    // 즐겨찾기 먼저, 그 Next 최근 사용 순으로 정렬
    private var templates: [Timer] {
        allTemplates.sorted { t1, t2 in
            // 즐겨찾기가 우선
            if t1.isFavorite != t2.isFavorite {
                return t1.isFavorite
            }
            // 최근 사용 시간이 있으면 그것으로 정렬
            if let d1 = t1.lastUsedAt, let d2 = t2.lastUsedAt {
                return d1 > d2
            }
            // 한쪽만 사용 기록이 있으면 그쪽 우선
            if t1.lastUsedAt != nil { return true }
            if t2.lastUsedAt != nil { return false }
            // 둘 다 없으면 생성일로 정렬
            return t1.createdAt > t2.createdAt
        }
    }

    @State private var editingTimer: Timer?
    @State private var editName: String = ""
    @State private var editLabel: String = ""
    @State private var editColorHex: String = "#007AFF"
    @State private var showPaywall = false
    @State private var paywallFeature: ProGate.Feature? = .unlimitedTemplates

    let onSelect: (Timer) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No saved templates",
                        systemImage: "clock.badge.questionmark",
                        description: Text("Templates are automatically saved when you start a timer")
                    )
                    .padding(.top, 40)
                } else {
                    List {
                        ForEach(templates) { t in
                            templateRow(for: t)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Timer Templates")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !StoreManager.isProUser && templates.count >= ProGate.freeTemplateLimit {
                    Button {
                        paywallFeature = .unlimitedTemplates
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            ProBadge(small: true)
                            Text("Unlock unlimited templates")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .paywallGate(isPresented: $showPaywall, feature: paywallFeature)
        }
        .sheet(item: $editingTimer) { timer in
            editSheet(for: timer)
        }
    }

    @ViewBuilder
    private func templateRow(for timer: Timer) -> some View {
        Button {
            onSelect(timer)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // 즐겨찾기 아이콘
                Button {
                    toggleFavorite(timer)
                } label: {
                    Image(systemName: timer.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(timer.isFavorite ? .yellow : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        // Label 태그
                        if !timer.label.isEmpty {
                            Text(timer.label)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(colorFromHex(timer.colorHex).opacity(0.2))
                                .foregroundStyle(colorFromHex(timer.colorHex))
                                .cornerRadius(6)
                        }

                        // 사용 횟수
                        if timer.usageCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "play.circle.fill")
                                    .font(.caption2)
                                Text("\(timer.usageCount)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Timer Info
                    let mMain = timer.mainSeconds / 60
                    let sMain = timer.mainSeconds % 60
                    let preList = timer.prealertOffsetsSec
                        .sorted()
                        .map { "\($0/60) \(String(localized: "min"))" }
                        .joined(separator: ", ")

                    Text(sMain > 0 ? "Main \(mMain) min \(sMain) sec" : "Main \(mMain) min")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if !preList.isEmpty {
                        Text("Pre-alert: \(preList)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                editingTimer = timer
                editName = timer.name
                editLabel = timer.label
                editColorHex = timer.colorHex
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete(timer)
            } label: {
                Image(systemName: "trash")
            }
        }
    }

    @ViewBuilder
    private func editSheet(for timer: Timer) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Name")) {
                    TextField("Template Name", text: $editName)
                }

                Section(header: Text("Label")) {
                    TextField("e.g., Presentation, Mentoring, Meeting", text: $editLabel)

                    Text("Labels help you easily distinguish timers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text("Label Color")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(Timer.presetColors.keys.sorted()), id: \.self) { label in
                                if let colorHex = Timer.presetColors[label] {
                                    colorButton(label: label, colorHex: colorHex)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    HStack {
                        Text("Selected Color:")
                        Circle()
                            .fill(colorFromHex(editColorHex))
                            .frame(width: 24, height: 24)
                        Text(editColorHex)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingTimer = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        timer.name = editName
                        timer.label = editLabel
                        timer.colorHex = editColorHex
                        try? context.save()
                        editingTimer = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func colorButton(label: String, colorHex: String) -> some View {
        let isDefault = colorHex == "#007AFF"
        let isLocked = !isDefault && !ProGate.canUseColor(colorHex)

        Button {
            if isLocked {
                paywallFeature = .labelColors
                showPaywall = true
            } else {
                editLabel = label
                editColorHex = colorHex
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(colorFromHex(colorHex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(editColorHex == colorHex ? Color.primary : Color.clear, lineWidth: 2)
                        )
                        .opacity(isLocked ? 0.4 : 1.0)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isLocked ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleFavorite(_ timer: Timer) {
        withAnimation {
            timer.isFavorite.toggle()
            try? context.save()
        }
    }

    private func delete(_ timer: Timer) {
        withAnimation {
            context.delete(timer)
            try? context.save()
        }
    }

    private func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 122, 255) // 기본 파란색
        }
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
