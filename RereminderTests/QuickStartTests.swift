//
//  QuickStartTests.swift
//  RereminderTests
//
//  제어센터·홈 화면 위젯에서 저장한 설정을 바로 시작하기(`QuickStartShelf`·`QuickStartPublisher`).
//

import SwiftData
import XCTest
@testable import Rereminder

private typealias TimerTemplate = Rereminder.Timer

@MainActor
final class QuickStartTests: XCTestCase {

    private var suiteName = ""
    private var savedDefaults: UserDefaults?
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // 기기에 남은 실제 목록·요청에 휘둘리지 않게 갈아 끼운다.
        suiteName = "QuickStartTests.\(UUID().uuidString)"
        savedDefaults = QuickStartShelf.defaults
        QuickStartShelf.defaults = UserDefaults(suiteName: suiteName)

        let schema = Schema([TimerTemplate.self, TimerRecord.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        UserDefaults().removePersistentDomain(forName: suiteName)
        QuickStartShelf.defaults = savedDefaults
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    // MARK: - 요청

    func test_request_isTakenOnlyOnce() {
        let id = UUID()
        QuickStartShelf.request(templateID: id.uuidString)
        XCTAssertEqual(QuickStartShelf.takeRequest(), id)
        // 알림과 활성화가 둘 다 와도 한 번만 시작한다
        XCTAssertNil(QuickStartShelf.takeRequest())
    }

    /// 앱이 받기 전에 죽었다면, 한참 뒤에 연 순간 엉뚱하게 시작하면 안 된다.
    func test_staleRequest_isDropped() {
        let now = Date()
        QuickStartShelf.request(templateID: UUID().uuidString, now: now)
        XCTAssertNil(QuickStartShelf.takeRequest(now: now.addingTimeInterval(QuickStartShelf.requestLifetime + 1)))
        XCTAssertNil(QuickStartShelf.takeRequest(), "버린 요청은 남지 않는다")
    }

    func test_request_resolvesToTemplateInStore() throws {
        let t = TimerTemplate(name: "Talk", mainSeconds: 900, prealertOffsetsSec: [300, 60])
        context.insert(t)
        try context.save()
        QuickStartShelf.request(templateID: t.id.uuidString)
        let id = try XCTUnwrap(QuickStartShelf.takeRequest())
        XCTAssertEqual(QuickStartPublisher.template(id: id, context: context)?.id, t.id)
    }

    // MARK: - 목록

    func test_write_reportsChangeOnlyWhenDifferent() {
        let items = [QuickStartItem(id: "a", name: "A", durationText: "10 min", alertCount: 1)]
        XCTAssertTrue(QuickStartShelf.write(items))
        XCTAssertFalse(QuickStartShelf.write(items), "같으면 위젯을 다시 그리지 않는다")
        XCTAssertEqual(QuickStartShelf.items, items)
    }

    func test_order_favoriteThenUsageThenRecent() {
        let now = Date()
        let recent = TimerTemplate(name: "recent", mainSeconds: 600, prealertOffsetsSec: [], lastUsedAt: now)
        let used = TimerTemplate(name: "used", mainSeconds: 600, prealertOffsetsSec: [])
        let favorite = TimerTemplate(name: "favorite", mainSeconds: 600, prealertOffsetsSec: [], isFavorite: true)
        [recent, used, favorite].forEach(context.insert)
        for _ in 0..<2 {
            context.insert(TimerRecord(date: now, finished: true, elapsedSeconds: 600,
                                       snapshotMainSeconds: 600, snapshotPrealertOffsetsSec: [], template: used))
        }
        let names = QuickStartPublisher.ordered([recent, used, favorite]).map(\.name)
        XCTAssertEqual(names, ["favorite", "used", "recent"])
    }

    /// 위젯 목록은 요금제와 무관하다 — 🔖 시트와 같은 템플릿이 같은 결과로 시작된다.
    /// 세션 모드로 저장한 것도 빠지지 않는다(결제한 사람의 템플릿이 위젯에서 사라지면 안 된다).
    func test_items_includeEveryKindOfTemplate_andCapAtMax() {
        var templates: [TimerTemplate] = (0..<8).map {
            TimerTemplate(name: "t\($0)", mainSeconds: 600, prealertOffsetsSec: [60])
        }
        templates[0] = TimerTemplate(name: "session", mainSeconds: 1800, prealertOffsetsSec: [600, 300],
                                     isFavorite: true, isPresentation: true)
        let items = QuickStartPublisher.items(from: templates)
        XCTAssertEqual(items.count, QuickStartShelf.maxItems)
        XCTAssertEqual(items.first?.name, templates[0].displayName)
        XCTAssertEqual(items.first?.alertCount, 2)
    }
}
