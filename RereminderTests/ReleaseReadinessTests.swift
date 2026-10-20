//
//  ReleaseReadinessTests.swift
//  RereminderTests
//
//  출시 전에 지켜야 할 것들 — LeeoKit 사전 점검, "새로 생긴 것" 안내의 대상, 내 혜택 화면의 셈법.
//

import XCTest
import LeeoKit
@testable import Rereminder

final class ReleaseReadinessTests: XCTestCase {

    // MARK: - LeeoKit 사전 점검

    /// 부트스트랩의 DEBUG 감사와 별개로 시험이 지킨다 — 개인정보·지원 주소, 결제 상품 선언 등이 비면 여기서 걸린다.
    func testPreflightIsReleasable() {
        let issues = LeeoPreflight.audit(RereminderSpec.self)
        XCTAssertTrue(issues.isReleasable,
                      issues.map { "\($0.severity.symbol) \($0.code): \($0.message)" }.joined(separator: "\n"))
    }

    func testFamilyIDIsInCatalog() {
        XCTAssertEqual(RereminderSpec.familyID, "rereminder")
        // 자기 자신은 함께 쓰는 앱 목록에서 빠져야 한다.
        XCTAssertFalse(LeeoFamilyCatalog.others(for: RereminderSpec.self).contains { $0.id == "rereminder" })
    }

    // MARK: - 새로 생긴 것

    func testNewcomerNeverSeesWhatsNew() {
        XCTAssertEqual(WhatsNewAudience.resolve(hasSeenOnboarding: false, lastSeenVersion: nil), .newcomer)
        XCTAssertEqual(WhatsNewAudience.resolve(hasSeenOnboarding: false, lastSeenVersion: "2.0.0"), .newcomer)
    }

    func testUpdatedUserSeesWhatsNewOnce() {
        XCTAssertEqual(WhatsNewAudience.resolve(hasSeenOnboarding: true, lastSeenVersion: nil,
                                                currentVersion: "2.3.4"), .returningNeedsWhatsNew)
        XCTAssertEqual(WhatsNewAudience.resolve(hasSeenOnboarding: true, lastSeenVersion: "2.3.3",
                                                currentVersion: "2.3.4"), .returningNeedsWhatsNew)
        XCTAssertEqual(WhatsNewAudience.resolve(hasSeenOnboarding: true, lastSeenVersion: "2.3.4",
                                                currentVersion: "2.3.4"), .returning)
    }

    // MARK: - 내 혜택

    /// 시드는 사용자가 저장한 것이 아니다 — 세면 무료로도 가졌을 것을 산 덕으로 부풀린다.
    func testOwnSetupCountSkipsSeeds() {
        let names = ["Study 25 min", "Meeting 60 min", "Morning standup", "Main 25 min / Pre-alert 5 min"]
        XCTAssertEqual(ProBenefitsView.Usage.ownSetupCount(names: names), 2)
    }

    /// 한도는 게이트와 같은 상수를 쓴다.
    func testLimitRowsUseGateConstants() {
        var usage = ProBenefitsView.Usage()
        usage.savedSetups = 4
        usage.sessions = 13

        let remember = ProBenefitsView.limitRows(tier: .plus, usage: usage)
        XCTAssertEqual(remember.map(\.id), ["setups"])
        XCTAssertEqual(remember.first?.freeLimit, ProGate.freeSavedSetups)
        XCTAssertEqual(remember.first?.extra, 4)

        let pro = ProBenefitsView.limitRows(tier: .session, usage: usage)
        XCTAssertEqual(pro.map(\.id), ["setups", "sessions"])
        XCTAssertEqual(pro.last?.freeLimit, TrialCounter.secondStageLimit)
        XCTAssertEqual(pro.last?.extra, 13 - TrialCounter.secondStageLimit)

        XCTAssertTrue(ProBenefitsView.limitRows(tier: .free, usage: usage).isEmpty)
    }

    func testExtraIsNeverNegative() {
        var usage = ProBenefitsView.Usage()
        usage.sessions = 3
        let pro = ProBenefitsView.limitRows(tier: .session, usage: usage)
        XCTAssertEqual(pro.last?.extra, 0)
    }

    // MARK: - 개발자에게 메일

    func testDeveloperMailURL() throws {
        let url = try XCTUnwrap(NoticeSettingView.developerMailURL)
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertTrue(url.absoluteString.contains(RereminderSpec.developerEmail))
    }
}
