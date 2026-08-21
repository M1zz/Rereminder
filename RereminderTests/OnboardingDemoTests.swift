//
//  OnboardingDemoTests.swift
//  RereminderTests
//
//  온보딩 체험의 속도 규칙 — **길이와 상관없이 10초 안에 끝나야 한다.**
//  배속을 고정해 두면 30분짜리 상황이 30초를 잡아먹는다(온보딩에서 30초는 아무도 안 기다린다).
//

import XCTest
@testable import Rereminder

@MainActor
final class OnboardingDemoTests: XCTestCase {

    func test_speed_scalesWithLength_soEveryDemoEndsInTenSeconds() {
        for useCase in OnboardingUseCase.all {
            let demo = OnboardingDemoTimer(totalSeconds: useCase.totalSeconds, alerts: useCase.alerts)
            let realSeconds = Double(useCase.totalSeconds) / demo.speed
            XCTAssertEqual(realSeconds, OnboardingDemoTimer.demoSeconds, accuracy: 0.01,
                           "\(useCase.id) 체험이 10초를 벗어난다")
        }
    }

    func test_everySuggestedUseCase_hasAtLeastTwoAlerts() {
        // 알림이 하나뿐이면 "끝나기 전에 여러 번"을 체험에서 보여 줄 수 없다
        for useCase in OnboardingUseCase.all {
            XCTAssertGreaterThanOrEqual(useCase.alerts.count, 2, "\(useCase.id)")
            for alert in useCase.alerts {
                XCTAssertLessThan(alert, useCase.totalSeconds, "\(useCase.id) 알림이 타이머보다 길다")
            }
        }
    }

    func test_alertsOutsideTheTimer_areDropped() {
        let demo = OnboardingDemoTimer(totalSeconds: 600, alerts: [900, 300, 0, -1])
        XCTAssertEqual(demo.alerts, [300])
    }
}
