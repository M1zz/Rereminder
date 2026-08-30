//
//  NextOccasionReminder.swift
//  Rereminder
//
//  **"다음 발표 언제세요?"** — 석 달 뒤에 앱을 기억해 주길 기대하지 않는다.
//
//  왜 필요한가: 이 앱에 돈을 낼 사람 중 하나(학회 발표자·분기 워크숍 진행자)는 아픔은 강한데
//  **주기가 길다.** 발표에서 잘린 그날 저녁에 앱을 깔고, 전날 리허설에서 잘 쓰고, 그리고
//  석 달 동안 앱을 열지 않는다. 그 사이 앱은 알림 한 번 보내지 않고 홈 화면 세 번째 페이지에서
//  잊힌다. 다음 발표가 잡히면 그는 **같은 검색을 다시 해서 다른 앱을 깐다.**
//
//  ⚠️ `RepeatDetector` 로는 이 사람을 못 잡는다 — 그쪽은 **주 단위 반복**(같은 요일·시각)을
//     보는 장치라 분기 주기에는 영영 걸리지 않는다. 그래서 별도 장치가 필요하다.
//
//  방식: 세션을 끝까지 마친 직후 **한 번** 묻고, 사용자가 날짜를 고르면 **그 전날 저녁**에
//  로컬 알림을 건다. 알림을 열면 그때 쓰던 설정이 다이얼에 그대로 올라온다(리허설을 바로 시작).
//
//  ⚠️ **잔소리가 되면 이 기능은 실패다.** 네 겹으로 막는다:
//    1. **세션 모드로 완주했을 때만** 묻는다 — 남 앞에서 시간을 운영한 사람에게만 "다음 자리"가 있다.
//    2. **주 단위로 반복하는 사람에게는 묻지 않는다** — 그 사람은 알아서 돌아온다(`RepeatDetector`).
//    3. 예약이 **이미 있으면** 묻지 않는다. 거절하면 완주 `declineCooldown` 회 동안 쉰다.
//    4. 전체 `maxAsks` 회 상한.
//

import Foundation
import UserNotifications

enum NextOccasionReminder {

    // MARK: - 예약 한 건

    struct Booking: Codable, Equatable {
        /// 사용자가 고른 "그날".
        let occasionDate: Date
        /// 그때 쓰던 설정 — 알림을 열면 이대로 다이얼에 오른다.
        let mainSec: Int
        let offsets: [Int]

        /// 실제로 알림이 울리는 시각 = **하루 전 저녁**.
        /// 발표 전날 저녁이 리허설 시간대다 — 당일 아침에 알려 봐야 고칠 수 있는 게 없다.
        static func fireDate(for occasion: Date, calendar: Calendar = .current) -> Date? {
            guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: occasion) else { return nil }
            return calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: dayBefore)
        }
    }

    /// 전날 몇 시에 알릴까. 저녁 7시 — 퇴근 뒤 리허설을 도는 시간대.
    static let reminderHour = 19

    /// 알림 식별자. 한 건만 유지하므로 고정값이다(다시 예약하면 덮어쓴다).
    static let notificationID = "rereminder.nextOccasion"

    // MARK: - 상한

    /// 이 질문을 통틀어 몇 번까지 할까.
    static let maxAsks = 3
    /// 거절당한 뒤 몇 번 더 완주해야 다시 물을까.
    static let declineCooldown = 5

    // MARK: - 저장

    /// ⚠️ 테스트에서 갈아 끼운다 — 실제 저장소를 쓰면 시뮬레이터에 남은 값이 새어 들어온다.
    static var defaults: UserDefaults = .standard
    static var calendar: Calendar = .current

    private static let bookingKey = "nextOccasion.booking"
    private static let askCountKey = "nextOccasion.askCount"
    private static let declinedAtKey = "nextOccasion.declinedAtCompletions"

    /// 지금 잡혀 있는 다음 자리(없으면 nil).
    static var booking: Booking? {
        get {
            guard let data = defaults.data(forKey: bookingKey) else { return nil }
            return try? JSONDecoder().decode(Booking.self, from: data)
        }
        set {
            guard let newValue else {
                defaults.removeObject(forKey: bookingKey)
                return
            }
            defaults.set(try? JSONEncoder().encode(newValue), forKey: bookingKey)
        }
    }

    static var askCount: Int { defaults.integer(forKey: askCountKey) }

    // MARK: - 물을 차례인가

    /// 지금 "다음 자리가 언제인지" 물어도 되는가.
    ///
    /// - Parameters:
    ///   - didUseSessionMode: 방금 끝낸 것이 **세션 모드**였나. 아니면 묻지 않는다.
    ///   - completions: 지금까지 완주한 총 횟수(거절 유예를 세는 자).
    ///   - repeatsWeekly: 주 단위로 되풀이하는 사람인가(`RepeatDetector` 가 안다).
    ///   - now: 판정 시각.
    static func shouldAsk(didUseSessionMode: Bool,
                          completions: Int,
                          repeatsWeekly: Bool,
                          now: Date = Date()) -> Bool {
        // ① 남 앞에서 시간을 운영한 사람에게만 "다음 자리"가 있다.
        guard didUseSessionMode else { return false }
        // ② 주 단위로 돌아오는 사람은 알아서 온다 — 물으면 잔소리다.
        guard !repeatsWeekly else { return false }
        // ③ 아직 지나지 않은 예약이 있으면 물을 것이 없다.
        if let booking, booking.occasionDate > now { return false }
        guard askCount < maxAsks else { return false }

        // ④ 거절한 뒤에는 몇 번 더 완주할 때까지 쉰다.
        if let declinedAt = defaults.object(forKey: declinedAtKey) as? Int,
           completions - declinedAt < declineCooldown {
            return false
        }
        return true
    }

    /// 물었다는 사실을 남긴다 — 답이 무엇이든 상한은 소모된다.
    static func markAsked() {
        defaults.set(askCount + 1, forKey: askCountKey)
    }

    /// "다음 자리 없어요" — 그다음 유예를 건다.
    static func decline(completions: Int) {
        defaults.set(completions, forKey: declinedAtKey)
    }

    // MARK: - 예약

    /// 고른 날짜의 **전날 저녁**에 로컬 알림을 건다. 기존 예약은 덮어쓴다.
    /// - Returns: 실제로 걸렸으면 `true`. 전날 저녁이 이미 지났으면 걸지 않는다.
    @discardableResult
    static func book(occasion: Date,
                     mainSec: Int,
                     offsets: [Int],
                     now: Date = Date(),
                     center: UNUserNotificationCenter = .current()) -> Bool {
        guard let fireDate = Booking.fireDate(for: occasion, calendar: calendar),
              fireDate > now else { return false }

        booking = Booking(occasionDate: occasion, mainSec: mainSec, offsets: offsets.sorted(by: >))

        let content = UNMutableNotificationContent()
        content.title = AppName.notification
        content.body = String(localized: "Tomorrow's the day. Want to run through it once?")
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.add(request) { error in
            if let error { print("❌ 다음 자리 알림 예약 실패: \(error)") }
        }
        return true
    }

    /// 날짜가 지난 예약을 치운다. 앱을 열 때 부른다 —
    /// 남겨 두면 `shouldAsk` 가 영영 "예약이 있다"고 판단해 다시 묻지 않는다.
    static func clearIfPassed(now: Date = Date()) {
        guard let booking, booking.occasionDate <= now else { return }
        self.booking = nil
    }

    /// 사용자가 예약을 스스로 취소했을 때.
    static func cancel(center: UNUserNotificationCenter = .current()) {
        booking = nil
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    // MARK: - 고를 수 있는 날짜

    /// 날짜 선택의 하한 — **모레부터.** 알림은 전날 저녁에 울리므로 내일 자리는 이미 늦었다.
    static func earliestSelectableDate(now: Date = Date()) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 2, to: today) ?? now
    }

    #if DEBUG
    static func resetForTesting() {
        defaults.removeObject(forKey: bookingKey)
        defaults.removeObject(forKey: askCountKey)
        defaults.removeObject(forKey: declinedAtKey)
    }
    #endif
}
