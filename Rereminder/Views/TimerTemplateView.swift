//
//  TimerTemplateView.swift
//  Rereminder
//
//  Created by POS on 8/26/25.
//

import Foundation
import SwiftData
import SwiftUI

struct TimerTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    /// 투명도 줄이기 — 아래 안내 줄의 반투명 바탕을 불투명하게 바꾼다(뒤 목록 글자가 비치지 않게).
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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

    /// ⚠️ 관찰이 목적 — `ProGate` 는 static 이라 Pro 상태 변화로 다시 그려지지 않는다.
    @ObservedObject private var store = StoreManager.shared

    private var canRememberSetup: Bool { store.canRemember || ProGate.canRememberSetup }

    @ObservedObject var screenVM: TimerScreenViewModel
    let onSelect: (Timer) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No saved templates",
                        systemImage: "clock.badge.questionmark",
                        // 새로 설치한 사람은 저절로 저장되지 않는다(`BlankStart`)
                        description: BlankStart.isNewInstall ? nil : Text("Templates are automatically saved when you start a timer")
                    )
                    .padding(.top, 40)
                    if hasUnsavedChanges || !screenVM.isAtDefaultSetup {
                        List {
                            saveSection
                            resetSection
                        }
                    }
                } else {
                    List {
                        saveSection
                        Section {
                            ForEach(templates) { t in
                                templateRow(for: t)
                            }
                        }
                        resetSection
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Saved setups")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if !canRememberSetup {
                    Button {
                        paywallFeature = .unlimitedTemplates
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            ProBadge(small: true)
                            Text("Let the app remember your setups")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding(14)
                        .background {
                            if reduceTransparency {
                                Color(uiColor: .secondarySystemBackground)
                            } else {
                                Rectangle().fill(.ultraThinMaterial)
                            }
                        }
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

    private var canSave: Bool {
        store.canRemember || ProGate.canSaveTemplate(
            currentCount: allTemplates.filter { !Timer.seedTemplateNames.contains($0.name) }.count)
    }

    /// 지금 다이얼과 같은 저장본이 없다.
    /// ⚠️ 기본 설정이라고 저장을 숨기지 말 것 — 10분 그대로를 저장해 위젯에서 시작하고 싶은 사람에게 길이 없었다.
    private var hasUnsavedChanges: Bool {
        let cfg = screenVM.normalizedCurrentConfig
        guard cfg.mainSec > 0 else { return false }
        let finish: String? = screenVM.finishMessage.isEmpty ? nil : screenVM.finishMessage
        return !allTemplates.contains {
            $0.mainSeconds == cfg.mainSec
                && $0.prealertOffsetsSec == cfg.offsets
                && $0.prealertMessages == screenVM.prealertMessages
                && $0.finishMessage == finish
        }
    }

    @ViewBuilder
    private var saveSection: some View {
        if hasUnsavedChanges {
            Section {
                Button {
                    guard canSave else {
                        paywallFeature = .unlimitedTemplates
                        showPaywall = true
                        return
                    }
                    screenVM.saveCurrentAsTemplate()
                    // 한 번 저장해 본 사람에게는 더 권하지 않는다
                    FeatureTips.markTemplateSaved()
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Label(String(localized: "Save"), systemImage: "bookmark.fill")
                            .font(.body.weight(.semibold))
                        Text(detailText(mainSeconds: screenVM.normalizedCurrentConfig.mainSec,
                                        offsets: screenVM.normalizedCurrentConfig.offsets))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .accessibilityLabel(String(localized: "Save the current settings as a template"))
                .accessibilityInputLabels([Text("Save")])
            }
        }
    }

    @ViewBuilder
    private var resetSection: some View {
        if !screenVM.isAtDefaultSetup {
            Section {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { screenVM.resetToDefaultSetup() }
                    dismiss()
                } label: {
                    Text("Reset the timer to the default setup")
                        .font(.body)
                }
            }
        }
    }

    private func detailText(mainSeconds: Int, offsets: [Int]) -> String {
        ([TimeMapper.durationText(mainSeconds)] + offsets.sorted().map(AlertPresets.label)).joined(separator: " · ")
    }

    @ViewBuilder
    private func templateRow(for timer: Timer) -> some View {
        Button {
            AnalyticsManager.log(.presetUsed(name: timer.name))
            onSelect(timer)
            dismiss()
        } label: {
            HStack(spacing: DSSpacing.md) {
                // 어떤 타이머인지 이름보다 먼저 모양으로 보인다
                OnboardingDemoRing(totalSeconds: max(1, timer.mainSeconds),
                                   alerts: timer.prealertOffsetsSec.filter { $0 < timer.mainSeconds },
                                   elapsed: 0, size: 52, showsTime: false)
                    .padding(DSSpacing.xxs)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    // 1행: 템플릿 이름이 주인공, 라벨은 색 칩으로 보조
                    HStack(spacing: DSSpacing.sm) {
                        Text(timer.displayName)
                            .font(DSFont.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            // 직접 붙인 긴 이름은 끝을 줄이고, 살짝 넘치면 간격을 좁혀 끝까지 보인다.
                            .truncationMode(.tail)
                            .allowsTightening(true)

                        if !timer.label.isEmpty {
                            Text(timer.displayLabel)
                                .font(DSFont.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, DSSpacing.sm)
                                .padding(.vertical, DSSpacing.xxs + 1)
                                .background(Color(hex: timer.colorHex).opacity(0.2))
                                .foregroundStyle(Color(hex: timer.colorHex))
                                .cornerRadius(DSRadius.sm)
                        }
                    }

                    // 2행: 시간과 알림을 다이얼 줄과 같은 말로
                    Text(detailText(mainSeconds: timer.mainSeconds, offsets: timer.prealertOffsetsSec))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                // 즐겨찾기 아이콘
                Button {
                    toggleFavorite(timer)
                } label: {
                    Image(systemName: timer.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(timer.isFavorite ? .yellow : .gray)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(timer.isFavorite ? String(localized: "Remove from favorites") : String(localized: "Add to favorites"))
            }
            .padding(.vertical, DSSpacing.xs)
        }
        // 목록 안 버튼은 기본이 파란 글자다. 저장한 설정이 전부 링크처럼 읽히지 않게 한다.
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "Applies this template to the timer"))
        .contextMenu {
            Button {
                startEdit(timer)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                toggleFavorite(timer)
            } label: {
                Label(
                    timer.isFavorite
                        ? String(localized: "Remove from favorites")
                        : String(localized: "Add to favorites"),
                    systemImage: timer.isFavorite ? "star.slash" : "star"
                )
            }
            Button(role: .destructive) {
                delete(timer)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                startEdit(timer)
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

    private func startEdit(_ timer: Timer) {
        editingTimer = timer
        editName = timer.displayName
        editLabel = timer.label
        editColorHex = timer.colorHex
    }

    /// M:SS 표기 (앱 전체 표기 통일)
    private func mmssText(_ sec: Int) -> String { TimeMapper.mmss(sec) }

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
                            .fill(Color(hex: editColorHex))
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
                        // 고치지 않았으면 저장값을 두어야 언어를 바꿔도 다시 번역된다.
                        if editName != timer.displayName { timer.name = editName }
                        timer.label = editLabel
                        timer.colorHex = editColorHex
                        do {
                            try context.save()
                        } catch {
                            print("❌ 템플릿 편집 저장 실패: \(error)")
                        }
                        editingTimer = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func colorButton(label: String, colorHex: String) -> some View {
        Button {
            // 색만 선택 — 라벨 텍스트는 사용자가 입력한 값 유지
            editColorHex = colorHex
        } label: {
            VStack(spacing: DSSpacing.xs) {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .strokeBorder(editColorHex == colorHex ? Color.primary : Color.clear, lineWidth: 2)
                    )

                Text(label)
                    .font(DSFont.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "\(label) color"))
        .accessibilityAddTraits(editColorHex == colorHex ? [.isSelected] : [])
    }

    private func toggleFavorite(_ timer: Timer) {
        withAnimation {
            timer.isFavorite.toggle()
            do {
                try context.save()
            } catch {
                print("❌ 즐겨찾기 저장 실패: \(error)")
            }
        }
    }

    private func delete(_ timer: Timer) {
        withAnimation {
            context.delete(timer)
            do {
                try context.save()
            } catch {
                print("❌ 템플릿 삭제 실패: \(error)")
            }
        }
    }

}
