//
//  PurchaseCompletedReportTests.swift
//  RereminderTests
//
//  결제 완료(`purchase_completed`)를 **새 결제 하나당 한 번만** 센다.
//  페이월 밖의 결제(자녀 구매 승인·프로모션 코드)도 세고, 옛 구매의 복원·가족 공유는 세지 않는다.
//

import XCTest
@testable import Rereminder

final class PurchaseCompletedReportTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_freshOwnPurchase_isReported() {
        XCTAssertTrue(StoreManager.shouldReportPurchase(
            purchaseDate: now.addingTimeInterval(-60),
            isOwnPurchase: true, alreadyReported: false, now: now))
    }

    /// 승인 대기(Ask to Buy)는 며칠 뒤에 도착할 수 있다.
    func test_purchaseApprovedDaysLater_isReported() {
        XCTAssertTrue(StoreManager.shouldReportPurchase(
            purchaseDate: now.addingTimeInterval(-3 * 24 * 3600),
            isOwnPurchase: true, alreadyReported: false, now: now))
    }

    /// 예전에 산 사람이 재설치·새 기기로 복원한 것은 새 결제가 아니다.
    func test_oldPurchaseRestored_isNotReported() {
        XCTAssertFalse(StoreManager.shouldReportPurchase(
            purchaseDate: now.addingTimeInterval(-StoreManager.newPurchaseWindow - 1),
            isOwnPurchase: true, alreadyReported: false, now: now))
    }

    func test_alreadyReported_isNotReportedAgain() {
        XCTAssertFalse(StoreManager.shouldReportPurchase(
            purchaseDate: now.addingTimeInterval(-60),
            isOwnPurchase: true, alreadyReported: true, now: now))
    }

    func test_familyShared_isNotReported() {
        XCTAssertFalse(StoreManager.shouldReportPurchase(
            purchaseDate: now.addingTimeInterval(-60),
            isOwnPurchase: false, alreadyReported: false, now: now))
    }

    // MARK: - flag.isPaid

    /// 평생 무료(그랜드파더링)는 결제가 아니다 — 예전에는 구매 기록이 함께 적혀 유료로 셌다.
    func test_grandfatheredWithStalePurchaseFlag_isNotPaid() {
        XCTAssertFalse(StoreManager.isPaid(storedPurchase: true, grandfathered: true))
    }

    func test_realPurchase_isPaid() {
        XCTAssertTrue(StoreManager.isPaid(storedPurchase: true, grandfathered: false))
    }

    func test_noPurchase_isNotPaid() {
        XCTAssertFalse(StoreManager.isPaid(storedPurchase: false, grandfathered: false))
    }
}
