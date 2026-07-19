//
//  TimePresetEditorSheet.swift
//  Rereminder
//
//  빠른설정 / 예비알림 프리셋 값을 편집하는 휠 피커 시트
//

import SwiftUI

struct TimePresetEditorSheet: View {
    let title: LocalizedStringKey
    let showSeconds: Bool
    let onSave: (Int) -> Void   // 저장 시 총 초(seconds)를 전달

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var seconds: Int

    init(
        title: LocalizedStringKey,
        showSeconds: Bool,
        initialSeconds: Int,
        onSave: @escaping (Int) -> Void
    ) {
        self.title = title
        self.showSeconds = showSeconds
        self.onSave = onSave
        _minutes = State(initialValue: initialSeconds / 60)
        _seconds = State(initialValue: initialSeconds % 60)
    }

    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: DSSpacing.lg) {
                    wheel(title: "min", selection: $minutes, range: 0..<121)

                    if showSeconds {
                        Text(":")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        wheel(title: "sec", selection: $seconds, range: 0..<60)
                    }
                }
                .padding(.top, DSSpacing.lg)

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let total = showSeconds ? (minutes * 60 + seconds) : (minutes * 60)
                        // 빠른설정은 최소 1분, 예비알림은 최소 5초
                        onSave(max(showSeconds ? 5 : 60, total))
                        dismiss()
                    }
                }
            }
        }
    }

    private func wheel(title: LocalizedStringKey, selection: Binding<Int>, range: Range<Int>) -> some View {
        VStack {
            Text(title)
                .font(DSFont.callout)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100)
        }
    }
}
