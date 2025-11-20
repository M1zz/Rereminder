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
    private var templates: [Timer]

    @State private var editingTimer: Timer?
    @State private var editName: String = ""

    let onSelect: (Timer) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "저장된 템플릿이 없습니다",
                        systemImage: "clock.badge.questionmark",
                        description: Text("타이머를 시작하면 자동으로 템플릿이 저장됩니다")
                    )
                    .padding(.top, 40)
                } else {
                    List {
                        ForEach(templates) { t in
                            Button {
                                onSelect(t)
                                dismiss()
                            } label: {
                                let mMain = t.mainSeconds / 60
                                let sMain = t.mainSeconds % 60

                                let preList = t.prealertOffsetsSec
                                    .sorted()
                                    .map { sec -> String in
                                        let m = sec / 60
                                        return "\(m)분"
                                    }
                                    .joined(separator: ", ")

                                if preList.isEmpty {
                                    Text("메인 \(mMain)분 \(sMain)초, 예비: 없음")
                                } else {
                                    Text(
                                        "메인 \(mMain)분 \(sMain)초, 예비: \(preList)"
                                    )
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingTimer = t
                                    editName = t.name
                                } label: {
                                    Label("편집", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: true
                            ) {
                                Button(role: .destructive) {
                                    delete(t)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("타이머 템플릿")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $editingTimer) { timer in
            NavigationView {
                Form {
                    TextField("템플릿 이름", text: $editName)
                }
                .navigationTitle("템플릿 편집")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") {
                            editingTimer = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            timer.name = editName
                            try? context.save()
                            editingTimer = nil
                        }
                    }
                }
            }
        }
    }

    private func delete(_ t: Timer) {
        withAnimation {
            context.delete(t)
            try? context.save()
        }
    }
}
