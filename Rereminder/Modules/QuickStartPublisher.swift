//
//  QuickStartPublisher.swift
//  Rereminder
//
//  저장한 설정을 위젯·제어센터가 읽을 목록(`QuickStartShelf`)으로 옮겨 적는다. 앱 전용.
//
//  언제 적나: 앱이 화면에 뜰 때와 뒤로 갈 때. 저장·이름 바꾸기·지우기·사용 기록이 전부 앱이 앞에
//  있는 동안 일어나므로, 뒤로 가는 순간 한 번 적으면 빠지는 변화가 없다. 홈 화면에서 위젯을 고르는
//  것도 늘 앱이 뒤로 간 다음이다.
//

import Foundation
import SwiftData
import WidgetKit

enum QuickStartPublisher {

    /// "자주 쓰는" 순서 — 즐겨찾기 → 쓴 횟수 → 최근 사용 → 만든 날.
    static func ordered(_ templates: [Timer]) -> [Timer] {
        templates.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            if a.usageCount != b.usageCount { return a.usageCount > b.usageCount }
            switch (a.lastUsedAt, b.lastUsedAt) {
            case let (x?, y?) where x != y: return x > y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return a.createdAt > b.createdAt
            }
        }
    }

    static func items(from templates: [Timer]) -> [QuickStartItem] {
        ordered(templates.filter { $0.mainSeconds > 0 })
            .prefix(QuickStartShelf.maxItems)
            .map { t in
                QuickStartItem(
                    id: t.id.uuidString,
                    name: t.displayName,
                    durationText: TimeMapper.durationText(t.mainSeconds),
                    alertCount: t.prealertOffsetsSec.filter { $0 > 0 && $0 < t.mainSeconds }.count
                )
            }
    }

    static func publish(context: ModelContext) {
        guard let templates = try? context.fetch(FetchDescriptor<Timer>()) else { return }
        guard QuickStartShelf.write(items(from: templates)) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: QuickStartShelf.widgetKind)
        #if !targetEnvironment(macCatalyst)
        ControlCenter.shared.reloadControls(ofKind: QuickStartShelf.controlKind)
        #endif
    }

    /// 요청받은 템플릿을 스토어에서 다시 읽는다(목록의 이름·시간은 그리기용일 뿐이다).
    static func template(id: UUID, context: ModelContext) -> Timer? {
        var descriptor = FetchDescriptor<Timer>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
