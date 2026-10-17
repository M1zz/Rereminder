//
//  PreflightReportView.swift
//  Rereminder
//
//  설정 ▸ (마스터 모드) ▸ 출시 점검 — LeeoKit 사전 점검(`LeeoPreflight`)을 **설치된 이 빌드에서** 돌려 본다.
//
//  왜 앱 안에 두나: 단위 시험(`ReleaseReadinessTests.testPreflightIsReleasable`)은 시뮬레이터의 디버그 빌드를
//  본다. TestFlight·스토어 빌드에 실린 계약(개인정보·지원 주소, 결제 상품 선언 등)이 맞는지는 그 빌드를 연
//  기기에서 보는 것이 가장 확실하다. 개발자 화면이라 문구는 카탈로그에 넣지 않는다(`Text(verbatim:)`).
//

import SwiftUI
import LeeoKit

struct PreflightReportView: View {
    @State private var issues: [LeeoPreflightIssue] = []

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: issues.isReleasable ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .foregroundStyle(issues.isReleasable ? Color.green : Color.red)
                        .accessibilityHidden(true)
                    Text(verbatim: issues.isReleasable ? "출시 가능 — 막는 문제 없음" : "출시 전에 고칠 것이 있음")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
            }
            if issues.isEmpty {
                Section {
                    Text(verbatim: "점검 항목이 모두 통과했습니다.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: "\(issue.severity.symbol) \(issue.code)")
                                .font(.subheadline.weight(.semibold).monospaced())
                            Text(verbatim: issue.message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: "출시 점검"))
        .navigationBarTitleDisplayMode(.inline)
        // 계약 점검. ⚠️ `runtimeAudit` 는 쓰지 않는다 — 이 앱은 `LeeoKit.bootstrap` 대신 진단·킬스위치를
        //    직접 켜서(`RereminderApp.init`) 그쪽 표시가 늘 "꺼짐"으로 나와 거짓 경보가 된다.
        .onAppear { issues = LeeoPreflight.audit(RereminderSpec.self) }
    }
}
