//
//  HomeLightSettingsView.swift
//  Rereminder
//
//  설정 > 알림 > 조명으로 알리기. 판정·제어는 `Modules/HomeLightAlert.swift`.
//  ⚠️ 권한은 토글을 켜는 순간 묻고, 거부당하면 토글을 되돌린다 — 켜져 있는데 안 바뀌는 것이 가장 나쁜 상태다.
//

import SwiftUI

struct HomeLightSettingsView: View {
    @AppStorage(HomeLightSettings.enabledKey) private var isEnabled = false
    @AppStorage(HomeLightSettings.modeKey) private var mode: HomeLightMode = .flash
    @ObservedObject private var controller = HomeLightController.shared
    @State private var selected = HomeLightSettings.selectedIDs

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Alert with lights"), isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, on in
                        if on { controller.activate() }
                    }
                Text("When an alert rings, your lights change to the color of the section that starts. At the end, they turn red.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if isEnabled {
                switch controller.status {
                case .idle, .loading:
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Looking for lights…")
                        }
                    }
                case .denied:
                    Section {
                        Text("Allow Rereminder to access Home data in Settings to use this.")
                            .font(.body)
                        Button(String(localized: "Open Settings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                case .ready:
                    readySections
                }
            }
        }
        .navigationTitle(String(localized: "Alert with lights"))
        .onAppear {
            if isEnabled { controller.activate() }
        }
        .onChange(of: controller.status) { _, status in
            if status == .denied { isEnabled = false }
        }
    }

    @ViewBuilder
    private var readySections: some View {
        Section {
            Picker(String(localized: "Color stays"), selection: $mode) {
                ForEach(HomeLightMode.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        }

        Section(String(localized: "Lights")) {
            if controller.lights.isEmpty {
                Text("No lights found. Add lights in the Home app first.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            ForEach(controller.lights) { light in
                Button {
                    toggle(light)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(light.name)
                                .foregroundStyle(.primary)
                            if !light.supportsColor {
                                Text("No color. It will blink instead.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            } else if let room = light.room {
                                Text(room)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selected.contains(light.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }

        Section {
            Button {
                controller.test()
            } label: {
                Label(String(localized: "Try it"), systemImage: "lightbulb.max")
            }
            .disabled(selected.isEmpty)
            Text("Lights change only while Rereminder is open on screen. The timer keeps the screen on while it runs.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func toggle(_ light: HomeLightController.Light) {
        if selected.contains(light.id) {
            selected.remove(light.id)
        } else {
            selected.insert(light.id)
        }
        HomeLightSettings.selectedIDs = selected
    }
}
