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

    /// 구간 이름은 **알림 경계에서 파생**된다 — 알림 N개면 구간은 N+1개다.
    /// 개수가 어긋나면 이름이 조용히 빠지거나 엉뚱한 구간에 붙는다.
    func test_sectionNames_matchTheSectionsTheAlertsCreate() {
        for useCase in OnboardingUseCase.all where !useCase.sectionNames.isEmpty {
            XCTAssertEqual(useCase.sectionNames.count, useCase.alerts.count + 1,
                           "\(useCase.id) 구간 이름 수가 알림이 만드는 구간 수와 다르다")
        }
    }

    /// 다이얼이 받을 수 있는 길이여야 한다 — 넘으면 온보딩이 권한 설정을 화면이 표현하지 못한다.
    func test_everyUseCaseFitsOnTheDial() {
        for useCase in OnboardingUseCase.all {
            XCTAssertLessThanOrEqual(useCase.minutes, TimeMapper.maxMinutes, "\(useCase.id)")
        }
    }

    /// ⚠️ 요리는 일부러 뺐다 — 시리를 이길 수 없는 싸움이고, 고른 사람은 이틀 뒤 앱을 지운다.
    /// 그리고 **돈을 내는 상황**(남 앞에서 시간을 운영하는 것)이 목록에 있어야 한다.
    func test_theListSpeaksToPeopleWhoRunTimeForOthers() {
        let ids = Set(OnboardingUseCase.all.map(\.id))
        XCTAssertFalse(ids.contains("cooking"), "요리를 되살렸다 — OnboardingUseCase 머리말 참고")
        XCTAssertTrue(ids.isSuperset(of: ["presentation", "class", "workshop"]))
    }

    func test_alertsOutsideTheTimer_areDropped() {
        let demo = OnboardingDemoTimer(totalSeconds: 600, alerts: [900, 300, 0, -1])
        XCTAssertEqual(demo.alerts, [300])
    }
}
