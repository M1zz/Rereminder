//
//  OnboardingUseCase.swift
//  Rereminder
//
//  온보딩에서 고르는 **"어디에 쓸 건가요"** — 그리고 그 답에 맞춘 타이머 한 벌.
//
//  왜 묻나: 이 앱의 값은 "끝나기 전에 여러 번 알려 준다"인데, 그게 왜 좋은지는 **자기 상황에
//  대입해야** 안다. 발표하는 사람에게 5분 전·1분 전은 살길이고, 요리하는 사람에게는 뒤집을
//  시간이다. 그래서 상황을 먼저 고르게 하고, 그 상황의 타이머를 바로 굴려 보여 준다.
//
//  "아직 모르겠다"도 답이다 — 그때는 우리가 기본 한 벌을 권한다(고르지 않아도 막히지 않게).
//
//  ⚠️ **여기 있는 상황이 곧 "이 앱은 누구 것인가"의 선언이다.** 앱을 처음 연 사람은 이 목록에서
//     자기를 찾고, 못 찾으면 자기 앱이 아니라고 결론 내린다. 그래서 **돈을 내는 사람**(남 앞에서
//     시간을 운영하는 사람 — 발표자·강사·퍼실리테이터)을 맨 위에 둔다.
//
//  ⚠️ **요리는 뺐다 — 되살리지 말 것.** "헤이 시리, 8분 타이머"를 이길 수 없는 싸움이고,
//     그 카드를 고른 사람은 이틀 뒤 앱을 지운다. 이기지 못하는 상황으로 신규 사용자를
//     안내하는 것은 획득이 아니라 이탈 비용이다.
//
//  ⚠️ 추천 값은 **알림이 두 개 이상**이 되게 잡는다. 하나짜리는 이 앱을 쓸 이유가 없는 설정이라
//     체험에서 보여 줄 것이 없다(단, "아직 모르겠다"만 기본 설정 그대로 하나다).
//

import Foundation

struct OnboardingUseCase: Identifiable, Hashable {
    let id: String
    /// SF Symbol
    let symbol: String
    let title: String
    /// 이 상황에서 알림이 왜 필요한지 — 한 줄.
    let reason: String
    let minutes: Int
    /// 종료까지 **남은 시간** 기준 알림 지점(초). 링·종의 좌표와 같다.
    let alerts: [Int]
    /// 발표처럼 구간에 이름이 있는 상황이면 채운다(없으면 빈 배열).
    let sectionNames: [String]

    var totalSeconds: Int { minutes * 60 }

    /// "10분 · 종료 5·1분 전에 알림" — 카드에 붙는 설정 요약.
    var setupSummary: String {
        let list = alerts.sorted(by: >).map { minutesText($0) }.joined(separator: "·")
        return String(localized: "\(minutes) min · alerts \(list) min before the end")
    }

    private func minutesText(_ seconds: Int) -> String {
        seconds % 60 == 0 ? "\(seconds / 60)" : String(format: "%.1f", Double(seconds) / 60)
    }

    // MARK: - 우리가 권하는 상황들

    static let all: [OnboardingUseCase] = [
        OnboardingUseCase(
            id: "presentation",
            symbol: "person.wave.2.fill",
            title: String(localized: "Presentation"),
            reason: String(localized: "Know when to wrap up without looking at a clock."),
            minutes: 10,
            alerts: [300, 60],
            sectionNames: [String(localized: "Intro"),
                           String(localized: "Main"),
                           String(localized: "Wrap-up")]
        ),
        // 수업·워크숍이 이 앱의 주 고객이다 — 매주 되풀이하고, 구간·템플릿·워치를 전부 쓴다.
        OnboardingUseCase(
            id: "class",
            symbol: "person.3.fill",
            title: String(localized: "Class"),
            reason: String(localized: "Keep the cool-down from getting squeezed."),
            minutes: 50,
            alerts: [2400, 600],
            sectionNames: [String(localized: "Warm-up"),
                           String(localized: "Main work"),
                           String(localized: "Cool-down")]
        ),
        OnboardingUseCase(
            id: "workshop",
            symbol: "rectangle.split.3x1.fill",
            title: String(localized: "Workshop"),
            reason: String(localized: "Six sessions, and the last one still gets its time."),
            minutes: 90,
            alerts: [4800, 3000, 1200, 300],
            sectionNames: [String(localized: "Opening"),
                           String(localized: "Session 1"),
                           String(localized: "Session 2"),
                           String(localized: "Wrap-up"),
                           String(localized: "Closing")]
        ),
        OnboardingUseCase(
            id: "workout",
            symbol: "figure.run",
            title: String(localized: "Workout"),
            reason: String(localized: "One more set, then cool down — without counting."),
            minutes: 20,
            alerts: [600, 60],
            sectionNames: []
        ),
        OnboardingUseCase(
            id: "focus",
            symbol: "brain.head.profile",
            title: String(localized: "Focus"),
            reason: String(localized: "Ease out of deep work instead of being cut off."),
            minutes: 25,
            alerts: [300, 60],
            sectionNames: []
        ),
        OnboardingUseCase(
            id: "meeting",
            symbol: "person.2.fill",
            title: String(localized: "Meeting"),
            reason: String(localized: "Land the agenda on time — 10, 5, and 1 minute out."),
            minutes: 30,
            alerts: [600, 300, 60],
            sectionNames: []
        ),
        OnboardingUseCase(
            id: "unsure",
            symbol: "sparkles",
            title: String(localized: "Not sure yet"),
            reason: String(localized: "Start with our default and change it later."),
            minutes: 10,
            alerts: [300, 60],
            sectionNames: []
        )
    ]

    static var suggested: OnboardingUseCase { all[0] }
}
