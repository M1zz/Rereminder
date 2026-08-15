//
//  UsageStatsView.swift
//  Rereminder
//
//  개발자(마스터 모드) 전용 — 공용 허브(FeedbackHub)에서 실제 데이터를 읽어와 보여준다.
//   ① 사용자 수·활성 사용자 (UsageSnapshot)
//   ② 기간별 추이 (UsageEvent)
//   ③ 핵심 가치 — 완주율·관리한 시간·완주 분포 (스냅샷 metrics)
//   ④ 활성화/온보딩/결제 퍼널, 리텐션 코호트
//   ⑤ 접수된 피드백 요약 → 인박스로 이동
//
//  ⚠️ 남의 레코드를 읽는 화면이라 CloudKit 컨테이너 read 권한이 필요하다(피드백 인박스와 동일).
//     스키마·권한 절차: docs/USAGE_STATS_HUB.md
//  ⚠️ 개발자 전용이라 문구는 한국어 그대로 두되 `Text(verbatim:)`으로 쓴다 —
//     문자열 카탈로그(Localizable.xcstrings)에 추출되면 다국어 검사(predeploy)가 막힌다.
//

import SwiftUI
import LeeoKit

struct UsageStatsView: View {
    @State private var snapshots: [ActivityReporter.Snapshot] = []
    @State private var eventSamples: [ActivityReporter.EventSample] = []
    @State private var feedback: [LeeoFeedbackService.FeedbackRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// 스냅샷의 metrics만 뽑은 것 — 집계 함수는 전부 이 형태를 받는다(테스트 가능하게).
    private var metrics: [[String: Double]] { snapshots.map(\.metrics) }

    var body: some View {
        List {
            if isLoading && snapshots.isEmpty && eventSamples.isEmpty {
                loadingSection
            } else {
                // 일부만 실패해도(예: 아직 스키마 미배포) 읽어온 것은 그대로 보여준다.
                if let errorMessage { errorSection(errorMessage) }
                usersSection
                trendSection
                valueSection
                distributionSection
                activationFunnelSection
                onboardingFunnelSection
                paywallFunnelSection
                retentionSection
                adoptionSection
                eventsSection
                averagesSection
                versionSection
                feedbackSection
            }
        }
        .navigationTitle(Text(verbatim: "사용 통계"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - 상태

    private var loadingSection: some View {
        Section {
            HStack(spacing: 10) {
                ProgressView()
                Text(verbatim: "불러오는 중…").foregroundStyle(.secondary)
            }
        }
    }

    private func errorSection(_ message: String) -> some View {
        Section {
            Text(verbatim: message).foregroundStyle(.red)
        } footer: {
            Text(verbatim: "전체 통계를 읽으려면 CloudKit 컨테이너 read 권한과 UsageSnapshot·UsageEvent 스키마 배포가 필요해요.")
        }
    }

    // MARK: - 사용자

    private var usersSection: some View {
        Section {
            statRow("쓰고 있는 사람 (설치)", "\(snapshots.count)")
            statRow("최근 7일 활성", "\(activeCount(days: 7))")
            statRow("최근 30일 활성", "\(activeCount(days: 30))")
            statRow("최근 7일 신규", "\(newCount(days: 7))")
            statRow("누적 실행", "\(snapshots.reduce(0) { $0 + $1.launchCount })")
        } header: {
            Text(verbatim: "사용자")
        } footer: {
            Text(verbatim: "설치마다 익명 스냅샷 1건이라, 설치 수 = 이 앱을 쓰는 기기 수예요. 재설치하면 새 설치로 잡혀요.")
        }
    }

    // MARK: - 기간별 추이

    private var trendSection: some View {
        Section {
            UsageTrendChartView(events: eventSamples, installDates: snapshots.compactMap(\.installDate))
        } header: {
            Text(verbatim: "기간별 추이")
        } footer: {
            Text(verbatim: "일·주·월·연 단위로 묶어서 보여줘요. 차트를 좌우로 넘기면 그 단위만큼 과거로 이동하고, 막대를 탭하면 그 기간의 정확한 날짜와 숫자가 나와요.")
        }
    }

    // MARK: - 핵심 가치

    /// 이 앱이 실제로 쓸모를 냈는지 — 시작한 타이머가 끝까지 갔는가, 그게 몇 시간인가.
    private var valueSection: some View {
        let summary = UsageInsights.valueSummary(metrics: metrics)
        return Section {
            statRow("완주율", percent(summary.completionRate))
            statRow("한 번이라도 완주한 설치",
                    "\(summary.completedInstalls)곳 (\(percent(summary.activationRate)))")
            statRow("완주 총 횟수", "\(summary.totalCompletions)")
            statRow("완주해 본 설치당 완주", String(format: "%.1f회", summary.completionsPerActiveInstall))
            statRow("이 앱으로 관리한 시간", focusText(summary.totalFocusMinutes))
        } header: {
            Text(verbatim: "핵심 가치")
        } footer: {
            Text(verbatim: "완주율이 이 앱에서 가장 중요한 숫자예요. 타이머를 걸어 놓고 알림이 울릴 때까지 함께 있었다는 뜻이고, 낮으면 도중에 그만두게 만드는 무언가가 있다는 신호예요. 횟수는 기기에서 세서 스냅샷에 실어 보내니 쓰로틀과 무관하게 정확해요.")
        }
    }

    // MARK: - 완주 횟수 분포

    @ViewBuilder
    private var distributionSection: some View {
        if !snapshots.isEmpty {
            let buckets = UsageInsights.completionDistribution(metrics: metrics)
            let maxInstalls = max(1, buckets.map(\.installs).max() ?? 1)
            Section {
                ForEach(buckets) { bucket in
                    barRow(label: bucket.label, value: bucket.installs, maxValue: maxInstalls)
                }
            } header: {
                Text(verbatim: "완주 횟수 분포")
            } footer: {
                Text(verbatim: "몇 번 완주한 사람이 몇 명인지예요. 0회 칸이 가장 중요해요 — 깔았지만 한 번도 끝까지 안 간 사람의 수이고, 그 크기가 곧 첫인상에서 새는 양이에요.")
            }
        }
    }

    // MARK: - 퍼널

    @ViewBuilder
    private var activationFunnelSection: some View {
        let stages = UsageInsights.activationFunnel(from: eventSamples)
        if (stages.first?.installs ?? 0) > 0 {
            Section {
                ForEach(stages) { stage in funnelRow(stage) }
            } header: {
                Text(verbatim: "활성화 퍼널")
            } footer: {
                Text(verbatim: "앱을 연 사람 중 몇이 타이머를 걸고, 몇이 끝까지 갔는지예요. 같은 이벤트는 설치당 6시간에 한 번만 기록되니 절대 건수가 아니라 단계 사이의 비율을 보세요.")
            }
        }
    }

    @ViewBuilder
    private var onboardingFunnelSection: some View {
        let stages = UsageInsights.onboardingFunnel(from: eventSamples)
        if (stages.first?.installs ?? 0) > 0 {
            Section {
                ForEach(stages) { stage in funnelRow(stage) }
            } header: {
                Text(verbatim: "온보딩 퍼널")
            }
        }
    }

    @ViewBuilder
    private var paywallFunnelSection: some View {
        let stages = UsageInsights.paywallFunnel(from: eventSamples)
        let dropoffs = UsageInsights.dropoffReasons(from: eventSamples).filter { $0.events > 0 }
        if (stages.first?.installs ?? 0) > 0 || !dropoffs.isEmpty {
            Section {
                ForEach(stages) { stage in funnelRow(stage) }
                ForEach(dropoffs) { reason in
                    HStack {
                        Text(verbatim: reason.name).foregroundStyle(.secondary)
                        Spacer()
                        Text(verbatim: "\(reason.events)").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(verbatim: "결제 전환 퍼널")
            } footer: {
                Text(verbatim: "이탈 줄은 건수예요. 단계 수치와 달리 같은 설치가 여러 번 잡힐 수 있어요.")
            }
        }
    }

    // MARK: - 리텐션

    @ViewBuilder
    private var retentionSection: some View {
        let rows = UsageInsights.weeklyRetention(
            installs: snapshots.map { .init(id: $0.id, installDate: $0.installDate) },
            events: eventSamples
        )
        if !rows.isEmpty {
            Section {
                ForEach(rows.prefix(8)) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(verbatim: cohortLabel(row.cohortStart)).font(.body.weight(.medium))
                            Spacer()
                            Text(verbatim: "설치 \(row.size)곳").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 14) {
                            retentionCell("D1", row.rate(row.day1))
                            retentionCell("D7", row.rate(row.day7))
                            retentionCell("D30", row.rate(row.day30))
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(verbatim: "리텐션 (주간 코호트)")
            } footer: {
                Text(verbatim: "설치한 주별로 묶어 며칠 뒤에도 앱을 열었는지 봐요(app_open 기준). 아직 그날이 오지 않은 설치는 세지 않으니 최근 코호트의 D30은 낮게 보입니다.")
            }
        }
    }

    // MARK: - 기능 채택률

    @ViewBuilder
    private var adoptionSection: some View {
        let signals = UsageInsights.adoptionSignals(metrics: metrics)
        if !signals.isEmpty {
            Section {
                ForEach(signals) { signal in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(verbatim: signal.name)
                            Spacer()
                            Text(verbatim: signal.value).font(.body.weight(.medium))
                        }
                        Text(verbatim: signal.hint).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(verbatim: "기능 채택률")
            }
        }
    }

    // MARK: - 이벤트 / 평균 / 분포

    private var eventsSection: some View {
        let events = ActivityReporter.eventStats(from: eventSamples)
        return Section {
            if events.isEmpty {
                Text(verbatim: "아직 기록된 사용 내용이 없어요.").foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: event.name).font(.body.weight(.medium))
                        Text(verbatim: "\(event.count)건 · 설치 \(event.installs)곳")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text(verbatim: "앱 사용 내용")
        } footer: {
            Text(verbatim: "최근 이벤트 3,000건 기준이에요. 같은 이벤트는 설치당 6시간에 한 번만 기록되니, 건수보다 '설치 몇 곳이 하는지'를 보세요.")
        }
    }

    @ViewBuilder
    private var averagesSection: some View {
        let averages = metricAverages
        if !averages.isEmpty {
            Section {
                ForEach(averages, id: \.key) { item in
                    statRow(Self.metricLabel(item.key), Self.format(item.value))
                }
            } header: {
                Text(verbatim: "설치당 평균")
            } footer: {
                Text(verbatim: "값을 가진 설치만 분모로 세요(0인 지표는 아예 보내지 않아요).")
            }
        }
    }

    @ViewBuilder
    private var versionSection: some View {
        if !snapshots.isEmpty {
            Section {
                ForEach(distribution(\.appVersion), id: \.key) { item in
                    statRow(item.key, "\(item.count)")
                }
            } header: {
                Text(verbatim: "버전 분포")
            }
            Section {
                ForEach(distribution(\.platform), id: \.key) { item in
                    statRow(item.key, "\(item.count)")
                }
            } header: {
                Text(verbatim: "플랫폼")
            }
        }
    }

    // MARK: - 피드백

    private var feedbackSection: some View {
        let nudge = UsageInsights.feedbackNudgeResponse(from: eventSamples)
        return Section {
            statRow("접수된 피드백", "\(feedback.count)")
            statRow("아직 처리 안 함", "\(feedback.filter { !$0.isDone }.count)")
            if nudge.shownInstalls > 0 {
                statRow("의견 요청 수락률",
                        "\(percent(nudge.acceptRate)) (\(nudge.acceptedInstalls)/\(nudge.shownInstalls)곳)")
            }
            NavigationLink {
                FeedbackInboxView()
            } label: {
                Label {
                    Text(verbatim: "피드백 전부 보기")
                } icon: {
                    Image(systemName: "tray.full.fill")
                }
            }
        } header: {
            Text(verbatim: "피드백")
        } footer: {
            Text(verbatim: "최근 100건 기준이에요. 인박스에서 완료 표시·삭제를 할 수 있어요. 수락률이 낮으면 묻는 시점이나 문구를 손볼 때예요 — 통계가 '어디서' 떨어지는지 말해 준다면, 이유는 여기로만 들어와요.")
        }
    }

    // MARK: - 행 조각

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: label)
            Spacer()
            Text(verbatim: value)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// 값과 비율을 함께 읽는 가로 막대 — 숫자만 있으면 분포의 모양이 안 보인다.
    private func barRow(label: String, value: Int, maxValue: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: label)
                Spacer()
                Text(verbatim: "\(value)곳").font(.body.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.accentColor)
                        .frame(width: max(2, geo.size.width * Double(value) / Double(maxValue)))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func funnelRow(_ stage: UsageInsights.FunnelStage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: stage.name).font(.body.weight(.medium))
                Spacer()
                Text(verbatim: "설치 \(stage.installs)곳").foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(Color.accentColor)
                        .frame(width: max(2, geo.size.width * stage.rateFromTop))
                }
            }
            .frame(height: 6)
            Text(verbatim: "전체 대비 \(percent(stage.rateFromTop)) · 직전 단계 대비 \(percent(stage.rateFromPrevious))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func retentionCell(_ label: String, _ rate: Double) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: label).font(.caption2).foregroundStyle(.secondary)
            Text(verbatim: percent(rate)).font(.body.weight(.medium))
        }
    }

    // MARK: - 집계 (클라이언트 계산)

    private func activeCount(days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return snapshots.filter { ($0.lastActiveAt ?? .distantPast) >= cutoff }.count
    }

    private func newCount(days: Int) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return snapshots.filter { ($0.installDate ?? .distantPast) >= cutoff }.count
    }

    private struct Bucket: Identifiable { let key: String; let count: Int; var id: String { key } }
    private func distribution(_ keyPath: KeyPath<ActivityReporter.Snapshot, String>) -> [Bucket] {
        Dictionary(grouping: snapshots) { $0[keyPath: keyPath] }
            .map { Bucket(key: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// 0/1 플래그가 아닌 수치 지표 — 값을 가진 설치들의 평균.
    private struct MetricAvg { let key: String; let value: Double }
    private var metricAverages: [MetricAvg] {
        var sums: [String: (total: Double, n: Int)] = [:]
        for snapshot in snapshots {
            for (key, value) in snapshot.metrics where !key.hasPrefix("flag.") {
                let current = sums[key] ?? (0, 0)
                sums[key] = (current.total + value, current.n + 1)
            }
        }
        return sums
            .map { MetricAvg(key: $0.key, value: $0.value.n > 0 ? $0.value.total / Double($0.value.n) : 0) }
            .sorted { $0.key < $1.key }
    }

    // MARK: - 표기

    private func percent(_ value: Double) -> String { String(format: "%.0f%%", value * 100) }

    private func focusText(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)시간 \(minutes % 60)분" : "\(minutes)분"
    }

    private func cohortLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return "\(formatter.string(from: date)) 주"
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// 전송 키(고정) → 화면 라벨. 모르는 키는 원본 그대로 보여준다.
    private static func metricLabel(_ key: String) -> String {
        switch key {
        case "timerStarts":       return "타이머 시작 횟수"
        case "timerCompletions":  return "완주 횟수"
        case "timerCancels":      return "도중 취소 횟수"
        case "focusMinutes":      return "관리한 시간 (분)"
        case "presentationRuns":  return "발표 모드 실행"
        case "presetSaves":       return "템플릿 저장"
        case "presetUses":        return "템플릿 사용"
        case "watchSyncUses":     return "워치 동기화"
        case "templates":         return "보유 템플릿 수"
        default:                  return key
        }
    }

    // MARK: - Load

    private func load() async {
        isLoading = true
        errorMessage = nil
        var failures: [String] = []

        do {
            snapshots = try await ActivityReporter.fetchSnapshots()
        } catch {
            failures.append(error.localizedDescription)
        }

        do {
            eventSamples = try await ActivityReporter.fetchEvents()
        } catch {
            failures.append(error.localizedDescription)
        }

        do {
            feedback = try await ActivityReporter.fetchFeedback()
        } catch {
            failures.append(error.localizedDescription)
        }

        if !failures.isEmpty {
            errorMessage = "불러오지 못했어요: " + Set(failures).joined(separator: "\n")
        }
        isLoading = false
    }
}
