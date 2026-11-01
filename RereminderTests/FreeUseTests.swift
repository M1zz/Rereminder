//
//  FreeUseTests.swift
//  RereminderTests
//
//  무료 기간과 "이미 누리던 것은 줄지 않는다"를 지킨다.
//

import XCTest
@testable import Rereminder

final class FreeUseTests: XCTestCase {

    private var suiteName = ""
    private var original: UserDefaults = .standard
    private var originalTrial: UserDefaults = .standard

    override func setUp() {
        super.setUp()
        suiteName = "FreeUseTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        original = FreeUse.defaults
        originalTrial = TrialCounter.defaults
        FreeUse.defaults = suite
        TrialCounter.defaults = suite
        UserDefaults.standard.set(true, forKey: "dev.testPaywall")
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        FreeUse.defaults = original
        TrialCounter.defaults = originalTrial
        UserDefaults.standard.removeObject(forKey: "dev.testPaywall")
        super.tearDown()
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    // MARK: - 문턱

    func test_같은_날_여러번은_하루다() {
        for _ in 0..<50 { FreeUse.recordCompletion(isSession: false, now: day(0)) }
        XCTAssertEqual(FreeUse.days, 1)
        XCTAssertTrue(FreeUse.isActive)
    }

    func test_서로_다른_날로_문턱에_닿는다() {
        for i in 0..<(FreeUse.dayThreshold - 1) { FreeUse.recordCompletion(isSession: false, now: day(i)) }
        XCTAssertTrue(FreeUse.isActive)
        FreeUse.recordCompletion(isSession: false, now: day(FreeUse.dayThreshold))
        XCTAssertFalse(FreeUse.isActive)
    }

    func test_세션_완주로도_문턱에_닿는다() {
        for _ in 0..<FreeUse.sessionThreshold { FreeUse.recordCompletion(isSession: true, now: day(0)) }
        XCTAssertFalse(FreeUse.isActive)
    }

    // MARK: - 무료 기간

    func test_무료_기간에는_모든_기능이_열린다() {
        for feature in ProGate.Feature.allCases {
            XCTAssertTrue(ProGate.isAvailable(feature), "\(feature)")
        }
        XCTAssertTrue(ProGate.canRememberSetup)
        XCTAssertTrue(ProGate.canSaveTemplate(currentCount: 100))
    }

    func test_무료_기간은_Pro_로_세지_않는다() {
        XCTAssertFalse(StoreManager.isProUser, "섞이면 창단 후원자 자격과 flag.isPaid 가 틀어진다")
    }

    func test_무료_기간에는_앱이_먼저_Pro_를_꺼내지_않는다() {
        XCTAssertFalse(ProMention.canMention(.recall, isPro: false))
    }

    // MARK: - 이미 누리던 것은 줄지 않는다

    /// 예전 5+5 판정. 새 판정은 어떤 상태에서도 이것보다 좁으면 안 된다.
    private func legacyAllowed(used: Int, extended: Bool) -> Bool {
        if used < TrialCounter.firstStageLimit { return true }
        return used < TrialCounter.secondStageLimit && extended
    }

    func test_문턱_뒤에도_예전에_열려_있던_것은_전부_열려_있다() {
        FreeUse.markReachedForTesting()
        for feature in [ProGate.Feature.presentationMode, .timerHistory] {
            for used in 0...12 {
                for extended in [false, true] {
                    TrialCounter.reset(feature)
                    for _ in 0..<used { TrialCounter.increment(feature) }
                    if extended { TrialCounter.acceptExtension(for: feature) }
                    if legacyAllowed(used: used, extended: extended) {
                        XCTAssertTrue(ProGate.evaluate(feature).isAllowed, "\(feature) \(used) \(extended)")
                    }
                }
            }
        }
    }

    func test_무료_기간에_쓴_것은_원래_횟수를_깎지_않는다() {
        TrialCounter.increment(.presentationMode)
        ProGate.recordUsage(.presentationMode)
        XCTAssertEqual(TrialCounter.count(for: .presentationMode), 1)
        FreeUse.markReachedForTesting()
        if case .allowedWithTrial(let remaining, _) = ProGate.evaluate(.presentationMode) {
            XCTAssertEqual(remaining, TrialCounter.firstStageLimit - 1)
        } else {
            XCTFail("남은 횟수가 그대로 있어야 한다")
        }
    }

    func test_오버타임은_언제나_무료다() {
        FreeUse.markReachedForTesting()
        for _ in 0..<20 { TrialCounter.increment(.overtimeTracking) }
        XCTAssertTrue(ProGate.canUseOvertime)
    }

    func test_문턱_전_기록은_계속_보인다() {
        let reached = day(-100)
        FreeUse.markReachedForTesting(at: reached)
        XCTAssertTrue(FreeUse.isRecordVisible(date: day(-400)))
        XCTAssertFalse(FreeUse.isRecordVisible(date: day(-60)))
        XCTAssertTrue(FreeUse.isRecordVisible(date: day(-5)))
    }

    // MARK: - 안내

    func test_문턱_안내는_한번만_돈_낸_사람에게는_뜨지_않는다() {
        XCTAssertFalse(FreeUse.shouldAnnounce(isPaid: false), "문턱 전")
        FreeUse.markReachedForTesting()
        XCTAssertFalse(FreeUse.shouldAnnounce(isPaid: true))
        XCTAssertTrue(FreeUse.shouldAnnounce(isPaid: false))
        FreeUse.markAnnounced()
        XCTAssertFalse(FreeUse.shouldAnnounce(isPaid: false))
    }
}
