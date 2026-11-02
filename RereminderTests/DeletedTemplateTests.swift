//
//  DeletedTemplateTests.swift
//  RereminderTests
//
//  도는 중에 그 템플릿을 지워도 앱이 죽지 않는다(`TimerViewModel.use`·`recordLink`).
//
//  ⚠️ 지운 SwiftData 객체의 속성을 읽으면 "backing data was detached" 로 앱이 죽는다.
//     예전에는 타이머가 저장된 템플릿을 그대로 들고 있다가 예비 알림·종료 순간에 그 문구를 읽었다.
//

import SwiftData
import XCTest
@testable import Rereminder

private typealias TimerTemplate = Rereminder.Timer

@MainActor
final class DeletedTemplateTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([TimerTemplate.self, TimerRecord.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    private func savedTemplate() throws -> TimerTemplate {
        let t = TimerTemplate(name: "Talk", mainSeconds: 900, prealertOffsetsSec: [300, 60],
                              prealertMessages: [60: "Wrap up"], finishMessage: "Done", label: "Class")
        context.insert(t)
        try context.save()
        return t
    }

    func test_copy_staysReadableAfterOriginalIsDeleted() throws {
        let original = try savedTemplate()
        let copy = original.detachedCopy()
        context.delete(original)
        try context.save()

        XCTAssertEqual(copy.getPrealertMessage(for: 60), "Wrap up")
        XCTAssertEqual(copy.getFinishMessage(), "Done")
        XCTAssertEqual(copy.mainSeconds, 900)
        XCTAssertEqual(copy.prealertOffsetsSec, [60, 300])
        XCTAssertEqual(copy.label, "Class")
        XCTAssertNil(copy.modelContext, "사본은 스토어에 들어가지 않는다")
    }

    func test_record_linksToLiveSource() throws {
        let original = try savedTemplate()
        let link = TimerViewModel.recordLink(source: original, running: original.detachedCopy(), isNewInstall: false)
        XCTAssertTrue(link === original)
    }

    /// 지운 원본도, 사본도 물리지 않는다 — 사본을 물리면 지운 템플릿이 칩으로 되살아난다.
    func test_record_dropsLinkWhenSourceWasDeleted() throws {
        let original = try savedTemplate()
        let copy = original.detachedCopy()
        context.delete(original)
        try context.save()

        let link = TimerViewModel.recordLink(source: original, running: copy, isNewInstall: false)
        XCTAssertNil(link)

        let record = TimerRecord(date: .now, finished: true, elapsedSeconds: 900,
                                 snapshotMainSeconds: copy.mainSeconds,
                                 snapshotPrealertOffsetsSec: copy.prealertOffsetsSec, template: link)
        context.insert(record)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerTemplate>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TimerRecord>()).count, 1)
    }

    func test_record_keepsTemporarySetupRule() {
        let temp = TimerTemplate(name: "", mainSeconds: 600, prealertOffsetsSec: [60])
        XCTAssertTrue(TimerViewModel.recordLink(source: nil, running: temp, isNewInstall: false) === temp)
        XCTAssertNil(TimerViewModel.recordLink(source: nil, running: temp, isNewInstall: true))
    }
}
