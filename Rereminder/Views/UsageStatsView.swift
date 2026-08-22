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

    /// 설치마다 "결제까지 얼마나 가까운가"를 매긴 것 — 결제 퍼널·구분·명단이 전부 이 하나를 쓴다.
    /// 스냅샷은 설치당 1건 upsert라 **지금 상태**다(이벤트는 쓰로틀 걸린 과거형이라 못 센다).
    /// ⚠️ 계산 프로퍼티로 두면 섹션마다(그리고 다시 그릴 때마다) 설치 수천 건을 다시 정렬한다 —
    ///    불러올 때 한 번만 만든다.
    @State private var profiles: [UsageInsights.UserProfile] = []

    /// 알림 개수 분포를 어느 쪽으로 볼지 — **실행 기준**과 **사람 기준**은 단위가 달라
    /// 한 차트에 겹쳐 그리지 않고 갈아 끼운다(축이 둘이면 없는 관계가 보인다).
    @State private var alertMeasure: AlertMeasure = .runs
    /// 알림 개수 분포를 결제 여부로 갈라 본다 — **무료 한도를 몇 개로 둘지는 이걸로만 정할 수 있다.**
    @State private var alertPlan: UsageInsights.PlanFilter = .all

    enum AlertMeasure: String, CaseIterable, Identifiable {
        /// 타이머 실행 하나하나를 센다 — "이 앱이 실제로 돌아가는 모양".
        case runs
        /// 설치마다 최빈값 하나씩 — "이 개수를 자기 기본값으로 삼은 사람 수".
        case installs
        var id: String { rawValue }

        var label: String { self == .runs ? "실행 기준" : "사람 기준" }
        var unit: String { self == .runs ? "회" : "명" }
    }

    var body: some View {
        List {
            if isLoading && snapshots.isEmpty && eventSamples.isEmpty {
                loadingSection
            } else {
                // 일부만 실패해도(예: 아직 스키마 미배포) 읽어온 것은 그대로 보여준다.
                if let errorMessage { errorSection(errorMessage) }
                usersSection
                purchaseReadinessSection
                paymentFunnelSection
                alertUsageSection
                alertDemandSection
                segmentSection
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
            // 같은 단위(횟수)라 한 축에 세울 수 있다 — 완주율이 숫자라면 이건 그 숫자의 모양이다.
            if summary.totalStarts > 0 {
                UsageDistributionChart(
                    items: [
                        .init(label: "시작", value: summary.totalStarts),
                        .init(label: "완주", value: summary.totalCompletions, isKey: true),
                        .init(label: "취소", value: max(0, summary.totalStarts - summary.totalCompletions))
                    ],
                    unit: "회",
                    height: 140
                )
            }
            statRow("완주율", percent(summary.completionRate))
            statRow("한 번이라도 완주한 설치",
                    "\(summary.completedInstalls)곳 (\(percent(summary.activationRate)))")
            statRow("완주 총 횟수", "\(summary.totalCompletions)")
            statRow("완주해 본 설치당 완주", String(format: "%.1f회", summary.completionsPerActiveInstall))
            statRow("이 앱으로 관리한 시간", focusText(summary.totalFocusMinutes))

            // **완주보다 이게 진짜 aha 다.** 알림이 한 번도 울리지 않은 완주는
            // 평범한 타이머를 쓴 것과 같다 — 이 앱이 판 것이 아니다.
            let heard = UsageInsights.alertedValueSummary(metrics: metrics)
            if heard.completions > 0 {
                highlightRow(title: "알림을 듣고 완주",
                             value: percent(heard.alertedRunRate),
                             detail: "완주 \(heard.completions)회 중 \(heard.alertedCompletions)회는 "
                                   + "끝나기 전 알림이 실제로 울렸어요.")
                statRow("가치를 경험한 설치",
                        "\(heard.installsWithAlertedCompletion)곳 (\(percent(heard.alertedInstallRate)))")
            }
        } header: {
            Text(verbatim: "핵심 가치")
        } footer: {
            Text(verbatim: "완주율이 이 앱에서 가장 중요한 숫자예요. 타이머를 걸어 놓고 알림이 울릴 때까지 함께 있었다는 뜻이고, 낮으면 도중에 그만두게 만드는 무언가가 있다는 신호예요.\n\n'알림을 듣고 완주'는 그중에서도 이 앱만의 숫자예요 — 끝에만 울리는 평범한 타이머와 달리, 끝나기 전에 알림이 실제로 울린 실행이에요. 이 비율이 낮으면 사람들이 이 앱을 그냥 타이머로 쓰고 있다는 뜻이고, 그러면 알림 개수로 돈을 받는 구조 자체가 어긋나 있어요.\n\n횟수는 기기에서 세서 스냅샷에 실어 보내니 쓰로틀과 무관하게 정확해요. 2.2.x 이전 버전은 '알림을 듣고 완주'를 보내지 않아 실제보다 낮게 시작해요.")
        }
    }

    // MARK: - 완주 횟수 분포

    @ViewBuilder
    private var distributionSection: some View {
        if !snapshots.isEmpty {
            let buckets = UsageInsights.completionDistribution(metrics: metrics)
            Section {
                UsageDistributionChart(items: buckets.map {
                    // 0회 칸만 강조 — 이 차트를 보는 이유가 그 칸이다.
                    .init(label: $0.label, value: $0.installs, isKey: $0.lowerBound == 0)
                })
            } header: {
                Text(verbatim: "완주 횟수 분포")
            } footer: {
                Text(verbatim: "몇 번 완주한 사람이 몇 명인지예요. 0회 칸이 가장 중요해요 — 깔았지만 한 번도 끝까지 안 간 사람의 수이고, 그 크기가 곧 첫인상에서 새는 양이에요.")
            }
        }
    }

    // MARK: - 결제 준비도 (이 화면에서 가장 먼저 볼 숫자)

    /// "지금 결제에 가까운 사람이 몇 명인가" — 이 앱의 결제는 알림 개수로 갈리므로,
    /// 알림 한도에 부딪힌 사람 수가 곧 결제 후보 수다.
    @ViewBuilder
    private var purchaseReadinessSection: some View {
        if !snapshots.isEmpty {
            let readiness = UsageInsights.purchaseReadiness(profiles: profiles)
            Section {
                highlightRow(title: "지금 막혀 있는 사람",
                             value: "\(readiness.blocked)명",
                             detail: "알림을 더 켜려면 결제해야 하는 상태예요.")
                highlightRow(title: "한도 임박 (체험 1~2회)",
                             value: "\(readiness.nearLimit)명",
                             detail: "곧 위 칸으로 넘어와요.")
                highlightRow(title: "최근 \(readiness.recentDays)일 안에 쓴 사람 중 결제 후보",
                             value: "\(readiness.reachable)명",
                             detail: "떠나지 않은 사람만 센 값이에요. 실제로 두드릴 수 있는 대상이에요.")
                highlightRow(title: "곧 필요해질 사람",
                             value: "\(readiness.latentDemand)명",
                             detail: "아직 알림 1개로 쓰지만 반복해서 완주하는 사람이에요(완주 \(UsageInsights.repeatUseThreshold)회 이상).")
                statRow("이미 결제한 사람", "\(readiness.paying)명 (\(percent(readiness.payingRate)))")
                statRow("결제에 가까워진 비율", percent(readiness.nearPurchaseRate))
                // 네 숫자가 다 '명'이라 한 축에 세울 수 있다 — 어느 칸이 큰지는 눈이 먼저 답한다.
                UsageBreakdownChart(
                    items: [
                        .init(label: "막힘", value: readiness.blocked, detail: "\(readiness.blocked)명"),
                        .init(label: "임박", value: readiness.nearLimit, detail: "\(readiness.nearLimit)명"),
                        .init(label: "곧 필요", value: readiness.latentDemand, detail: "\(readiness.latentDemand)명"),
                        .init(label: "결제함", value: readiness.paying, detail: "\(readiness.paying)명")
                    ],
                    unit: "명",
                    limit: 4
                )
                if !UsageInsights.hotLeads(profiles: profiles).isEmpty {
                    NavigationLink {
                        UserSegmentListView(profiles: profiles, initialStage: .blocked)
                    } label: {
                        Label {
                            Text(verbatim: "결제 후보 명단 보기")
                        } icon: {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                        }
                    }
                }
            } header: {
                Text(verbatim: "결제 준비도 (지금)")
            } footer: {
                Text(verbatim: "이 앱의 결제는 '알림을 몇 개까지 켤 수 있나'로 갈려요(무료 1개, 그 위는 5+5 체험 뒤 결제). 그래서 결제에 가까운 사람 = 알림 한도에 다가간 사람이에요. 스냅샷은 설치당 1건 덮어쓰기라 여기 숫자는 과거 합계가 아니라 지금 상태예요.")
            }
        }
    }

    // MARK: - 결제 퍼널 (지금 상태)

    @ViewBuilder
    private var paymentFunnelSection: some View {
        if !snapshots.isEmpty {
            let stages = UsageInsights.paymentFunnel(profiles: profiles)
            Section {
                UsageFunnelChart(stages: stages)
                if let worst = weakestStep(stages) {
                    dropNote(worst)
                }
            } header: {
                Text(verbatim: "결제 퍼널 (지금 상태)")
            } footer: {
                Text(verbatim: "설치 → 가치 경험 → 알림 2개 이상 → 한도 도달 → 페이월 → 결제. 어느 칸에서 확 줄어드는지가 곧 손볼 곳이에요. 결제한 사람은 앞 단계를 모두 지난 것으로 세요. 아래 '결제 이벤트'는 같은 이야기를 기간 누적 이벤트로 본 것이라 숫자가 다를 수 있어요.")
            }
        }
    }

    // MARK: - 주로 쓰는 알림 개수 (실행마다 센 값)

    /// **이 앱이 실제로 팔고 있는 크기.** `alertsMax`(아래 섹션)가 "가장 많이 걸어 본 개수"라면
    /// 여기는 "평소 몇 개를 거는가"다 — 한 번 5개를 해 본 사람과 늘 5개를 거는 사람은 다르다.
    @ViewBuilder
    private var alertUsageSection: some View {
        let summary = UsageInsights.alertUsageSummary(metrics: metrics, plan: alertPlan)
        if summary.totalRuns > 0 {
            let buckets = UsageInsights.alertRunDistribution(metrics: metrics, plan: alertPlan)
            let values = buckets.map { alertMeasure == .runs ? $0.runs : $0.installs }
            let peak = values.max() ?? 0
            Section {
                Picker(selection: $alertMeasure) {
                    ForEach(AlertMeasure.allCases) { measure in
                        Text(verbatim: measure.label).tag(measure)
                    }
                } label: {
                    Text(verbatim: "보는 기준")
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // 무료 사용자의 분포는 한도에 눌린 값이다(1개에서 잘린다).
                // 눌리지 않은 수요는 **결제한 사람**에게서만 보인다 — 그래서 갈라 본다.
                Picker(selection: $alertPlan) {
                    ForEach(UsageInsights.PlanFilter.allCases) { plan in
                        Text(verbatim: plan.label).tag(plan)
                    }
                } label: {
                    Text(verbatim: "결제 여부")
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                UsageDistributionChart(
                    items: zip(buckets, values).map { bucket, value in
                        // 가장 높은 칸이 곧 "주로 쓰는 개수"다 — 눈이 거기 먼저 가야 한다.
                        .init(label: bucket.label, value: value, isKey: value == peak && peak > 0)
                    },
                    unit: alertMeasure.unit
                )

                if let mode = summary.modeAlerts {
                    highlightRow(title: "주로 쓰는 알림 개수",
                                 value: mode == 0 ? "없음" : "\(mode)개",
                                 detail: "타이머 실행 \(summary.totalRuns)회 중 가장 많았던 개수예요.")
                }
                statRow("실행당 평균 알림", String(format: "%.1f개", summary.averageAlerts))
                statRow("알림 2개 이상 건 실행", percent(summary.multiAlertRunRate))
                statRow("이 값을 보내온 설치",
                        "\(summary.reportingInstalls)곳 (\(percent(summary.coverageRate)))")
            } header: {
                Text(verbatim: "주로 쓰는 알림 개수")
            } footer: {
                Text(verbatim: "타이머를 시작할 때마다 그때 건 알림 개수를 기기에서 세어 보낸 값이에요. '실행 기준'은 타이머 하나하나를, '사람 기준'은 설치마다 가장 자주 쓰는 개수 하나씩을 세요.\n\n무료 한도를 올릴지는 '결제'만 켜고 보세요 — 무료 분포는 한도(현재 \(ProGate.freePrealertLimit)개)에 눌린 값이라 '다들 이 정도면 충분하다'는 잘못된 결론이 나요. 결제한 사람이 주로 쓰는 개수가 한도보다 넉넉히 크면 한도를 올려도 팔 것이 남아요.\n\n2.1.2 이전 버전은 아직 이 값을 보내지 않아 '보내온 설치' 비율이 낮게 시작해요.")
            }
        }
    }

    // MARK: - 알림 개수 수요

    @ViewBuilder
    private var alertDemandSection: some View {
        if !snapshots.isEmpty {
            let buckets = UsageInsights.alertDemandDistribution(profiles: profiles)
            Section {
                UsageDistributionChart(items: buckets.map {
                    // 무료 한도(1개) 바로 위 칸이 이 차트의 관전 포인트다.
                    .init(label: $0.label,
                          value: $0.installs,
                          isKey: $0.lowerBound > ProGate.freePrealertLimit)
                })
            } header: {
                Text(verbatim: "알림 개수 수요 (한 타이머 최대)")
            } footer: {
                Text(verbatim: "무료는 1개까지예요. 2개 이상 칸이 크면 지금의 가격 경계가 실제로 매출을 만든다는 뜻이고, 1개 칸만 크면 한도를 조여도 결제는 늘지 않아요. '기록 없음'은 2.1.1 이전 버전이라 아직 이 값을 보내지 않은 설치예요.")
            }
        }
    }

    // MARK: - 사용자 구분

    @ViewBuilder
    private var segmentSection: some View {
        if !snapshots.isEmpty {
            let segments = UsageInsights.segmentCounts(profiles: profiles).filter { $0.count >= 1 }
            Section {
                UsageBreakdownChart(items: segments.map {
                    .init(label: $0.stage.label, value: $0.count, detail: "\($0.count)명")
                }, unit: "명", limit: UsageInsights.PaymentStage.allCases.count)
                ForEach(segments, id: \.stage) { segment in
                    NavigationLink {
                        UserSegmentListView(profiles: profiles, initialStage: segment.stage)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(verbatim: segment.stage.label)
                                Spacer()
                                Text(verbatim: "\(segment.count)명")
                                    .font(.body.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(verbatim: segment.stage.detail)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 1)
                    }
                }
            } header: {
                Text(verbatim: "사용자 구분")
            } footer: {
                Text(verbatim: "설치 하나하나를 결제까지의 거리로 나눈 거예요. 줄을 누르면 그 구분에 속한 설치 명단이 나와요(익명 설치 ID 앞 8자리).")
            }
        }
    }

    // MARK: - 퍼널

    @ViewBuilder
    private var activationFunnelSection: some View {
        let stages = UsageInsights.activationFunnel(from: eventSamples)
        if (stages.first?.installs ?? 0) > 0 {
            Section {
                UsageFunnelChart(stages: stages)
                if let worst = weakestStep(stages) { dropNote(worst) }
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
                UsageFunnelChart(stages: stages)
                if let worst = weakestStep(stages) { dropNote(worst) }
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
                if (stages.first?.installs ?? 0) > 0 {
                    UsageFunnelChart(stages: stages)
                }
                if !dropoffs.isEmpty {
                    Text(verbatim: "이탈 사유 (건수)")
                        .font(.caption).foregroundStyle(.secondary)
                    UsageBreakdownChart(items: dropoffs.map {
                        .init(label: $0.name, value: $0.events, detail: "\($0.events)건")
                    }, unit: "건", limit: dropoffs.count)
                }
            } header: {
                Text(verbatim: "결제 이벤트 (기간 누적)")
            } footer: {
                Text(verbatim: "위 '결제 퍼널(지금 상태)'이 현재 인원이라면, 이건 최근 이벤트 3,000건에 남은 흔적이에요. 이탈 줄은 건수라 같은 설치가 여러 번 잡힐 수 있어요.")
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
                // 오래된 코호트가 왼쪽에 오도록 뒤집는다(시간은 왼쪽에서 오른쪽으로 흐른다).
                UsageRetentionChart(rows: Array(rows.prefix(8).reversed()))
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
            let ratios = signals.compactMap { signal in
                signal.ratio.map { UsageRatioChart.Item(label: signal.name, ratio: $0) }
            }
            Section {
                if !ratios.isEmpty { UsageRatioChart(items: ratios) }
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
                // 건수보다 '설치 몇 곳이 하는지'가 뜻이 있어서 그 값으로 세우고, 건수는 옆에 적는다.
                UsageBreakdownChart(items: events
                    .sorted { $0.installs > $1.installs }
                    .map { .init(label: $0.name,
                                 value: $0.installs,
                                 detail: "\($0.installs)곳 · \($0.count)건") },
                                    unit: "곳",
                                    limit: 10)
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
                UsageBreakdownChart(items: distribution(\.appVersion).map {
                    .init(label: $0.key, value: $0.count, detail: "\($0.count)곳")
                })
            } header: {
                Text(verbatim: "버전 분포")
            }
            Section {
                UsageBreakdownChart(items: distribution(\.platform).map {
                    .init(label: $0.key, value: $0.count, detail: "\($0.count)곳")
                }, limit: 6)
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

    /// 큰 숫자 + 그 숫자를 어떻게 읽어야 하는지. 판단에 바로 쓰는 줄에만 쓴다.
    private func highlightRow(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(verbatim: title)
                Spacer()
                Text(verbatim: value)
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            Text(verbatim: detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    /// 퍼널에서 **가장 크게 줄어드는 칸** — 차트를 보면 눈에 띄지만, 말로도 한 번 못박아 둔다.
    private func weakestStep(_ stages: [UsageInsights.FunnelStage]) -> UsageInsights.FunnelStage? {
        stages.dropFirst().filter { $0.rateFromPrevious < 1 }.min { $0.rateFromPrevious < $1.rateFromPrevious }
    }

    private func dropNote(_ stage: UsageInsights.FunnelStage) -> some View {
        Label {
            Text(verbatim: "가장 크게 줄어드는 칸: \(stage.name) — 직전 단계의 \(percent(stage.rateFromPrevious))만 넘어와요.")
                .font(.caption)
        } icon: {
            Image(systemName: "arrow.down.right")
        }
        .foregroundStyle(.secondary)
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
            // 알림 개수 히스토그램(alertRuns.*)은 위에서 차트로 다 보여 준다 — 여기서는 뺀다.
            for (key, value) in snapshot.metrics
            where !key.hasPrefix("flag.") && !key.hasPrefix("alertRuns.") {
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
        case "alertsMax":         return "알림 최대 개수"
        case "multiAlertRuns":    return "알림 2개 이상 실행"
        case "alertLimitHits":    return "알림 한도에 막힌 횟수"
        case "paywallViews":      return "페이월 노출 횟수"
        case "trial.prealerts":   return "알림 체험 사용 횟수"
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

        profiles = UsageInsights.profiles(from: snapshots.map {
            .init(id: $0.id,
                  metrics: $0.metrics,
                  installDate: $0.installDate,
                  lastActiveAt: $0.lastActiveAt,
                  appVersion: $0.appVersion,
                  platform: $0.platform)
        })

        if !failures.isEmpty {
            errorMessage = "불러오지 못했어요: " + Set(failures).joined(separator: "\n")
        }
        isLoading = false
    }
}
