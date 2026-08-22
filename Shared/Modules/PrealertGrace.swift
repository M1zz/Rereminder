//
//  PrealertGrace.swift
//  Rereminder
//
//  **한도에 막힌 순간에 내주는 하루 한 번의 유예.**
//
//  한도에 막히는 순간은 사용자가 이 앱의 가치를 가장 강하게 원하는 순간이다. 그 자리에서
//  페이월로 문을 닫으면 얻는 것은 결제가 아니라 "이 앱은 안 되는 앱"이라는 인상이다.
//  한 번 내주면 원하던 것을 손에 넣은 채로 "다음부터는 Pro"를 듣게 되고, 그 문장이 훨씬 잘 팔린다.
//
//  **하루 한 번**으로 묶는다 — 무제한이면 게이트가 없는 것과 같고, 아예 없으면 위의 이탈이 난다.
//  날짜만 저장하므로 시계를 되돌리면 다시 받을 수 있는데, 그걸 막자고 서버를 붙일 값은 아니다.
//
//  ⚠️ 이 유예를 받은 사람이 나중에 결제하는지가 이 설계의 유일한 판정 기준이다 —
//     `AnalyticsManager.prealertGraceGranted` + `UsageMetrics.graceGrants` 로 잰다.
//

import Foundation

enum PrealertGrace {

    /// `TrialCounter` 와 같은 저장소를 쓴다 — 체험 상태와 유예가 다른 곳에 있으면 초기화가 갈라진다.
    static var defaults: UserDefaults { TrialCounter.defaults }

    private static let lastGrantedDayKey = "prealert.grace.lastGrantedDay"

    /// "오늘 이미 받았나"만 알면 된다 — **사용자의 달력 기준**으로 센다.
    /// (UTC 로 세면 한국에서는 오전 9시에 하루가 바뀌어, 아침에 받은 유예가 그날 오전에 또 열린다.)
    private static func dayStamp(_ date: Date) -> Int { LocalDay.stamp(date) }

    /// 오늘 아직 유예를 안 썼는가.
    static func isAvailable(now: Date = Date()) -> Bool {
        let last = defaults.object(forKey: lastGrantedDayKey) as? Int
        guard let last else { return true }
        return last != dayStamp(now)
    }

    /// 편의 프로퍼티 — 판정 시점을 넘길 일이 없는 호출부용.
    static var isAvailable: Bool { isAvailable() }

    /// 오늘치를 쓴다.
    static func consume(now: Date = Date()) {
        defaults.set(dayStamp(now), forKey: lastGrantedDayKey)
    }

    static func reset() {
        defaults.removeObject(forKey: lastGrantedDayKey)
    }
}
