//
//  PresentationTemplatesView.swift
//  Rereminder
//
//  Created by Claude on 2/28/26.
//

import SwiftUI

struct PresentationTemplatesView: View {
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Self.templates) { template in
                    Button {
                        screenVM.presentationSections = template.sections
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(template.name)
                                    .font(.headline)
                                Spacer()
                                Text(template.totalFormatted)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 4) {
                                ForEach(template.sections) { section in
                                    HStack(spacing: 2) {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.6))
                                            .frame(width: 6, height: 6)
                                        Text("\(section.name) \(section.formattedDuration)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if section.id != template.sections.last?.id {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 6))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Template Data

extension PresentationTemplatesView {
    struct Template: Identifiable {
        let id = UUID()
        let name: String
        let sections: [PresentationSection]

        var totalSeconds: Int {
            sections.reduce(0) { $0 + $1.durationSeconds }
        }

        var totalFormatted: String {
            let minutes = totalSeconds / 60
            if minutes >= 60 {
                let h = minutes / 60
                let m = minutes % 60
                return m > 0 ? "\(h)h \(m)m" : "\(h)h"
            }
            return "\(minutes)m"
        }
    }

    static let templates: [Template] = [
        Template(
            name: "5-min Pitch",
            sections: [
                PresentationSection(name: "Opening", durationSeconds: 60),
                PresentationSection(name: "Main Point", durationSeconds: 180),
                PresentationSection(name: "Closing", durationSeconds: 60),
            ]
        ),
        Template(
            name: "15-min Talk",
            sections: [
                PresentationSection(name: "Introduction", durationSeconds: 120),
                PresentationSection(name: "Main Content", durationSeconds: 480),
                PresentationSection(name: "Summary", durationSeconds: 180),
                PresentationSection(name: "Q&A", durationSeconds: 120),
            ]
        ),
        Template(
            name: "30-min Presentation",
            sections: [
                PresentationSection(name: "Introduction", durationSeconds: 180),
                PresentationSection(name: "Part 1", durationSeconds: 600),
                PresentationSection(name: "Part 2", durationSeconds: 600),
                PresentationSection(name: "Summary", durationSeconds: 180),
                PresentationSection(name: "Q&A", durationSeconds: 300),
            ]
        ),
        Template(
            name: "1-hour Workshop",
            sections: [
                PresentationSection(name: "Introduction", durationSeconds: 300),
                PresentationSection(name: "Theory", durationSeconds: 900),
                PresentationSection(name: "Hands-on", durationSeconds: 1200),
                PresentationSection(name: "Review", durationSeconds: 600),
                PresentationSection(name: "Q&A", durationSeconds: 600),
            ]
        ),
    ]
}
