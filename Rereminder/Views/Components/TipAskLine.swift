//
//  TipAskLine.swift
//  Rereminder
//
//  "계속 만들 수 있게 힘을 보태 주세요" 카드. 타이머를 **끝까지 마친 직후** 원 아래 묶음에 선다.
//
//  누구에게: **이미 Pro 를 다 가진 사람**에게만(결제·평생 무료·창단 후원자). 무료·플러스(기억) 사용자에게는
//  올리는 길(페이월)이 맞는 길이라 팁을 묻지 않는다 — 파는 말 둘이 겹치면 둘 다 약해진다.
//  언제: 이 앱이 그 사람에게 도움이 됐다는 것이 **숫자로 보이는 순간**(`TipAskMoments`).
//       방금 타이머를 끝낸 자리라 숫자가 막 하나 늘어난 때다.
//  얼마나 드물게: LeeoKit 의 규칙(`LeeoTipAskPolicy`). 물으면 60일 쉬고, 낸 사람은 180일, '다음에' 세 번이면 끝.
//
//  ⚠️ 모달이 아니다. 끝난 화면 아래에 한 장 서고, 다이얼을 다시 만지거나 타이머를 걸면 물러난다.
//

import SwiftUI
import LeeoKit

// MARK: - 순간 (순수)

enum TipAskMoments {
    /// 관리한 시간(시간). 큰 것부터.
    static let hours = [100, 30, 10]
    /// **예비 알림을 들은 채** 끝까지 마친 타이머 수(`UsageMetrics.alertedCompletions`). 큰 것부터.
    static let alertedCompletions = [300, 100, 30]

    /// 넘어선 순간, **인상적인 것부터**. 시간이 앞이다(사람이 얻은 것이 가장 분명하다).
    static func reached(focusMinutes: Double, alertedCompletions completions: Int) -> [LeeoTipMoment] {
        let h = Int(focusMinutes / 60)
        let byHours = hours.filter { h >= $0 }.map { threshold in
            LeeoTipMoment(id: "hours.\(threshold)",
                          message: String(localized: "You've kept \(h) hours on track so far",
                                          comment: "Tip ask card: total hours timed so far"))
        }
        let byAlerts = alertedCompletions.filter { completions >= $0 }.map { threshold in
            LeeoTipMoment(id: "alerted.\(threshold)",
                          message: String(localized: "\(completions) timers finished with a heads-up before the end",
                                          comment: "Tip ask card: how many timers ended after pre-alerts rang"))
        }
        return byHours + byAlerts
    }

    static var reachedNow: [LeeoTipMoment] {
        reached(focusMinutes: UsageMetrics.value(.focusMinutes),
                alertedCompletions: Int(UsageMetrics.value(.alertedCompletions)))
    }
}

// MARK: - 한 곳

@MainActor
final class TipAskCenter: ObservableObject {
    static let shared = TipAskCenter()
    @Published private(set) var moment: LeeoTipMoment?
    /// 물을 거리를 정할 때 닿아 있던 순간들. 카드가 실제로 섰을 때 물은 것으로 적는다.
    private var reachedAtEvaluate: [LeeoTipMoment] = []

    private init() {}

    /// 물을 때인지 본다. 이미 카드가 서 있으면 그대로 둔다.
    /// ⚠️ 여기서 물은 것으로 적지 않는다 — 카드가 실제로 섰을 때(`markShown`) 적는다.
    func evaluate() {
        guard moment == nil, StoreManager.isProUser,
              let tipJar = StoreManager.shared.tipJar else { return }
        let reached = TipAskMoments.reachedNow
        guard let next = tipJar.momentToAsk(from: reached) else { return }
        reachedAtEvaluate = reached
        moment = next
    }

    /// 카드가 실제로 섰다. 이때 물은 것으로 적는다.
    func markShown() {
        guard moment != nil, !reachedAtEvaluate.isEmpty,
              let tipJar = StoreManager.shared.tipJar else { return }
        tipJar.markAsked(covering: reachedAtEvaluate)
        reachedAtEvaluate = []
    }

    func close() { moment = nil }
}

// MARK: - 카드

/// 부탁 카드 한 장. 띄울지는 `TipAskCenter.moment` 가 정한다 — 부르는 쪽은 그게 있을 때만 세운다.
/// '응원하기'를 누르면 카드는 시트 뒤에 남았다가 시트가 닫힐 때 물러난다(시트가 카드에 붙어 있어서다).
struct TipAskLine: View {
    let moment: LeeoTipMoment
    let tipJar: LeeoTipJar
    @State private var showTipJar = false

    var body: some View {
        LeeoTipAskCard(tipJar: tipJar, moment: moment,
                       onSupport: { showTipJar = true },
                       onLater: {
                           withAnimation(.easeInOut(duration: 0.2)) { TipAskCenter.shared.close() }
                       })
            .onAppear { TipAskCenter.shared.markShown() }
            .sheet(isPresented: $showTipJar, onDismiss: { TipAskCenter.shared.close() }) {
                NavigationStack {
                    LeeoTipJarView<RereminderSpec>(tipJar: tipJar)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "Close")) { showTipJar = false }
                            }
                        }
                }
            }
    }
}
