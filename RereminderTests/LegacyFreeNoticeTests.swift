//
//  LegacyFreeNoticeTests.swift
//  RereminderTests
//
//  개편 전부터 무료로 쓰던 사람에게만 "달라진 점" 안내가 뜨는가.
//  이 기능의 실패는 두 방향이다 — **새로 설치한 사람에게 뜨는 것**(잃은 게 없는데 "잃었다"고
//  말한다)과 **정작 잃은 사람에게 안 뜨는 것**. 둘 다 여기서 막는다.
//

import SwiftData
import XCTest
@testable import Rereminder

private typealias TimerTemplate = Rereminder.Timer

final class LegacyFreeNoticeTests: XCTestCase {

    private var suiteName = ""
    private var suite: UserDefaults!
    private var context: ModelContext!

    private let window = Date(timeIntervalSince1970: 1_789_000_000)
    private var before: Date { window.addingTimeInterval(-86_400) }
    private var after: Date { window.addingTimeInterval(60) }

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "LegacyFreeNoticeTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        LegacyFreeNotice.defaults = suite

        let schema = Schema([TimerTemplate.self, TimerRecord.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        LegacyFreeNotice.defaults = .standard
        context = nil
        super.tearDown()
    }

    private func refresh(justClosed: Bool = false, starts: Double = 0) {
        LegacyFreeNotice.refresh(context: context, windowJustClosed: justClosed,
                                 priorTimerStarts: starts, windowClosedAt: window)
    }

    private func insertTemplate(createdAt: Date, name: String = "Presentation 30 min") {
        context.insert(TimerTemplate(name: name, mainSeconds: 1800, prealertOffsetsSec: [60], createdAt: createdAt))
        try? context.save()
    }

    // MARK: - 새로 설치한 사람에게는 뜨지 않는다

    func testFreshInstall_notEligible() {
        refresh(justClosed: true, starts: 0)
        XCTAssertFalse(LegacyFreeNotice.isEligible)
    }

    /// 시드는 창이 닫힌 **뒤에** 심긴다 — 그 시드를 개편 전 흔적으로 읽으면 신규 사용자 전원이 안내를 본다.
    func testFreshInstall_seedsAfterWindow_notEligible() {
        insertTemplate(createdAt: after)
        refresh(justClosed: true)
        XCTAssertFalse(LegacyFreeNotice.isEligible)
    }

    /// 개편 뒤에 설치해 한참 쓴 사람 — 기록·템플릿이 전부 경계 뒤다.
    func testInstalledAfterChange_usedALot_notEligible() {
        insertTemplate(createdAt: after, name: "My talk")
        context.insert(TimerRecord(date: after, finished: true, elapsedSeconds: 600,
                                   snapshotMainSeconds: 600, snapshotPrealertOffsetsSec: [60], template: nil))
        try? context.save()
        refresh(justClosed: false, starts: 40)
        XCTAssertFalse(LegacyFreeNotice.isEligible)
    }

    // MARK: - 개편 전부터 쓰던 사람에게는 뜬다

    /// 옛 버전에서 곧장 이번 버전으로 올라온 사람 — 창이 이번에 닫혔는데 이미 타이머를 건 적이 있다.
    func testUpdatedStraightFromOldVersion_eligible() {
        refresh(justClosed: true, starts: 3)
        XCTAssertTrue(LegacyFreeNotice.isEligible)
    }

    /// 개편 버전을 이미 써 온 사람 — 날짜가 붙은 흔적으로 알아본다.
    func testTemplateBeforeWindow_eligible() {
        insertTemplate(createdAt: before)
        refresh()
        XCTAssertTrue(LegacyFreeNotice.isEligible)
    }

    func testRecordBeforeWindow_eligible() {
        context.insert(TimerRecord(date: before, finished: true, elapsedSeconds: 600,
                                   snapshotMainSeconds: 600, snapshotPrealertOffsetsSec: [60], template: nil))
        try? context.save()
        refresh()
        XCTAssertTrue(LegacyFreeNotice.isEligible)
    }

    /// 저장소가 고장 나 있던 시기(템플릿·기록이 안 남았다)의 사람도 옛 알림 한도 키로 알아본다.
    func testLegacyOnlyKey_eligible() {
        suite.set(4, forKey: "trial.count.unlimitedPrealerts")
        refresh()
        XCTAssertTrue(LegacyFreeNotice.isEligible)
    }

    // MARK: - 띄울지

    func testProAndFounder_neverAnnounced() {
        refresh(justClosed: true, starts: 3)
        XCTAssertFalse(LegacyFreeNotice.shouldAnnounce(isPro: true, isFounder: false))
        XCTAssertFalse(LegacyFreeNotice.shouldAnnounce(isPro: false, isFounder: true))
        XCTAssertTrue(LegacyFreeNotice.shouldAnnounce(isPro: false, isFounder: false))
    }

    func testAnnouncedOnlyOnce_butStaysEligibleForSettings() {
        refresh(justClosed: true, starts: 3)
        LegacyFreeNotice.markAnnounced()
        XCTAssertFalse(LegacyFreeNotice.shouldAnnounce(isPro: false, isFounder: false))
        XCTAssertTrue(LegacyFreeNotice.isEligible)
    }

    /// 흔적은 과거의 것이라 한 번만 본다 — 나중에 생긴 데이터로 판정이 바뀌면 안 된다.
    func testCheckedOnce() {
        refresh(justClosed: true, starts: 0)
        insertTemplate(createdAt: before)
        refresh()
        XCTAssertFalse(LegacyFreeNotice.isEligible)
    }

    // MARK: - 개편 전 템플릿은 무료에서도 불러온다

    func testPreChangeTemplate_loadableOnFree() {
        XCTAssertTrue(LegacyFreeNotice.isPreChangeTemplate(createdAt: before, windowClosedAt: window))
        XCTAssertFalse(LegacyFreeNotice.isPreChangeTemplate(createdAt: after, windowClosedAt: window))
    }

    /// 창이 아직 닫히지 않았으면(경계가 없으면) 어떤 템플릿도 예외가 아니다.
    func testPreChangeTemplate_noWindow_locked() {
        XCTAssertFalse(LegacyFreeNotice.isPreChangeTemplate(createdAt: before, windowClosedAt: nil))
    }
}
