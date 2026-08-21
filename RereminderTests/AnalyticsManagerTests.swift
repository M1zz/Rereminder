//
//  AnalyticsManagerTests.swift
//  RereminderTests
//
//  AnalyticsManager 이벤트 인코딩 테스트
//  Firebase 호출 자체는 테스트하지 않고, Event enum 의 name/parameters 매핑만 검증
//

import XCTest
@testable import Rereminder

final class AnalyticsManagerTests: XCTestCase {

    // MARK: - Timer events

    func test_timerStarted_withoutPreset_hasDurationOnly() {
        let event = AnalyticsManager.Event.timerStarted(durationSeconds: 600, alertCount: 1, presetName: nil)
        XCTAssertEqual(event.name, "timer_started")
        XCTAssertEqual(event.parameters["duration_seconds"] as? Int, 600)
        XCTAssertNil(event.parameters["preset_name"])
    }

    func test_timerStarted_withPreset_includesPresetName() {
        let event = AnalyticsManager.Event.timerStarted(durationSeconds: 600, alertCount: 3, presetName: "Workout")
        XCTAssertEqual(event.parameters["duration_seconds"] as? Int, 600)
        XCTAssertEqual(event.parameters["preset_name"] as? String, "Workout")
    }

    func test_timerCompleted_includesDuration() {
        let event = AnalyticsManager.Event.timerCompleted(durationSeconds: 1500)
        XCTAssertEqual(event.name, "timer_completed")
        XCTAssertEqual(event.parameters["duration_seconds"] as? Int, 1500)
    }

    func test_timerCancelled_includesRemainingSeconds() {
        let event = AnalyticsManager.Event.timerCancelled(remainingSeconds: 300)
        XCTAssertEqual(event.name, "timer_cancelled")
        XCTAssertEqual(event.parameters["remaining_seconds"] as? Int, 300)
    }

    // MARK: - Premium events

    func test_premiumFeatureUsed_includesFeatureAndCount() {
        let event = AnalyticsManager.Event.premiumFeatureUsed(
            feature: .presentationMode,
            trialCount: 3
        )
        XCTAssertEqual(event.name, "premium_feature_used")
        XCTAssertEqual(event.parameters["feature"] as? String, "presentationMode")
        XCTAssertEqual(event.parameters["trial_count"] as? Int, 3)
    }

    func test_premiumTrialExhausted_includesFeatureAndStage() {
        let event = AnalyticsManager.Event.premiumTrialExhausted(
            feature: .timerHistory,
            stage: .second
        )
        XCTAssertEqual(event.name, "premium_trial_exhausted")
        XCTAssertEqual(event.parameters["feature"] as? String, "timerHistory")
        XCTAssertEqual(event.parameters["stage"] as? String, "second")
    }

    // MARK: - Paywall events

    func test_paywallShown_withTrigger_includesFeatureName() {
        let event = AnalyticsManager.Event.paywallShown(trigger: .presentationMode)
        XCTAssertEqual(event.name, "paywall_shown")
        XCTAssertEqual(event.parameters["trigger"] as? String, "presentationMode")
    }

    func test_paywallShown_noTrigger_usesGeneralValue() {
        let event = AnalyticsManager.Event.paywallShown(trigger: nil)
        XCTAssertEqual(event.parameters["trigger"] as? String, "general")
    }

    func test_paywallDismissed_includesPurchaseFlag() {
        let event = AnalyticsManager.Event.paywallDismissed(
            trigger: .overtimeTracking,
            didPurchase: true
        )
        XCTAssertEqual(event.name, "paywall_dismissed")
        XCTAssertEqual(event.parameters["trigger"] as? String, "overtimeTracking")
        XCTAssertEqual(event.parameters["did_purchase"] as? Bool, true)
    }

    func test_paywallOneMoreClicked_hasFeatureName() {
        let event = AnalyticsManager.Event.paywallOneMoreClicked(trigger: .timerHistory)
        XCTAssertEqual(event.name, "paywall_one_more_clicked")
        XCTAssertEqual(event.parameters["trigger"] as? String, "timerHistory")
    }

    // MARK: - Purchase events

    func test_purchaseStarted_includesProductId() {
        let event = AnalyticsManager.Event.purchaseStarted(productId: "com.xa.toki.pro")
        XCTAssertEqual(event.name, "purchase_started")
        XCTAssertEqual(event.parameters["product_id"] as? String, "com.xa.toki.pro")
    }

    func test_purchaseCompleted_includesProductId() {
        let event = AnalyticsManager.Event.purchaseCompleted(productId: "com.xa.toki.pro")
        XCTAssertEqual(event.name, "purchase_completed")
        XCTAssertEqual(event.parameters["product_id"] as? String, "com.xa.toki.pro")
    }

    func test_purchaseFailed_includesProductIdAndReason() {
        let event = AnalyticsManager.Event.purchaseFailed(
            productId: "com.xa.toki.pro",
            reason: "user_cancelled"
        )
        XCTAssertEqual(event.name, "purchase_failed")
        XCTAssertEqual(event.parameters["product_id"] as? String, "com.xa.toki.pro")
        XCTAssertEqual(event.parameters["reason"] as? String, "user_cancelled")
    }

    func test_purchaseRestored_hasNoParameters() {
        let event = AnalyticsManager.Event.purchaseRestored
        XCTAssertEqual(event.name, "purchase_restored")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    // MARK: - Misc events

    func test_reviewRequested_hasNoParameters() {
        let event = AnalyticsManager.Event.reviewRequested
        XCTAssertEqual(event.name, "review_requested")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    func test_reviewCompleted_hasNoParameters() {
        let event = AnalyticsManager.Event.reviewCompleted
        XCTAssertEqual(event.name, "review_completed")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    func test_presentationModeStarted_hasNoParameters() {
        let event = AnalyticsManager.Event.presentationModeStarted
        XCTAssertEqual(event.name, "presentation_mode_started")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    func test_watchSyncUsed_hasNoParameters() {
        let event = AnalyticsManager.Event.watchSyncUsed
        XCTAssertEqual(event.name, "watch_sync_used")
        XCTAssertTrue(event.parameters.isEmpty)
    }

    // MARK: - Preset events

    func test_presetSaved_includesNameAndDuration() {
        let event = AnalyticsManager.Event.presetSaved(name: "Pomodoro", durationSeconds: 1500)
        XCTAssertEqual(event.name, "preset_saved")
        XCTAssertEqual(event.parameters["preset_name"] as? String, "Pomodoro")
        XCTAssertEqual(event.parameters["duration_seconds"] as? Int, 1500)
    }

    func test_presetUsed_includesName() {
        let event = AnalyticsManager.Event.presetUsed(name: "Pomodoro")
        XCTAssertEqual(event.name, "preset_used")
        XCTAssertEqual(event.parameters["preset_name"] as? String, "Pomodoro")
    }
}
