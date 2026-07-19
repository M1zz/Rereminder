//
//  PrealertSettingsView.swift
//  Rereminder
//
//  예비 알림(Pre-alerts) 설정 — 메인 화면에서 분리한 시트
//

import SwiftUI

struct PrealertSettingsView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @ObservedObject private var store = PresetStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var paywallFeature: ProGate.Feature?
    @State private var paywallStage: ProGate.PaywallStage = .second
    @State private var pendingPrealertSec: Int?
    @State private var showAddOffset = false

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pre-alerts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .paywallGate(
            isPresented: $showPaywall,
            feature: paywallFeature,
            stage: paywallStage,
            onAcceptExtension: applyPendingPrealert
        )
    }

    @ViewBuilder
    private var content: some View {
        let mainSeconds = screenVM.mainMinutes * 60 + screenVM.mainSeconds
        let presets = store.prealertSeconds
        let prealertGate = ProGate.evaluate(.unlimitedPrealerts)

        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Get a heads-up before the timer ends.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !StoreManager.isProUser {
                        if let remaining = prealertGate.trialRemaining,
                           screenVM.selectedOffsets.count >= ProGate.freePrealertLimit {
                            Text("Trial \(remaining) left")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                        } else {
                            Text("\(screenVM.selectedOffsets.count)/\(ProGate.freePrealertLimit)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(presets, id: \.self) { sec in
                        prealertToggle(sec: sec, mainSeconds: mainSeconds)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.removePrealert(seconds: sec)
                                    screenVM.selectedOffsets.remove(sec)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }

                    addButton
                }

                Text("Touch and hold a pre-alert to remove it.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
        .sheet(isPresented: $showAddOffset) {
            TimePresetEditorSheet(
                title: "Add Pre-alert",
                showSeconds: true,
                initialSeconds: 60
            ) { sec in
                store.addPrealert(seconds: sec)
            }
            .presentationDetents([.height(340)])
        }
    }

    private var addButton: some View {
        Button {
            showAddOffset = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("Add")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .tint(Color.accentColor)
        .accessibilityLabel(String(localized: "Add a custom pre-alert"))
    }

    private func applyPendingPrealert() {
        if let sec = pendingPrealertSec {
            screenVM.selectedOffsets.insert(sec)
            screenVM.showPrealertToast(for: sec, isEnabled: true)
            pendingPrealertSec = nil
        }
    }

    private func prealertToggle(sec: Int, mainSeconds: Int) -> some View {
        let isDisabled = sec >= mainSeconds
        let isSelected = screenVM.selectedOffsets.contains(sec)
        let prealertGate = ProGate.evaluate(.unlimitedPrealerts)

        return Toggle(
            isOn: Binding(
                get: { isSelected },
                set: { on in
                    if on {
                        // 1번째는 항상 free, 2번째부터 5+5 trial 평가
                        if screenVM.selectedOffsets.count >= ProGate.freePrealertLimit {
                            switch ProGate.evaluate(.unlimitedPrealerts) {
                            case .allowed, .allowedWithTrial:
                                screenVM.selectedOffsets.insert(sec)
                            case .blocked(let stage):
                                paywallFeature = .unlimitedPrealerts
                                paywallStage = stage
                                pendingPrealertSec = sec
                                showPaywall = true
                                AnalyticsManager.log(.premiumTrialExhausted(
                                    feature: .unlimitedPrealerts,
                                    stage: stage
                                ))
                                return
                            }
                        } else {
                            screenVM.selectedOffsets.insert(sec)
                        }
                    } else {
                        screenVM.selectedOffsets.remove(sec)
                    }
                    screenVM.showPrealertToast(for: sec, isEnabled: on)
                }
            )
        ) {
            HStack(spacing: 4) {
                Text(sec < 60 ? String(localized: "\(sec) sec") : String(localized: "\(sec/60) min"))
                    .dsScaledFont(14, weight: .medium, relativeTo: .callout, maxSize: 20)

                // 제한 초과 프리셋에 잠금 아이콘 (trial 도 소진된 경우)
                if !isSelected && !StoreManager.isProUser
                    && screenVM.selectedOffsets.count >= ProGate.freePrealertLimit
                    && !prealertGate.isAllowed
                    && !isDisabled {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .disabled(isDisabled)
    }
}
