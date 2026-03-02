//
//  PresentationSetupView.swift
//  Rereminder
//
//  Created by Claude on 2/28/26.
//

import SwiftUI

struct PresentationSetupView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @State private var showTemplates = false

    var body: some View {
        VStack(spacing: 0) {
            // 총 시간 헤더
            totalTimeHeader
                .padding(.top, 8)

            // 섹션 리스트
            sectionList

            Spacer(minLength: 16)

            // 하단 버튼들
            bottomButtons
                .padding(.bottom, 8)
        }
    }

    // MARK: - Total Time Header

    private var totalTimeHeader: some View {
        let totalSeconds = screenVM.presentationSections.reduce(0) { $0 + $1.durationSeconds }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m")
                    .font(.title2.weight(.bold).monospacedDigit())
            }

            Spacer()

            Text("\(screenVM.presentationSections.count) sections")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Section List

    private var sectionList: some View {
        List {
            ForEach($screenVM.presentationSections) { $section in
                SectionRow(section: $section, onDelete: {
                    if let idx = screenVM.presentationSections.firstIndex(where: { $0.id == section.id }) {
                        screenVM.presentationSections.remove(at: idx)
                    }
                })
            }
            .onMove { from, to in
                screenVM.presentationSections.move(fromOffsets: from, toOffset: to)
            }

            // 섹션 추가 버튼
            Button {
                withAnimation {
                    screenVM.presentationSections.append(
                        PresentationSection(name: "Section \(screenVM.presentationSections.count + 1)", durationSeconds: 300)
                    )
                }
            } label: {
                Label("Add Section", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        VStack(spacing: 12) {
            // 템플릿 버튼
            Button {
                showTemplates = true
            } label: {
                Label("Templates", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            // 시작 버튼
            Button {
                screenVM.startPresentation()
            } label: {
                Label("Start Presentation", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(screenVM.presentationSections.isEmpty ? Color.gray : Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .disabled(screenVM.presentationSections.isEmpty)
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showTemplates) {
            PresentationTemplatesView()
                .environmentObject(screenVM)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Section Row

private struct SectionRow: View {
    @Binding var section: PresentationSection
    let onDelete: () -> Void

    @State private var minutesText: String = ""
    @State private var secondsText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 섹션 이름
            TextField("Section name", text: $section.name)
                .font(.body.weight(.medium))

            HStack(spacing: 12) {
                // 시간 입력
                HStack(spacing: 4) {
                    TextField("min", text: $minutesText)
                        .keyboardType(.numberPad)
                        .frame(width: 44)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: minutesText) { _, newValue in
                            updateDuration()
                            _ = newValue
                        }
                    Text("m")
                        .foregroundStyle(.secondary)

                    TextField("sec", text: $secondsText)
                        .keyboardType(.numberPad)
                        .frame(width: 36)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: secondsText) { _, newValue in
                            updateDuration()
                            _ = newValue
                        }
                    Text("s")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.monospacedDigit())

                Spacer()

                // 알림 토글
                Toggle(isOn: $section.alertAtEnd) {
                    Image(systemName: section.alertAtEnd ? "bell.fill" : "bell.slash")
                        .font(.caption)
                        .foregroundStyle(section.alertAtEnd ? Color.accentColor : Color.secondary)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)

                // 삭제 버튼
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            let minutes = section.durationSeconds / 60
            let seconds = section.durationSeconds % 60
            minutesText = "\(minutes)"
            secondsText = seconds > 0 ? "\(seconds)" : "0"
        }
    }

    private func updateDuration() {
        let minutes = Int(minutesText) ?? 0
        let seconds = Int(secondsText) ?? 0
        section.durationSeconds = max(0, minutes * 60 + seconds)
    }
}
