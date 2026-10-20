//
//  MonetizationExtrasTests.swift
//  RereminderTests
//
//  **무료 한도 선언 · 팁 · 선물의 약속.**
//
//  지키는 것:
//  - 팁·선물 상품은 아무 권한도 열지 않는다 — `productIDs` · `entitlementIDs` 밖에 있다.
//  - 선물은 Pro 전체(`com.xa.toki.pro`)를 연다. 플러스(기억)는 Pro 권한이 아니다.
//  - 새 상품 ID 는 기존 접두사(`com.xa.toki.`)를 따른다.
//  - 무료 한도는 `ProGate.gatePolicy` 한 곳이고, 체험 한 바퀴(5)와 같은 숫자다.
//  - 한도 미리 알림은 한 바퀴에 2번 이하 남았을 때만, 막혔거나 열린 사람에게는 서지 않는다.
//  - 팁 부탁의 순간은 숫자를 넘어섰을 때만, 인상적인 것부터.
//

import XCTest
import LeeoKit
@testable import Rereminder

final class MonetizationExtrasTests: XCTestCase {

    private let config = RereminderSpec.paywallConfig

    // MARK: - 상품

    func test_팁과_선물은_권한을_열지_않는다() {
        let sold = Set(config.productIDs).union(config.entitlementIDs)
        XCTAssertTrue(sold.isDisjoint(with: StoreManager.tipProductIDs))
        XCTAssertFalse(sold.contains(StoreManager.giftProductID))
        XCTAssertFalse(StoreManager.tipProductIDs.contains(StoreManager.giftProductID))
    }

    func test_선물은_Pro_전체를_연다() {
        let gift = try! XCTUnwrap(config.gift)
        XCTAssertEqual(gift.productID, StoreManager.giftProductID)
        XCTAssertEqual(gift.grantsProductID, StoreManager.ProductID.pro.rawValue)
        XCTAssertTrue(config.entitlementIDs.contains(gift.grantsProductID))
        XCTAssertEqual(gift.containerIdentifier, "iCloud.com.Ysoup.FeedbackHub")
    }

    func test_플러스는_Pro_권한이_아니다() {
        XCTAssertFalse(config.entitlementIDs.contains(StoreManager.ProductID.remember.rawValue))
        XCTAssertEqual(StoreManager.ProductID.remember.tier, .plus)
        XCTAssertEqual(StoreManager.ProductID.pro.tier, .session)
    }

    func test_새_상품_ID_는_기존_접두사를_따른다() {
        for id in StoreManager.tipProductIDs + [StoreManager.giftProductID] {
            XCTAssertTrue(id.hasPrefix("com.xa.toki."), id)
        }
        XCTAssertEqual(StoreManager.tipProductIDs.count, 3)
    }

    func test_계약과_페이월_구성이_같은_팁_선물_한도를_싣는다() {
        let monetization = RereminderSpec.monetization
        XCTAssertEqual(monetization.gate, config.gate)
        XCTAssertEqual(config.tipJar?.productIDs, StoreManager.tipProductIDs)
    }

    func test_사전_점검에_팁_선물_오류가_없다() {
        let codes = LeeoPreflight.audit(RereminderSpec.self)
            .filter { $0.severity == .error }
            .map(\.code)
        XCTAssertTrue(codes.filter { $0.hasPrefix("gift.") || $0.hasPrefix("tip.") || $0.hasPrefix("paywall.") }.isEmpty,
                      "\(codes)")
    }

    // MARK: - 무료 한도

    func test_무료_한도는_체험_한_바퀴와_같다() {
        let policy = ProGate.gatePolicy
        for feature in ProGate.Feature.allCases where feature.supportsTrial {
            XCTAssertEqual(policy.freeLimits[feature.rawValue], TrialCounter.firstStageLimit, feature.rawValue)
        }
        XCTAssertEqual(policy.proOnly, [ProGate.Feature.unlimitedTemplates.rawValue])
        XCTAssertTrue(policy.hasAnyGate)
        XCTAssertEqual(policy.warnWhenRemaining, 2)
    }

    func test_한도_미리_알림은_두_번_이하_남았을_때만() {
        func left(_ used: Int, extended: Bool = false) -> Int? {
            ProGate.nearLimitRemaining(.presentationMode, used: used, extended: extended, isUnlocked: false)
        }
        XCTAssertNil(left(0), "쓰고 나서 4번 남으면 말하지 않는다")
        XCTAssertNil(left(1))
        XCTAssertEqual(left(2), 2)
        XCTAssertEqual(left(3), 1)
        XCTAssertEqual(left(4), 0, "첫 바퀴의 마지막 한 번")
        XCTAssertNil(left(5), "첫 바퀴를 다 썼고 더 받지 않았다 — 그때는 페이월이 말한다")
        XCTAssertNil(left(5, extended: true), "둘째 바퀴는 처음부터 센다")
        XCTAssertEqual(left(7, extended: true), 2)
        XCTAssertEqual(left(9, extended: true), 0)
    }

    func test_열린_사람과_기억에는_미리_알림이_없다() {
        XCTAssertNil(ProGate.nearLimitRemaining(.presentationMode, used: 4, extended: false, isUnlocked: true))
        XCTAssertNil(ProGate.nearLimitRemaining(.unlimitedTemplates, used: 4, extended: false, isUnlocked: false))
    }

    // MARK: - 팁 부탁의 순간

    func test_숫자가_작으면_팁을_묻지_않는다() {
        XCTAssertTrue(TipAskMoments.reached(focusMinutes: 9 * 60, alertedCompletions: 29).isEmpty)
    }

    func test_넘어선_순간은_인상적인_것부터() {
        let ids = TipAskMoments.reached(focusMinutes: 35 * 60, alertedCompletions: 120).map(\.id)
        XCTAssertEqual(ids, ["hours.30", "hours.10", "alerted.100", "alerted.30"])
    }

    func test_팁_부탁은_규칙대로_드물게() {
        let reached = TipAskMoments.reached(focusMinutes: 12 * 60, alertedCompletions: 0)
        let now = Date()
        XCTAssertEqual(LeeoTipAskPolicy.pick(reached: reached, seen: [], lastAskedAt: nil, lastTipAt: nil,
                                             laters: 0, now: now)?.id, "hours.10")
        XCTAssertNil(LeeoTipAskPolicy.pick(reached: reached, seen: ["hours.10"], lastAskedAt: nil, lastTipAt: nil,
                                           laters: 0, now: now), "같은 순간은 한 번만")
        XCTAssertNil(LeeoTipAskPolicy.pick(reached: reached, seen: [], lastAskedAt: now.addingTimeInterval(-86400),
                                           lastTipAt: nil, laters: 0, now: now), "물은 지 60일 안에는 다시 묻지 않는다")
    }
}
