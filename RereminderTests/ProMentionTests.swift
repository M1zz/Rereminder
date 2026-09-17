//
//  ProMentionTests.swift
//  RereminderTests
//
//  무료 사용자에게 Pro 를 먼저 꺼내는 횟수의 예산.
//  실패 방식은 하나다 — **알아들은 사람에게 계속 말하는 것.** 그래서 "언제 입을 다무는가"를 본다.
//

import XCTest
@testable import Rereminder

final class ProMentionTests: XCTestCase {

    private var suiteName = ""
    private var suite: UserDefaults!
    private var calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_789_520_400)

    private func day(_ n: Int) -> Date { now.addingTimeInterval(Double(n) * 86_400) }

    override func setUp() {
        super.setUp()
        suiteName = "ProMentionTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        ProMention.defaults = suite
        ProMention.calendar = calendar
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        ProMention.defaults = .standard
        ProMention.calendar = .current
        super.tearDown()
    }

    private func can(_ kind: ProMention.Kind, at date: Date, isPro: Bool = false, paywallViews: Int = 0) -> Bool {
        ProMention.canMention(kind, isPro: isPro, paywallViews: paywallViews, now: date)
    }

    func testFreshFreeUser_canMention() {
        XCTAssertTrue(can(.recall, at: day(0)))
    }

    func testPro_never() {
        XCTAssertFalse(can(.recall, at: day(0), isPro: true))
    }

    func testEachKind_onlyOnce() {
        ProMention.markMentioned(.recall, now: day(0))
        XCTAssertFalse(can(.recall, at: day(30)))
        XCTAssertTrue(can(.repeatSetup, at: day(30)))
    }

    /// 연달아 이틀 들으면 조르는 앱이 된다.
    func testRestsBetweenMentions() {
        ProMention.markMentioned(.recall, now: day(0))
        XCTAssertFalse(can(.repeatSetup, at: day(1)))
        XCTAssertFalse(can(.repeatSetup, at: day(ProMention.minDaysBetween - 1)))
        XCTAssertTrue(can(.repeatSetup, at: day(ProMention.minDaysBetween)))
    }

    func testTotalBudget() {
        let kinds: [ProMention.Kind] = [.recall, .repeatSetup, .reentry, .eve]
        for (i, kind) in kinds.prefix(ProMention.maxMentions).enumerated() {
            ProMention.markMentioned(kind, now: day(i * 10))
        }
        XCTAssertFalse(can(kinds[ProMention.maxMentions], at: day(100)))
    }

    /// 권유를 한 번 눌러 Pro 가 뭔지 봤으면 알아들은 것이다.
    func testStopsAfterTapped() {
        ProMention.markTapped()
        XCTAssertFalse(can(.recall, at: day(0)))
    }

    /// 잠긴 기능을 눌러 페이월을 여러 번 봤어도 알아들은 것이다.
    func testStopsAfterSeeingPaywall() {
        XCTAssertTrue(can(.recall, at: day(0), paywallViews: ProMention.learnedPaywallViews - 1))
        XCTAssertFalse(can(.recall, at: day(0), paywallViews: ProMention.learnedPaywallViews))
    }

    /// 달라진 점 설명은 예산을 쓰지 않지만, 그 뒤 며칠은 다른 권유가 붙지 않는다.
    func testLegacyNotice_spacesButDoesNotSpend() {
        ProMention.markMentioned(.legacy, now: day(0))
        XCTAssertEqual(ProMention.count, 0)
        XCTAssertFalse(can(.recall, at: day(1)))
        XCTAssertTrue(can(.recall, at: day(ProMention.minDaysBetween)))
    }

    // MARK: - 문구 실험

    /// 세션 모드를 안 쓴 사람은 실험 밖이다 — 구간 이야기는 뜬금없다.
    func testVariant_notAssignedWithoutSessionMode() {
        XCTAssertNil(ProMention.copyVariant(usedSessionMode: false, coinFlip: { true }))
        XCTAssertNil(ProMention.assignedCopyVariant)
    }

    /// 한 번 정해진 갈래는 바뀌지 않는다 — 바뀌면 결제가 어느 문구 덕인지 못 가른다.
    func testVariant_stickyOnceAssigned() {
        XCTAssertEqual(ProMention.copyVariant(usedSessionMode: true, coinFlip: { true }), .session)
        XCTAssertEqual(ProMention.copyVariant(usedSessionMode: true, coinFlip: { false }), .session)
        XCTAssertEqual(ProMention.copyVariant(usedSessionMode: false, coinFlip: { false }), .session)
        XCTAssertEqual(ProMention.assignedCopyVariant, .session)
    }

    func testVariant_otherHalf() {
        XCTAssertEqual(ProMention.copyVariant(usedSessionMode: true, coinFlip: { false }), .remember)
    }
}
