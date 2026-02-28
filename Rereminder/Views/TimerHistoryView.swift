//
//  TimerHistoryView.swift
//  Rereminder
//
//  타이머 사용 기록 & 통계 (Pro 기능)
//

import SwiftUI
import SwiftData

struct TimerHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\TimerRecord.date, order: .reverse)])
    private var records: [TimerRecord]

    @State private var showPaywall = false
    @State private var displayLimit = 50

    private var isPro: Bool { StoreManager.isProUser }

    var body: some View {
        NavigationStack {
            Group {
                if !isPro {
                    lockedView
                } else if records.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No timer history"),
                        systemImage: "clock.badge.questionmark",
                        description: Text("History will appear after you use timers", comment: "History empty state")
                    )
                } else {
                    List {
                        statsSection
                        recordsSection
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(String(localized: "Timer History"))
            .navigationBarTitleDisplayMode(.inline)
            .paywallGate(isPresented: $showPaywall, feature: .timerHistory)
        }
    }

    // MARK: - Locked View (무료)

    private var lockedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor.opacity(0.6))

            VStack(spacing: 8) {
                Text("Timer History & Stats", comment: "History locked title")
                    .font(.title2.weight(.bold))
                Text("Track your timer usage patterns\nand improve your time management", comment: "History locked description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 미리보기 (블러 처리)
            VStack(spacing: 12) {
                previewStatRow(String(localized: "Total Sessions"), value: "\(records.count)")
                previewStatRow(String(localized: "Completed"), value: "\(records.filter(\.finished).count)")
                previewStatRow(String(localized: "Total Time"), value: formatTotalTime())
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .blur(radius: 4)
            .overlay(
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
            )
            .padding(.horizontal, 32)

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    ProBadge(small: true)
                    Text("Unlock with Pro", comment: "History unlock button")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .cornerRadius(14)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func previewStatRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Stats Section (Pro)

    private var statsSection: some View {
        Section(header: Text("Overview", comment: "History stats section header")) {
            let completed = records.filter(\.finished)
            let totalElapsed = records.reduce(0) { $0 + $1.elapsedSeconds }
            let avgDuration = records.isEmpty ? 0 : totalElapsed / records.count
            let completionRate = records.isEmpty ? 0.0 : Double(completed.count) / Double(records.count) * 100

            statRow(String(localized: "Total Sessions"), value: "\(records.count)", icon: "play.circle.fill", color: .blue)
            statRow(String(localized: "Completed"), value: "\(completed.count)", icon: "checkmark.circle.fill", color: .green)
            statRow(String(localized: "Completion Rate"), value: String(format: "%.0f%%", completionRate), icon: "percent", color: .orange)
            statRow(String(localized: "Total Time"), value: formatTotalTime(), icon: "clock.fill", color: .purple)
            statRow(String(localized: "Average Duration"), value: formatSeconds(avgDuration), icon: "chart.line.uptrend.xyaxis", color: .cyan)

            // 이번 주 사용
            let thisWeek = recordsThisWeek()
            statRow(String(localized: "This Week"), value: "\(thisWeek.count) \(String(localized: "sessions"))", icon: "calendar", color: .indigo)
        }
    }

    private func statRow(_ label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Records List (Pro)

    private var recordsSection: some View {
        Section(header: Text("Recent Records", comment: "History records section header")) {
            ForEach(records.prefix(displayLimit)) { record in
                recordRow(record)
            }

            if records.count > displayLimit {
                Button {
                    displayLimit += 50
                } label: {
                    HStack {
                        Spacer()
                        Text(String(localized: "Show more (\(records.count - displayLimit) remaining)"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private func recordRow(_ record: TimerRecord) -> some View {
        HStack(spacing: 12) {
            // 완료/중단 아이콘
            Image(systemName: record.finished ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(record.finished ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                // 설정 시간
                HStack(spacing: 4) {
                    Text(formatSeconds(record.snapshotMainSeconds))
                        .font(.subheadline.weight(.medium))
                    if !record.snapshotPrealertOffsetsSec.isEmpty {
                        Text("· \(record.snapshotPrealertOffsetsSec.count) alerts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 날짜
                Text(record.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                +
                Text(" ")
                    .font(.caption)
                +
                Text(record.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 실제 사용 시간
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatSeconds(record.elapsedSeconds))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(record.finished ? String(localized: "completed") : String(localized: "stopped"))
                    .font(.caption2)
                    .foregroundStyle(record.finished ? .green : .secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func formatTotalTime() -> String {
        let total = records.reduce(0) { $0 + $1.elapsedSeconds }
        return formatSeconds(total)
    }

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        } else {
            return "\(seconds)s"
        }
    }

    private func recordsThisWeek() -> [TimerRecord] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return records.filter { $0.date >= startOfWeek }
    }
}

#Preview {
    TimerHistoryView()
        .modelContainer(for: [TimerRecord.self, Timer.self])
}
