//
//  RereminderSpecTests.swift
//  RereminderTests
//
//  LeeoAppSpec 준수값의 리그레션 테스트 — CloudKit Dashboard·기존 사용자 기기와의 계약.
//  레코드 매핑 등 일반 피드백 로직 테스트는 LeeoKit(LeeoFeedbackServiceTests)에 있다.
//

import XCTest
import LeeoKit
@testable import Rereminder

final class RereminderSpecTests: XCTestCase {

    func testContainerIdentifierMatchesEntitlements() {
        // Rereminder.entitlements의 iCloud 컨테이너와 어긋나면 제출이 조용히 실패한다
        XCTAssertEqual(RereminderSpec.feedback.containerIdentifier, "iCloud.com.xa.toki")
    }

    func testRecordTypeIsStable() {
        // Dashboard의 Record Type 이름 — 바꾸면 기존 피드백이 전부 조회에서 빠진다
        XCTAssertEqual(RereminderSpec.feedback.recordType, "Feedback")
    }

    func testNewFeedbackSubscriptionIDIsStable() {
        // 서버에 저장된 구독 ID — 바꾸면 기존 기기의 구독을 해제할 수 없게 된다
        XCTAssertEqual(RereminderSpec.feedback.subscriptionID, "feedback-new-v1")
    }

    func testAppIdentifierStaysNilForLegacySchema() {
        // appId 필드는 Production 스키마에 없다 — 공용 허브 전환 전까지 nil 유지
        XCTAssertNil(RereminderSpec.feedback.appIdentifier)
    }

    func testAppNameAndDeveloperEmail() {
        XCTAssertEqual(RereminderSpec.appName, "두번알림")
        XCTAssertEqual(RereminderSpec.developerEmail, "leeo@kakao.com")
    }
}
