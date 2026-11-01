//
//  FreeUse.swift
//  Rereminder
//
//  **먼저 충분히 써 보고, 그 뒤에 처음으로 묻는다.** 문턱에 닿을 때까지는 모든 기능이 열려 있다.
//
//  왜: 결제를 망설이는 까닭은 이 앱이 그만한 값을 하는지 모르기 때문이고, 그건 써 봐야 안다.
//  첫날부터 벽을 세우면 증거가 쌓이기 전에 묻게 된다(클립키보드 `FreeUse` 와 같은 생각).
//
//  ⚠️ **횟수가 아니라 서로 다른 날로 센다.** 횟수로 세면 하루 네 번 도는 포모도로가 먼저 닿고,
//     주 3회 수업하는 강사(= 돈을 낼 사람)가 가장 늦게 닿는다. `RepeatDetector` 와 같은 이유다.
//     세션 완주 조건을 함께 두는 것은 분기마다 발표하는 사람이 날수로는 닿지 않기 때문이다.
//  ⚠️ **"체험"이라고 부르지 않는다.** 기간으로 끝나는 체험이 아니라 쓴 만큼으로 끝나는 무료 사용이다.
//  ⚠️ **`StoreManager.isProUser` 에 섞지 말 것.** 창단 후원자 판정이 "첫 실행에 이미 Pro"를 결제로 보고,
//     `flag.isPaid` 도 그 값을 읽는다. 섞으면 새로 깐 사람에게 평생 혜택이 나간다.
//     판정은 `ProGate` 에서 한다.
//  ⚠️ **문턱은 지금까지 있던 권리를 깎지 않는다.** 무료 기간에는 5+5 카운터를 태우지 않으므로,
//     문턱 뒤에도 그 사람이 원래 갖고 있던 횟수가 그대로 남는다. `FreeUseTests` 가 지킨다.
//

import Foundation

enum FreeUse {

    /// 완주한 서로 다른 날이 이만큼이면 문턱이다.
    static let dayThreshold = 14
    /// 세션 모드로 완주한 횟수가 이만큼이면 문턱이다.
    static let sessionThreshold = 5
    /// 문턱 뒤 무료에서 보이는 기록의 범위. 문턱 전에 쌓인 기록은 이와 무관하게 계속 보인다.
    static let recentHistoryDays = 30

    /// 테스트 시 격리된 UserDefaults 주입을 위해 var 로 둠. 프로덕션에서는 변경하지 않음.
    static var defaults: UserDefaults = .standard

    private static let daysKey = "freeUse.days"
    private static let lastDayKey = "freeUse.lastDay"
    private static let sessionsKey = "freeUse.sessions"
    private static let reachedAtKey = "freeUse.reachedAt"
    private static let announcedKey = "freeUse.announced"

    /// 완주한 서로 다른 날의 수. 줄지 않는다.
    static var days: Int { defaults.integer(forKey: daysKey) }
    /// 세션 모드로 완주한 횟수. 줄지 않는다.
    static var sessions: Int { defaults.integer(forKey: sessionsKey) }

    /// 문턱을 넘은 시각. 한 번 적히면 지우지 않는다.
    static var reachedAt: Date? { defaults.object(forKey: reachedAtKey) as? Date }

    /// 아직 무료 기간인가.
    static var isActive: Bool { reachedAt == nil }

    /// 타이머를 끝까지 마쳤다. `TimerUnifiedView` 한 곳에서만 부른다(다른 곳에서 세면 두 번 센다).
    static func recordCompletion(isSession: Bool, now: Date = Date()) {
        let today = LocalDay.stamp(now)
        if defaults.object(forKey: lastDayKey) == nil || defaults.integer(forKey: lastDayKey) != today {
            defaults.set(today, forKey: lastDayKey)
            defaults.set(days + 1, forKey: daysKey)
        }
        if isSession { defaults.set(sessions + 1, forKey: sessionsKey) }
        if isActive, days >= dayThreshold || sessions >= sessionThreshold {
            defaults.set(now, forKey: reachedAtKey)
        }
    }

    // MARK: - 문턱에 닿았다는 안내

    /// 문턱 안내를 띄울 차례인가. 이미 돈을 낸 사람에게는 할 말이 없다.
    static func shouldAnnounce(isPaid: Bool) -> Bool {
        !isActive && !isPaid && !defaults.bool(forKey: announcedKey)
    }

    static func markAnnounced() {
        defaults.set(true, forKey: announcedKey)
    }

    // MARK: - 기록

    /// 문턱 뒤 무료 사용자에게 이 기록이 보이는가. 문턱 전 기록은 그 사람이 이미 보던 것이라 계속 보인다.
    static func isRecordVisible(date: Date, now: Date = Date()) -> Bool {
        guard let reachedAt else { return true }
        if date <= reachedAt { return true }
        return date >= now.addingTimeInterval(-Double(recentHistoryDays) * 86_400)
    }

    #if DEBUG
    /// 테스트에서 문턱을 이미 넘은 상태로 만든다.
    static func markReachedForTesting(at date: Date = Date()) {
        defaults.set(date, forKey: reachedAtKey)
    }

    static func resetForTesting() {
        for key in [daysKey, lastDayKey, sessionsKey, reachedAtKey, announcedKey] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
