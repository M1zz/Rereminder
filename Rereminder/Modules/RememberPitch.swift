//
//  RememberPitch.swift
//  Rereminder
//
//  **"앱이 기억한다"를 무료 사용자에게 보여 주는 세 자리** — 판정만 한다(화면은 부르는 쪽).
//
//  Pro 가 파는 한 문장은 "앱이 당신의 설정을 기억한다"인데, 무료 사용자는 그 가치를 **겪을 길이
//  없었다.** 콜드 런치에 다이얼이 조용히 기본값으로 돌아가고, 반복 감지 제안은 무료에게 뜨지
//  않았다. 사용자는 "원래 그런 앱"이라고 생각하고, 자기가 Pro 가 필요한 사람인 줄 모른다.
//  그래서 사용자가 **방금 겪은 불편에 이름을 붙이는** 자리 세 곳을 둔다:
//
//   ① **다시 연 순간의 한 줄**(`recallLine`) — "지난번엔 25:00, 알림 3개였어요. Pro 는 이걸 기억해 둡니다."
//      다이얼 아래 한 줄이고 모달이 아니다. 하루 한 번, 통틀어 `maxRecallDays` 일까지.
//   ② **반복 감지 제안**(`RepeatDetector.shouldPropose(canSave:)`) — 무료에게도 **한 번** 띄운다.
//      "이 설정을 기억해 둘까"를 가장 강하게 느끼는 순간이다.
//   ③ **다음 자리 전날**(`eveBookingToPrepare`) — 예약해 둔 발표 전날에 앱을 열면 그때 설정을
//      다이얼에 올려 준다. Pro 가 매번 하는 일을 이날만 체험시킨다(Pro 에게도 똑같이 올려 준다 —
//      예약 시트가 "이 설정 그대로 준비해 둔다"고 약속했다).
//
//  ⚠️ **①과 ②는 한 번에 띄우지 않는다** — 같은 말을 두 번 하게 된다. ②가 뜨면 ①은 그날 건너뛴다.
//  ⚠️ ③이 다이얼을 채웠으면 ①·②·시간대 제안은 모두 건너뛴다 — 오늘의 주인공은 내일 자리다.
//  ⚠️ 전부 원격 플래그(`RereminderFlag.rememberPitchEnabled`)로 끌 수 있다. ③의 **설정 올려 주기**는
//     약속이므로 끄지 않고, 끄면 Pro 권유 문구만 빠진다.
//

import Foundation

enum RememberPitch {

    // MARK: - 정책

    /// 다시 연 순간의 한 줄을 **며칠까지** 보일까. 날마다 뜨면 잔소리다 — 일주일이면 알 사람은 안다.
    static let maxRecallDays = 7

    /// ⚠️ 테스트에서 갈아 끼운다.
    static var defaults: UserDefaults = .standard
    static var calendar: Calendar = .current

    private static let recallLastDayKey = "rememberPitch.recall.lastDay"
    private static let recallDaysKey = "rememberPitch.recall.days"
    private static let evePreparedKey = "rememberPitch.eve.preparedOccasion"

    // MARK: - ① 다시 연 순간의 한 줄

    /// 지금 "지난번엔 이랬어요"라는 한 줄을 띄울까.
    ///
    /// - Parameters:
    ///   - lastUsed: 마지막으로 쓴 설정(무료에서도 저장은 계속 한다).
    ///   - canRemember: Pro 인가. Pro 는 이미 복원됐으니 말할 것이 없다.
    ///   - isAtDefaultSetup: 다이얼이 기본값 그대로인가. 이미 바꿨으면 늦었다.
    /// - Returns: 띄울 설정. 띄우지 않으면 nil.
    static func recallLine(lastUsed: RepeatDetector.Config?,
                           canRemember: Bool,
                           isAtDefaultSetup: Bool,
                           defaultConfig: RepeatDetector.Config,
                           now: Date = Date()) -> RepeatDetector.Config? {
        guard !canRemember, isAtDefaultSetup else { return nil }
        guard let lastUsed, lastUsed.mainSec > 0 else { return nil }
        // 마지막 설정이 곧 기본값이면 잃은 것이 없다.
        guard lastUsed != defaultConfig else { return nil }

        let today = LocalDay.stamp(now, calendar: calendar)
        if let last = defaults.object(forKey: recallLastDayKey) as? Int, last == today { return nil }
        guard recallDays < maxRecallDays else { return nil }
        return lastUsed
    }

    static var recallDays: Int { defaults.integer(forKey: recallDaysKey) }

    /// 한 줄을 띄웠다 — **같은 날에는 다시 세지 않는다**(하루 한 번).
    static func markRecallShown(now: Date = Date()) {
        let today = LocalDay.stamp(now, calendar: calendar)
        if let last = defaults.object(forKey: recallLastDayKey) as? Int, last == today { return }
        defaults.set(today, forKey: recallLastDayKey)
        defaults.set(recallDays + 1, forKey: recallDaysKey)
    }

    // MARK: - ③ 다음 자리 전날

    /// 지금이 예약한 자리의 **전날 저녁부터 그날이 끝날 때까지**이고, 아직 다이얼에 올려 주지
    /// 않았으면 그 예약을 돌려준다.
    ///
    /// 알림을 탭하지 않고 앱을 직접 열어도 같다 — 알림을 놓친 사람이 더 도움이 필요하다.
    static func eveBookingToPrepare(_ booking: NextOccasionReminder.Booking?,
                                    now: Date = Date()) -> NextOccasionReminder.Booking? {
        guard let booking, booking.mainSec > 0 else { return nil }
        guard let fireDate = NextOccasionReminder.Booking.fireDate(for: booking.occasionDate, calendar: calendar),
              let dayAfter = calendar.date(byAdding: .day, value: 1,
                                           to: calendar.startOfDay(for: booking.occasionDate))
        else { return nil }
        guard now >= fireDate, now < dayAfter else { return nil }

        let stamp = booking.occasionDate.timeIntervalSince1970
        if let prepared = defaults.object(forKey: evePreparedKey) as? Double, prepared == stamp { return nil }
        return booking
    }

    /// 올려 줬다 — 같은 예약으로는 다시 덮지 않는다(사용자가 그 뒤에 바꾼 것을 지우면 안 된다).
    static func markEvePrepared(_ booking: NextOccasionReminder.Booking) {
        defaults.set(booking.occasionDate.timeIntervalSince1970, forKey: evePreparedKey)
    }

    #if DEBUG
    static func resetForTesting() {
        for key in [recallLastDayKey, recallDaysKey, evePreparedKey] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
