//
//  FeedbackRecordMappingTests.swift
//  RereminderTests
//
//  CloudKit Feedback 레코드 → 조회용 read model 매핑 리그레션 테스트
//  네트워크 없이 CKRecord를 로컬에서 만들어 필드 매핑만 검증한다.
//

import CloudKit
import XCTest
@testable import Rereminder

final class FeedbackRecordMappingTests: XCTestCase {

    private func makeRecord() -> CKRecord {
        let record = CKRecord(recordType: FeedbackService.recordType)
        record["type"] = "bug"
        record["message"] = "타이머가 멈춰요"
        record["deviceInfo"] = "2.0.3 (1) · iPhone17,1 · iOS 26.0"
        record["appVersion"] = "2.0.3"
        record["locale"] = "ko_KR"
        record["platform"] = "iOS"
        return record
    }

    func test_init_mapsAllFields() {
        let feedback = FeedbackService.FeedbackRecord(makeRecord())

        XCTAssertEqual(feedback.type, "bug")
        XCTAssertEqual(feedback.message, "타이머가 멈춰요")
        XCTAssertEqual(feedback.deviceInfo, "2.0.3 (1) · iPhone17,1 · iOS 26.0")
        XCTAssertEqual(feedback.appVersion, "2.0.3")
        XCTAssertEqual(feedback.locale, "ko_KR")
        XCTAssertEqual(feedback.platform, "iOS")
        XCTAssertNil(feedback.status)
        XCTAssertFalse(feedback.isDone)
    }

    func test_init_missingFields_fallBackToPlaceholders() {
        let empty = CKRecord(recordType: FeedbackService.recordType)

        let feedback = FeedbackService.FeedbackRecord(empty)

        XCTAssertEqual(feedback.type, "-")
        XCTAssertEqual(feedback.message, "")
        XCTAssertEqual(feedback.appVersion, "-")
        XCTAssertFalse(feedback.isDone)
    }

    func test_isDone_reflectsStatusField() {
        let record = makeRecord()
        record["status"] = "done"

        var feedback = FeedbackService.FeedbackRecord(record)
        XCTAssertTrue(feedback.isDone)

        feedback.status = nil
        XCTAssertFalse(feedback.isDone)
    }
}
