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

                messageSection(mainSeconds: mainSeconds)
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

    // MARK: - 울릴 때 뜰 말

    /// **알림을 켜는 그 자리에서 문구도 쓴다.** 설정 깊숙한 곳(설정 > 메시지)에만 두면
    /// 있는 줄도 모른다 — 문구가 필요하다고 느끼는 순간은 알림을 켤 때다.
    /// (설정 화면의 같은 기능은 그대로 두었다. 둘은 같은 값을 본다.)
    @ViewBuilder
    private func messageSection(mainSeconds: Int) -> some View {
        let firing = screenVM.selectedOffsets.filter { $0 > 0 && $0 < mainSeconds }.sorted(by: >)

        if !firing.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("What it says when it rings")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, DSSpacing.md)

                ForEach(firing, id: \.self) { sec in
                    HStack(spacing: DSSpacing.sm) {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(DSColor.marker)
                        Text(TimeMapper.mmss(sec))
                            .font(.callout.monospacedDigit().weight(.medium))
                            .frame(width: 52, alignment: .leading)
                        TextField(Self.defaultMessage(for: sec), text: messageBinding(sec))
                            .textFieldStyle(.plain)
                            .submitLabel(.done)
                            .accessibilityLabel(String(localized: "Pre-alert Message"))
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DSRadius.sm)
                            .fill(Color(.systemGray6))
                    )
                }

                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "flag.checkered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("End")
                        .font(.callout.weight(.medium))
                        .frame(width: 52, alignment: .leading)
                    TextField(String(localized: "Timer finished"), text: $screenVM.finishMessage)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .accessibilityLabel(String(localized: "End Alert Message"))
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DSRadius.sm)
                        .fill(Color(.systemGray6))
                )

                Text("Leave it empty to use the default.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func messageBinding(_ sec: Int) -> Binding<String> {
        Binding(
            get: { screenVM.prealertMessages[sec] ?? "" },
            set: { screenVM.prealertMessages[sec] = $0 }
        )
    }

    /// 아무것도 안 쓰면 실제로 뜰 말 — placeholder 로 보여줘야 "뭘 덮어쓰는 건지" 안다.
    /// ⚠️ `Timer.getPrealertMessage` 와 **같은 문구**를 써야 한다(다르면 안내가 거짓말이 된다).
    private static func defaultMessage(for sec: Int) -> String {
        sec < 60
            ? String(localized: "\(sec) sec remaining")
            : String(localized: "\(sec / 60) min remaining")
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

        return Toggle(
            isOn: Binding(
                get: { isSelected },
                set: { on in
                    if on {
                        // 정책(1번째 free, 그 다음부터 체험 평가)은 ProGate 가 단독으로 안다
                        switch ProGate.requestPrealert(currentCount: screenVM.selectedOffsets.count) {
                        case .allowed:
                            screenVM.selectedOffsets.insert(sec)
                        case .grace:
                            // 막힌 자리에서 문을 닫지 않는다 — 원하던 걸 손에 쥔 채로 다음 문장을 듣는다
                            screenVM.selectedOffsets.insert(sec)
                            screenVM.showToast?(String(localized: "Turned this one on for you. Pro keeps them unlimited."))
                        case .blocked(let stage):
                            paywallFeature = .unlimitedPrealerts
                            paywallStage = stage
                            pendingPrealertSec = sec
                            showPaywall = true
                            return
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
                if !isSelected && !StoreManager.isProUser && !isDisabled
                    && ProGate.prealertAdmission(currentCount: screenVM.selectedOffsets.count) != .allowed {
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
