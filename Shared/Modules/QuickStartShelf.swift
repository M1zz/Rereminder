//
//  QuickStartShelf.swift
//  Rereminder
//
//  **제어센터·홈 화면 위젯에서 저장한 설정을 눌러 바로 시작한다** — 그 목록과 요청이 오가는 통로.
//
//  왜 목록을 따로 적나: 템플릿은 앱 그룹의 SwiftData 스토어에 있지만 위젯 확장에는 `Timer` 모델이
//  없고, 두 프로세스가 같은 스토어를 함께 여는 것도 위험하다. 그래서 앱이 보여 줄 만큼만 가볍게
//  적어 두고 확장은 그것만 읽는다(`WatchTimerState` 와 같은 방식).
//
//  ⚠️ **시작은 앱 안 🔖 시트와 똑같은 길(`TimerScreenViewModel.apply(template:)`)로만 한다.**
//     위젯에만 다른 판정을 두면 같은 템플릿이 앱에서는 되고 위젯에서는 안 되는(또는 그 반대)
//     일이 생긴다. 저장한 템플릿 불러오기는 누구에게나 열려 있으므로 여기에는 결제 판정이 없다.
//
//  ⚠️ 목록에는 id 만 믿는다. 이름·시간은 그리기용이고, 누를 때 앱이 스토어에서 다시 읽는다.
//     (앱에서 고친 템플릿을 위젯이 옛 값으로 시작하지 않게.)
//
//  앱·위젯 확장 양쪽에서 컴파일된다 — 무거운 의존을 끌어들이지 말 것.
//

import Foundation

/// 위젯·제어센터에 그릴 저장한 설정 한 칸.
struct QuickStartItem: Codable, Hashable, Identifiable {
    /// `Timer.id` 문자열
    let id: String
    /// 적을 때의 언어로 만든 이름(`Timer.displayName`)
    let name: String
    /// 적을 때의 언어로 만든 길이(`TimeMapper.durationText`) — 확장에는 그 함수가 없다.
    let durationText: String
    let alertCount: Int
    /// 위젯 칸의 작은 링을 그리는 재료. 2.3.5 첫 빌드가 적은 목록에는 없어서 선택값이다.
    var mainSeconds: Int?
    var alertOffsets: [Int]?
}

enum QuickStartShelf {

    /// 위젯이 가장 많이 보여 주는 칸 수(큰 위젯). 더 적어 둘 이유가 없다.
    static let maxItems = 6

    /// 요청이 이 시간 안에 앱에 닿지 않았으면 버린다.
    /// ⚠️ 없으면 앱이 요청을 받기 전에 죽었을 때, 한참 뒤 앱을 연 순간 엉뚱하게 타이머가 시작된다.
    static let requestLifetime: TimeInterval = 60

    static let controlKind = "com.xa.toki.QuickStartControl.v1"
    static let widgetKind = "RereminderAlarm"

    private static let suiteName = "group.leeo.toki"
    private static let itemsKey = "quickStart.items.v1"
    private static let requestIDKey = "quickStart.request.templateID"
    private static let requestAtKey = "quickStart.request.at"

    /// 테스트에서 갈아 끼운다.
    static var defaults: UserDefaults? = UserDefaults(suiteName: suiteName)

    // MARK: - 목록

    static var items: [QuickStartItem] {
        guard let data = defaults?.data(forKey: itemsKey),
              let items = try? JSONDecoder().decode([QuickStartItem].self, from: data) else { return [] }
        return items
    }

    /// 목록을 적는다. 바뀌었을 때만 참 — 그때만 위젯을 다시 그리면 된다.
    @discardableResult
    static func write(_ items: [QuickStartItem]) -> Bool {
        let trimmed = Array(items.prefix(maxItems))
        guard trimmed != self.items, let data = try? JSONEncoder().encode(trimmed) else { return false }
        defaults?.set(data, forKey: itemsKey)
        return true
    }

    // MARK: - 시작 요청

    static func request(templateID: String, now: Date = Date()) {
        defaults?.set(templateID, forKey: requestIDKey)
        defaults?.set(now.timeIntervalSince1970, forKey: requestAtKey)
    }

    /// 남아 있는 요청을 꺼낸다(꺼내면 지워진다). 오래된 요청은 버린다.
    static func takeRequest(now: Date = Date()) -> UUID? {
        guard let raw = defaults?.string(forKey: requestIDKey) else { return nil }
        let at = defaults?.double(forKey: requestAtKey) ?? 0
        defaults?.removeObject(forKey: requestIDKey)
        defaults?.removeObject(forKey: requestAtKey)
        guard now.timeIntervalSince1970 - at < requestLifetime else { return nil }
        return UUID(uuidString: raw)
    }
}

extension Notification.Name {
    /// 앱이 이미 떠 있을 때 요청을 바로 받게 한다. 콜드 런치는 `QuickStartShelf.takeRequest` 가 받는다.
    static let quickStartRequested = Notification.Name("rereminder.quickStartRequested")
}
