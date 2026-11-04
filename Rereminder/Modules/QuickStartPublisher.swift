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

import AppIntents
import CoreSpotlight
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
                    name: tileName(t),
                    durationText: TimeMapper.durationText(t.mainSeconds),
                    alertCount: t.prealertOffsetsSec.filter { $0 > 0 && $0 < t.mainSeconds }.count,
                    mainSeconds: t.mainSeconds,
                    alertOffsets: t.prealertOffsetsSec.filter { $0 > 0 && $0 < t.mainSeconds }
                )
            }
    }

    /// 칸의 둘째 줄. 사용자가 지은 이름이면 그것, 앱이 지은 이름("10분 · 알림 1분 전")이면 알림 시각만 —
    /// 시간은 칸에 이미 크게 있어서, 같은 말을 한 번 더 쓰면 잘려서 찌그러져 보였다.
    static func tileName(_ t: Timer) -> String {
        guard Timer.isGeneratedName(t.name) else { return t.displayName }
        return t.prealertOffsetsSec.filter { $0 > 0 && $0 < t.mainSeconds }
            .sorted(by: >)
            .map { AlertPresets.label($0) }
            .joined(separator: ", ")
    }

    static func publish(context: ModelContext) {
        guard let templates = try? context.fetch(FetchDescriptor<Timer>()) else { return }
        SavedSetupEntity.reindex(templates)
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

// MARK: - Siri · Spotlight
//
// 저장한 설정을 Spotlight 에 색인해, Siri·Spotlight 가 이름으로 찾아 바로 시작하게 한다.
// 시작은 위젯·제어센터와 같은 길(`QuickStartShelf.request`)이다 — 앱이 스토어에서 다시 읽어 `apply(template:)` 한다.
// 색인은 위젯 목록과 같은 때(앱이 뜰 때 · 뒤로 갈 때) 통째로 다시 적는다. 위젯과 달리 6개로 자르지 않는다.

struct SavedSetupEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Saved setup")
    static let defaultQuery = SavedSetupQuery()

    /// `Timer.id` 문자열
    let id: String
    let name: String
    let durationText: String

    var displayRepresentation: DisplayRepresentation {
        // 사용자가 지은 이름이라 번역하지 않는다 — 리터럴로 쓰면 "%@" 가 카탈로그에 추출된다.
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name),
                              subtitle: LocalizedStringResource(stringLiteral: durationText))
    }

    init(_ template: Timer) {
        id = template.id.uuidString
        name = template.displayName
        durationText = TimeMapper.durationText(template.mainSeconds)
    }

    static func reindex(_ templates: [Timer]) {
        let entities = QuickStartPublisher.ordered(templates.filter { $0.mainSeconds > 0 }).map(SavedSetupEntity.init)
        Task {
            let index = CSSearchableIndex.default()
            try? await index.deleteAppEntities(ofType: SavedSetupEntity.self)
            try? await index.indexAppEntities(entities)
        }
    }
}

struct SavedSetupQuery: EntityStringQuery {
    @MainActor
    private func all() -> [SavedSetupEntity] {
        let context = RereminderApp.sharedModelContainer.mainContext
        let templates = (try? context.fetch(FetchDescriptor<Timer>())) ?? []
        return QuickStartPublisher.ordered(templates.filter { $0.mainSeconds > 0 }).map(SavedSetupEntity.init)
    }

    @MainActor
    func entities(for identifiers: [String]) async throws -> [SavedSetupEntity] {
        all().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [SavedSetupEntity] {
        all().filter { $0.name.localizedStandardContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [SavedSetupEntity] {
        all()
    }
}

/// Spotlight 에서 저장한 설정을 누르거나 Siri 에게 이름으로 시키면 앱을 열고 그 설정을 시작한다.
/// 이미 도는 타이머는 덮지 않는다(`TimerUnifiedView.startRequestedSetupIfAny`).
struct OpenSavedSetupIntent: OpenIntent {
    static let title: LocalizedStringResource = "Start a saved setup"
    static let description = IntentDescription("Opens the app and starts the saved setup you pick.")

    @Parameter(title: "Saved setup", description: "The saved setup to start.")
    var target: SavedSetupEntity

    init() {}
    init(target: SavedSetupEntity) { self.target = target }

    /// 🔖 시트에서 같은 일을 했을 때 기부한다 — Siri 가 "이 설정 시작" 을 배운다.
    static func donate(_ template: Timer) {
        IntentDonationManager.shared.donate(intent: OpenSavedSetupIntent(target: SavedSetupEntity(template)))
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickStartShelf.request(templateID: target.id)
        NotificationCenter.default.post(name: .quickStartRequested, object: nil)
        return .result()
    }
}
