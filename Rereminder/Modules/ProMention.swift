//
//  ProMention.swift
//  Rereminder
//
//  **무료 사용자에게 Pro 를 먼저 꺼내는 횟수의 예산** — 자리가 여럿이어도 예산은 하나다.
//
//  왜: "앱이 기억한다"를 알리는 자리가 늘어나면서(다시 연 순간의 한 줄·반복 저장 제안·손으로 다시
//  맞춘 순간·다음 자리 전날) 자리마다 따로 횟수를 세고 있었다. 하나씩 보면 절제돼 있어도 합치면
//  한 사람이 열 번 넘게 Pro 이야기를 듣는다. 넛지는 **처음 몇 번**이 일을 하고, 그 뒤로는 알아들은
//  사람에게 같은 말을 되풀이하는 잔소리가 된다 — 그리고 잔소리는 결제가 아니라 삭제로 끝난다.
//
//  규칙:
//  - 설치당 **통틀어 `maxMentions` 번**. 자리마다는 **한 번씩**만.
//  - 한 번 말했으면 **`minDaysBetween` 일** 쉰다 — 연달아 이틀 들으면 앱이 조르는 것으로 읽힌다.
//  - **알아들었으면 멈춘다.** 권유를 한 번이라도 눌렀거나(= Pro 가 뭔지 봤다) 페이월을
//    `learnedPaywallViews` 번 봤으면(잠긴 칩을 눌러 본 것 포함) 더는 먼저 꺼내지 않는다.
//  - Pro 는 당연히 대상이 아니다.
//
//  ⚠️ 이 예산은 **앱이 먼저 꺼내는 말**에만 쓴다. 사용자가 잠긴 기능을 눌러 여는 페이월은
//     넛지가 아니라 대답이므로 예산을 쓰지 않는다.
//  ⚠️ 약속은 예산과 무관하다 — 다음 자리 전날 **설정을 다이얼에 올려 주는 일**은 예산이 없어도 한다.
//     빠지는 것은 "이게 Pro 가 하는 일" 이라는 말뿐이다.
//  ⚠️ 달라진 점 안내(`LegacyFreeNotice`)는 권유가 아니라 **설명**이라 예산과 상관없이 한 번 뜨고,
//     뜬 날을 예산에 적어 그 뒤 며칠은 다른 권유가 붙지 않게 한다.
//

import Foundation

enum ProMention {

    /// Pro 를 먼저 꺼내는 자리.
    enum Kind: String, CaseIterable {
        /// 다시 연 순간 다이얼 아래 한 줄 — "지난번엔 25:00 이었어요"
        case recall
        /// 서로 다른 날 반복한 설정 — "Pro 로 기억해 두기"
        case repeatSetup = "repeat"
        /// 기본값으로 돌아간 다이얼을 손으로 지난번 설정에 다시 맞춘 순간
        case reentry
        /// 예약한 자리의 전날 — "이게 Pro 가 매번 하는 일"
        case eve
        /// 개편 전 무료 사용자에게 달라진 점 설명 (예산을 확인하지 않고 날짜만 남긴다)
        case legacy
    }

    // MARK: - 정책

    static let maxMentions = 3
    static let minDaysBetween = 3
    static let learnedPaywallViews = 2

    // MARK: - 저장

    /// ⚠️ 테스트에서 갈아 끼운다.
    static var defaults: UserDefaults = .standard
    static var calendar: Calendar = .current

    private static let countKey = "proMention.count"
    private static let lastDayKey = "proMention.lastDay"
    private static let usedKindsKey = "proMention.usedKinds"
    private static let tappedKey = "proMention.tapped"

    // MARK: - 판정

    /// 지금 이 자리에서 Pro 를 꺼내도 되는가.
    static func canMention(_ kind: Kind,
                           isPro: Bool,
                           paywallViews: Int = Int(UsageMetrics.value(.paywallViews)),
                           now: Date = Date()) -> Bool {
        guard !isPro else { return false }
        guard !defaults.bool(forKey: tappedKey), paywallViews < learnedPaywallViews else { return false }
        guard count < maxMentions, !usedKinds.contains(kind.rawValue) else { return false }
        if let last = defaults.object(forKey: lastDayKey) as? Int,
           LocalDay.stamp(now, calendar: calendar) - last < minDaysBetween {
            return false
        }
        return true
    }

    /// 꺼냈다. 설명(`legacy`)은 날짜만 남기고 예산 횟수는 쓰지 않는다.
    static func markMentioned(_ kind: Kind, now: Date = Date()) {
        defaults.set(LocalDay.stamp(now, calendar: calendar), forKey: lastDayKey)
        guard kind != .legacy else { return }
        var used = usedKinds
        guard !used.contains(kind.rawValue) else { return }
        used.insert(kind.rawValue)
        defaults.set(Array(used), forKey: usedKindsKey)
        defaults.set(count + 1, forKey: countKey)
    }

    /// 권유를 눌러 Pro 가 무엇인지 봤다 — 알아들었으니 더는 먼저 꺼내지 않는다.
    static func markTapped() {
        defaults.set(true, forKey: tappedKey)
    }

    static var count: Int { defaults.integer(forKey: countKey) }

    /// 권유를 한 번이라도 눌렀는가 (스냅샷용).
    static var wasTapped: Bool { defaults.bool(forKey: tappedKey) }

    // MARK: - 문구 실험 — 세션 모드 사용자에게 무엇을 앞세울까

    /// 권유 문구의 갈래.
    ///
    /// 가설: 돈을 내는 사람(발표자·강사·퍼실리테이터)이 실제로 사는 것은 "다이얼을 다시 안 맞춰도
    /// 된다"보다 **세션 운영**(구간 이름·대본)일 수 있다. 그래서 **세션 모드를 써 본 사람만** 반씩
    /// 나눠 한쪽에는 지금 문구(`remember`), 다른 쪽에는 세션을 앞세운 문구(`session`)를 보여 준다.
    /// 세션 모드를 안 쓴 사람은 실험 대상이 아니다 — 그들에게 구간 이야기는 뜬금없다.
    ///
    /// ⚠️ **한 번 정해진 갈래는 바뀌지 않는다.** 바뀌면 결제가 어느 문구 덕인지 가를 수 없다.
    /// ⚠️ 판정 기준은 이벤트가 아니라 스냅샷(`flag.pitchCopySession` / `flag.pitchCopyRemember`)
    ///    × `flag.isPaid` 다 — 이벤트 슬라이스는 뷰어 퍼널에서 한 단계로 합쳐진다.
    /// ⚠️ 바꾸는 것은 권유 **문구**뿐이다. 페이월·예산·빈도는 두 갈래가 같아야 비교가 된다.
    enum CopyVariant: String {
        case remember
        case session
    }

    private static let variantKey = "proMention.copyVariant"

    /// 이 설치의 문구 갈래. 세션 모드를 써 본 적이 없으면 `nil`(실험 밖 — 지금 문구를 쓴다).
    static func copyVariant(usedSessionMode: Bool = Self.usedSessionMode,
                            coinFlip: () -> Bool = { Bool.random() }) -> CopyVariant? {
        if let raw = defaults.string(forKey: variantKey), let variant = CopyVariant(rawValue: raw) {
            return variant
        }
        guard usedSessionMode else { return nil }
        let variant: CopyVariant = coinFlip() ? .session : .remember
        defaults.set(variant.rawValue, forKey: variantKey)
        return variant
    }

    /// 이미 정해진 갈래만 읽는다(스냅샷용 — 여기서 새로 정하지 않는다).
    static var assignedCopyVariant: CopyVariant? {
        defaults.string(forKey: variantKey).flatMap(CopyVariant.init(rawValue:))
    }

    /// 세션 모드를 써 본 적이 있는가 — 완주 기록이든 체험 사용이든.
    static var usedSessionMode: Bool {
        UsageMetrics.value(.presentationRuns) > 0 || TrialCounter.count(for: .presentationMode) > 0
    }

    /// 세션을 앞세운 문구를 쓸 차례인가.
    static var usesSessionCopy: Bool { copyVariant() == .session }

    private static var usedKinds: Set<String> {
        Set(defaults.stringArray(forKey: usedKindsKey) ?? [])
    }

    #if DEBUG
    static func resetForTesting() {
        for key in [countKey, lastDayKey, usedKindsKey, tappedKey, variantKey] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
