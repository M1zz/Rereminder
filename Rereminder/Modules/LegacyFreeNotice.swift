//
//  LegacyFreeNotice.swift
//  Rereminder
//
//  **Pro 가 바뀌기 전부터 무료로 쓰던 사람에게, 무엇이 달라졌는지 한 번 알린다** — 판정만 한다.
//
//  왜: 2.2.2(첫 배포 2.2.4)에서 파는 축이 "알림 개수"에서 "앱이 기억한다"로 옮겨 가며, 그 전의
//  무료 사용자는 **얻은 것**(예비 알림 무제한)과 함께 **잃은 것**이 생겼다 —
//  템플릿 3개 무료 저장·불러오기, 앱을 다시 열 때 마지막 설정 복원.
//  결제한 사람(창단 후원자)과 Pro 도입 전 사용자(그랜드파더링)에게는 안내 화면이 있었지만
//  **이 사람들에게는 아무 설명이 없었다.** 어느 날 자기 템플릿에 자물쇠가 붙어 있는 것을 보게 된다.
//  소리 없이 빼앗긴 것은 결제가 아니라 분노가 된다 — 그래서 그대로 적어서 보여 준다.
//
//  ⚠️ **"개편 전부터 썼다"는 날짜가 붙은 흔적으로만 판정한다.** 경계는 창단 후원자와 같은
//     `FoundingSupporter.windowClosedAt`(개편 버전을 처음 실행한 순간)이다. 흔적은 넷:
//     ① 개편 버전을 **바로 이번에** 처음 켰는데 이미 타이머를 건 적이 있다
//     ② 옛 알림 한도 시절에만 쌓이던 키가 남아 있다(`legacyOnlyKeys` — 지금은 아무도 쓰지 않는다)
//     ③ 경계보다 먼저 만들어진 템플릿이 있다(시드 포함 — 시드는 설치 시점의 증거다)
//     ④ 경계보다 먼저 남은 타이머 기록이 있다
//     새로 설치한 사람은 넷 다 해당하지 않는다 — 시드도 창이 닫힌 **뒤에** 심긴다
//     (`TimerUnifiedView.setupOnAppear` 의 순서. 바꾸면 신규 사용자 전원이 이 안내를 본다).
//  ⚠️ 한 번 참이 되면 기억해 둔다(`eligibleKey`). 설정에서 다시 열어 볼 자리가 그걸 본다.
//  ⚠️ Pro(결제·그랜드파더링·자동 Pro)와 창단 후원자에게는 띄우지 않는다 — 그들은 잃은 것이 없다.
//

import Foundation
import SwiftData

enum LegacyFreeNotice {

    // MARK: - 저장

    /// ⚠️ 테스트에서 갈아 끼운다.
    static var defaults: UserDefaults = .standard

    private static let eligibleKey = "rereminder.legacyFree.eligible"
    private static let checkedKey = "rereminder.legacyFree.checked"
    private static let announcedKey = "rereminder.legacyFree.announced"

    /// 옛 알림 한도 시절에만 쌓이던 키. 지금 코드는 **어디서도 쓰지 않으므로** 있으면 개편 전 흔적이다.
    /// (`ProGate.Feature.unlimitedPrealerts`·`PrealertGrace`·`UsageMetrics` 의 늘지 않는 키)
    static let legacyOnlyKeys = [
        "trial.count.unlimitedPrealerts",
        "trial.extension.unlimitedPrealerts",
        "prealert.grace.lastGrantedDay",
        "usage.metric.alertLimitHits",
        "usage.metric.graceGrants",
    ]

    /// 첫 실행에 심는 시드 템플릿의 이름(`TimerConfigService.seedIfNeeded`).
    /// 안내에서 "저장해 두신 템플릿"을 셀 때는 빼야 한다 — 사용자가 만든 것이 아니다.
    static let seedTemplateNames: Set<String> = [
        "Presentation 30 min", "Mentoring 40 min", "Study 25 min", "Exercise 30 min", "Meeting 60 min",
    ]

    // MARK: - 판정 (순수 함수)

    /// 개편 전부터 쓰던 흔적이 있는가.
    static func hasPreChangeEvidence(windowClosedAt: Date?,
                                     windowJustClosed: Bool,
                                     priorTimerStarts: Double,
                                     legacyKeysPresent: Bool,
                                     earliestTemplate: Date?,
                                     earliestRecord: Date?) -> Bool {
        if windowJustClosed, priorTimerStarts > 0 { return true }
        if legacyKeysPresent { return true }
        guard let windowClosedAt else { return false }
        if let earliestTemplate, earliestTemplate < windowClosedAt { return true }
        if let earliestRecord, earliestRecord < windowClosedAt { return true }
        return false
    }

    /// 지금 안내를 띄울까.
    static func shouldAnnounce(isPro: Bool, isFounder: Bool) -> Bool {
        isEligible && !isPro && !isFounder && !defaults.bool(forKey: announcedKey)
    }

    /// 개편 전부터 무료로 쓰던 사람으로 판정된 적이 있는가.
    static var isEligible: Bool { defaults.bool(forKey: eligibleKey) }

    static func markAnnounced() {
        defaults.set(true, forKey: announcedKey)
    }

    // MARK: - 개편 전에 만든 템플릿은 무료에서도 불러온다

    /// 개편 **전에** 만든 템플릿인가 — 그렇다면 무료에서도 불러올 수 있다.
    ///
    /// 왜: 그 사람들은 무료로 저장하고 불러오던 템플릿을 개편과 함께 잃었다. 설명만 하고 돌려주지
    /// 않으면 안내 화면은 "잃으셨습니다, 돌려받으려면 결제하세요"로 읽힌다. **새로 저장하는 것은
    /// 여전히 Pro** 라서 파는 물건은 줄지 않고, 해당하는 사람도 적다.
    /// ⚠️ 날짜로만 가른다 — 경계는 `FoundingSupporter.windowClosedAt`. 새로 설치한 사람의 시드는
    ///    창이 닫힌 **뒤에** 심기므로 여기에 걸리지 않는다(`setupOnAppear` 의 순서).
    /// ⚠️ 개수로 나누는 게 아니다(`ProGate` 의 "템플릿에 무료 몫이 없다"는 원칙은 그대로다).
    static func isPreChangeTemplate(createdAt: Date,
                                    windowClosedAt: Date? = FoundingSupporter.windowClosedAt) -> Bool {
        guard let windowClosedAt else { return false }
        return createdAt < windowClosedAt
    }

    // MARK: - 흔적 읽기

    /// 흔적을 읽어 판정을 기억해 둔다. 흔적은 전부 과거의 것이라 **한 번만** 보면 된다.
    ///
    /// - Parameter windowJustClosed: 이번 실행에서 개편 버전의 창이 처음 닫혔는가.
    ///   `FoundingSupporter.refreshFromCurrentState` **전에** 창이 비어 있었는지로 알아낸다.
    static func refresh(context: ModelContext,
                        windowJustClosed: Bool,
                        priorTimerStarts: Double = UsageMetrics.value(.timerStarts),
                        windowClosedAt: Date? = FoundingSupporter.windowClosedAt) {
        guard !isEligible, !defaults.bool(forKey: checkedKey) else { return }

        var templateQuery = FetchDescriptor<Timer>(sortBy: [SortDescriptor(\.createdAt)])
        templateQuery.fetchLimit = 1
        var recordQuery = FetchDescriptor<TimerRecord>(sortBy: [SortDescriptor(\.date)])
        recordQuery.fetchLimit = 1
        // 조회가 실패하면 판정을 미룬다 — "흔적 없음"으로 적어 두면 영영 다시 보지 않는다.
        guard let templates = try? context.fetch(templateQuery),
              let records = try? context.fetch(recordQuery) else { return }

        let eligible = hasPreChangeEvidence(
            windowClosedAt: windowClosedAt,
            windowJustClosed: windowJustClosed,
            priorTimerStarts: priorTimerStarts,
            legacyKeysPresent: legacyOnlyKeys.contains { defaults.object(forKey: $0) != nil },
            earliestTemplate: templates.first?.createdAt,
            earliestRecord: records.first?.date
        )
        defaults.set(true, forKey: checkedKey)
        if eligible { defaults.set(true, forKey: eligibleKey) }
    }

    // MARK: - 테스트 지원

    #if DEBUG
    static func resetForTesting() {
        defaults.removeObject(forKey: eligibleKey)
        defaults.removeObject(forKey: checkedKey)
        defaults.removeObject(forKey: announcedKey)
    }
    #endif
}
