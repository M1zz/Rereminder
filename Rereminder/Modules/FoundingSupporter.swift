//
//  FoundingSupporter.swift
//  Rereminder
//
//  **창단 후원자** — 이 앱이 아직 아무것도 아니었을 때 값을 치른 사람들.
//
//  왜 만드나: 곧 파는 물건의 축이 바뀌고(알림 개수 → 세션 운영) 가격도 오른다. 그때
//  "먼저 산 사람이 손해를 봤다"가 되면 그 사람들은 두 번 다시 이 앱을 편들지 않는다.
//  그래서 **바꾸기 전에** 먼저 약속을 걸어 둔다 — *앞으로 생기는 유료 기능은 전부, 값 없이.*
//
//  ⚠️ 이 약속은 되돌릴 수 없다. 한 번 부여한 자격은 **어떤 경우에도 회수하지 않는다**
//     (`grant` 만 있고 revoke 가 없는 이유). 나중에 유료 기능을 추가할 때 게이트에서
//     `FoundingSupporter.isFounder` 를 반드시 함께 볼 것 — 그러지 않으면 이 파일은
//     지키지 않은 약속의 기록이 된다.
//
//  경계는 **"이 버전을 처음 실행한 순간"**(`windowClosedAt`)이다. 날짜 상수를 찍지 않는 이유:
//  출시일은 심사·재제출로 밀리는데 상수는 안 밀린다. 하루만 어긋나도 옛 가격에 산 사람이
//  자격에서 빠지거나, 새 가격에 산 사람이 평생 무료를 받는다.
//
//  ⚠️ **그래서 이 파일은 모델 변경과 반드시 같은 릴리즈에 나가야 한다.** 먼저 내보내면 그
//     시점에 창이 닫혀, 그 뒤 변경 전까지 옛 가격에 산 사람이 자격을 못 받는다.
//
//  판정은 세 갈래다:
//  - **이 버전 첫 실행에 이미 Pro** → 결제는 반드시 그보다 앞이다 → 창단 후원자.
//    StoreKit 없이도 참이라 오프라인·콜드런치에서 자격을 놓치지 않는다.
//  - **StoreKit 의 `originalPurchaseDate` 가 `windowClosedAt` 보다 앞** → 창단 후원자.
//    재설치·기기 교체로 복원해도 결제 시각은 그대로라 자격이 살아 돌아온다.
//  - **그랜드파더링된 기존 사용자**(Pro 도입 전부터 쓰던 사람)도 같은 대접이다.
//    이미 "평생 무료"라고 말해 뒀고, 그 말의 범위를 나중에 좁히는 건 약속을 깨는 것이다.
//
//  저장은 Keychain + UserDefaults 두 벌이다. Keychain 은 앱을 지워도 남아서, 재설치한 사람이
//  복원하기 전에도 자격과 **창이 닫힌 시각**을 알아본다 — 시각까지 남겨야 새 가격에 산 사람이
//  재설치·복원으로 자격을 주워 가지 못한다.
//

import Foundation
import StoreKit

enum FoundingSupporter {

    // MARK: - 어디서 온 자격인가

    enum Origin: String {
        /// 값을 치르고 산 사람.
        case purchased
        /// Pro 도입 전부터 쓰던 사람 (이미 "평생 무료"를 약속했다).
        case grandfathered
    }

    // MARK: - 창이 닫힌 시각

    /// 이 버전을 **처음 실행한 순간**. 이보다 앞선 결제만 창단 후원자가 된다.
    ///
    /// 한 번 적히면 바뀌지 않는다. Keychain 에도 함께 남겨 앱을 지웠다 다시 깔아도
    /// 같은 경계를 쓴다 — 그러지 않으면 새 가격에 산 사람이 재설치·복원만으로 자격을 얻는다.
    static var windowClosedAt: Date? {
        if let stored = defaults.object(forKey: windowKey) as? Date { return stored }
        if let raw = keychainReadString(windowKey), let date = Self.formatter.date(from: raw) {
            defaults.set(date, forKey: windowKey)
            return date
        }
        return nil
    }

    /// 창이 아직 열려 있으면 지금으로 닫는다.
    /// - Returns: 이번 호출로 처음 닫혔으면 `true` — 그 순간 Pro 인 사람이 창단 후원자다.
    @discardableResult
    static func closeWindowIfNeeded(now: Date = Date()) -> Bool {
        guard windowClosedAt == nil else { return false }
        defaults.set(now, forKey: windowKey)
        keychainWriteString(windowKey, Self.formatter.string(from: now))
        return true
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - 저장

    private static let keychainKey = "rereminder.founder"
    private static let originKey = "rereminder.founder.origin"
    private static let announcedKey = "rereminder.founder.announced"
    private static let windowKey = "rereminder.founder.window"

    /// ⚠️ 테스트에서 갈아 끼운다 — 실제 저장소를 쓰면 시뮬레이터에 남은 값이 새어 들어온다.
    static var defaults: UserDefaults = .standard

    /// Keychain 접근을 한 겹 감싼다. 자격은 앱을 지워도 살아남아야 해서 Keychain 을 쓰는데,
    /// 바로 그 성질 때문에 테스트에서는 이전 실행의 값이 그대로 남는다 — 그래서 주입 가능하게 둔다.
    static var keychainRead: (String) -> Bool? = { KeychainHelper.load(key: $0) }
    static var keychainWrite: (String, Bool) -> Void = { _ = KeychainHelper.save(key: $0, value: $1) }
    static var keychainClear: (String) -> Void = { KeychainHelper.delete(key: $0) }
    static var keychainReadString: (String) -> String? = { KeychainHelper.loadString(key: $0) }
    static var keychainWriteString: (String, String) -> Void = { _ = KeychainHelper.save(key: $0, value: $1) }

    // MARK: - 상태

    /// 창단 후원자인가.
    static var isFounder: Bool { origin != nil }

    /// 자격의 출처. 없으면 창단 후원자가 아니다.
    ///
    /// Keychain 이 참인데 출처 기록이 없으면(앱을 지웠다 다시 깐 경우) `.purchased` 로 본다 —
    /// 자격은 살아 있는데 출처만 잃은 상황이고, 그때 자격을 없애는 건 약속을 깨는 것이다.
    static var origin: Origin? {
        if let raw = defaults.string(forKey: originKey), let origin = Origin(rawValue: raw) {
            return origin
        }
        if keychainRead(keychainKey) == true {
            defaults.set(Origin.purchased.rawValue, forKey: originKey)
            return .purchased
        }
        return nil
    }

    // MARK: - 부여 (회수는 없다)

    /// 자격을 부여한다. 이미 있으면 아무것도 하지 않는다 — **덮어쓰지도, 회수하지도 않는다.**
    /// - Returns: 이번 호출로 새로 부여됐으면 `true`.
    @discardableResult
    static func grant(_ origin: Origin) -> Bool {
        guard !isFounder else { return false }
        defaults.set(origin.rawValue, forKey: originKey)
        keychainWrite(keychainKey, true)
        return true
    }

    /// StoreKit 이 알려 준 **최초 결제 시각**으로 판정한다.
    /// 재설치·기기 교체로 복원해도 이 값은 원래 결제 시각을 유지하므로,
    /// 한참 뒤에 복원하더라도 자격이 되살아난다.
    ///
    /// 창이 아직 닫히지 않았으면 판정하지 않는다 — 경계가 없으면 비교할 것이 없다.
    /// (`refreshFromCurrentState` 가 먼저 돌면서 창을 닫는다.)
    @discardableResult
    static func considerPurchase(date: Date?) -> Bool {
        guard let date, let closedAt = windowClosedAt, date < closedAt else { return false }
        return grant(.purchased)
    }

    /// 이 버전의 **첫 실행**에 창을 닫고, 그 순간의 상태로 판정한다.
    ///
    /// 첫 실행에 이미 Pro 라면 결제는 반드시 그보다 앞이므로, 결제 시각을 몰라도 자격이
    /// 성립한다 — StoreKit 이 닿지 않아도 자격을 놓치지 않는다. 창이 이미 닫힌 뒤라면
    /// 이 경로로는 부여하지 않는다(그 뒤의 결제는 새 가격이다). 그때부터는
    /// `considerPurchase(date:)` 만이 자격을 만든다.
    ///
    /// 상태는 기본값으로 받아 둔다(호출부에서 평가) — 테스트에서 갈아 끼우기 위해서다.
    @discardableResult
    static func refreshFromCurrentState(
        now: Date = Date(),
        isGrandfathered: Bool = StoreManager.isGrandfathered,
        isPro: Bool = StoreManager.isProUser,
        isAutoPro: Bool = StoreManager.isAutoProEnvironment
    ) -> Bool {
        let justClosed = closeWindowIfNeeded(now: now)

        if isGrandfathered {
            return grant(.grandfathered)
        }
        guard justClosed, isPro, !isAutoPro else { return false }
        return grant(.purchased)
    }

    /// StoreKit 이 아는 **최초 결제 시각**으로 판정한다 — 마감이 지난 뒤 재설치·기기 교체로
    /// 복원한 사람의 자격이 되살아나는 유일한 경로다.
    ///
    /// ⚠️ `StoreManager` 는 `Shared/` 에 있어 워치·위젯 타겟에서도 컴파일된다. 그래서
    ///    창단 후원자 판정은 그쪽이 아니라 **여기(앱 전용)** 에 둔다 — 저쪽에 넣으면
    ///    워치·위젯 빌드가 앱 전용 코드를 찾다가 깨진다.
    static func refreshFromStoreKit() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == StoreManager.ProductID.pro.rawValue else { continue }
            considerPurchase(date: transaction.originalPurchaseDate)
        }
    }

    // MARK: - 안내 (한 번만)

    /// 약속을 아직 전하지 않은 창단 후원자인가.
    /// ⚠️ 한 번만 뜬다 — 고맙다는 말도 두 번 하면 잔소리가 된다.
    static var shouldAnnounce: Bool {
        isFounder && !defaults.bool(forKey: announcedKey)
    }

    static func markAnnounced() {
        defaults.set(true, forKey: announcedKey)
    }

    // MARK: - 테스트 지원

    #if DEBUG
    /// 테스트에서만 쓰는 초기화 — 앱 코드에서 부르지 말 것(자격은 회수하지 않는다).
    static func resetForTesting() {
        defaults.removeObject(forKey: originKey)
        defaults.removeObject(forKey: announcedKey)
        defaults.removeObject(forKey: windowKey)
        keychainClear(keychainKey)
        keychainClear(windowKey)
    }
    #endif
}
