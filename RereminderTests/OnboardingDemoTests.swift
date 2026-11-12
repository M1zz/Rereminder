//
//  OnboardingDemoTests.swift
//  RereminderTests
//
//  첫 실행 그림의 장난감 타이머와 백지 시작 판정.
//

import XCTest
@testable import Rereminder

@MainActor
final class OnboardingDemoTests: XCTestCase {

    func test_speed_followsDemoLength() {
        for total in [600, 1800, 3600] {
            let demo = OnboardingDemoTimer(totalSeconds: total, alerts: [60])
            XCTAssertEqual(Double(total) / demo.speed, OnboardingDemoTimer.demoSeconds, accuracy: 0.01)
        }
    }

    func test_alertsOutsideTheTimer_areDropped() {
        let demo = OnboardingDemoTimer(totalSeconds: 600, alerts: [900, 300, 0, -1])
        XCTAssertEqual(demo.alerts, [300])
    }

    // MARK: - 알림 앞뒤는 실제 속도

    private func warp(_ remaining: Double) -> Double {
        OnboardingDemoTimer.warpSpeed(remaining: remaining, total: 900, alerts: [300, 60])
    }

    /// 종이 울리기 직전부터 울린 직후까지는 1배속이다. 빨리 감긴 채 울리면 무슨 일이 났는지 안 보인다.
    func test_알림과_종료_앞뒤는_실제_속도로_흐른다() {
        for remaining in [302.0, 300, 299, 61, 60, 59, 2, 0] {
            XCTAssertEqual(warp(remaining), 1, "남은 \(remaining)초")
        }
    }

    /// 아무 일도 없는 구간은 빨리 감고, 알림에 다가갈수록 느려진다.
    func test_빈_구간은_빠르고_알림에_다가가며_느려진다() {
        XCTAssertGreaterThan(warp(600), 100)
        XCTAssertGreaterThan(warp(180), 100)
        XCTAssertGreaterThan(warp(320), warp(305))
        XCTAssertGreaterThan(warp(305), 1)
    }

    /// 시작하자마자 최고 속도로 튀지 않는다.
    func test_시작은_천천히_떠난다() {
        XCTAssertEqual(warp(900), 1)
        XCTAssertLessThan(warp(899), warp(880))
    }

    /// 체험이 너무 길어지면 아무도 끝까지 보지 않는다. 15분에 종 둘이 20초 안쪽이어야 한다.
    func test_체험은_이십초_안에_끝난다() {
        var remaining = 900.0
        var seconds = 0.0
        let step = 1.0 / 30.0
        while remaining > 0, seconds < 60 {
            remaining -= step * warp(remaining)
            seconds += step
        }
        XCTAssertLessThan(seconds, 20)
        XCTAssertGreaterThan(seconds, 10)
    }

    /// 기존 사용자는 백지 시작이 아니다 — 온보딩을 봤거나 타이머를 건 적이 있으면 화면이 그대로다.
    func test_blankStart_onlyForNewInstalls() {
        XCTAssertTrue(BlankStart.isNewInstall(hasSeenOnboarding: false, timerStarts: 0))
        XCTAssertFalse(BlankStart.isNewInstall(hasSeenOnboarding: true, timerStarts: 0))
        XCTAssertFalse(BlankStart.isNewInstall(hasSeenOnboarding: false, timerStarts: 3))
    }

    private func stage(new: Bool, runs: Int = 0, pref: BlankStart.Preference = .automatic, session: Bool = false) -> BlankStart.Stage {
        BlankStart.stage(isNewInstall: new, completions: runs, preference: pref, hasUsedSession: session)
    }

    func test_기존_사용자는_고르지_않으면_전부_보인다() {
        XCTAssertEqual(stage(new: false), .everything)
    }

    func test_새_사용자는_완주할수록_하나씩_드러난다() {
        let stages = (0...5).map { stage(new: true, runs: $0) }
        XCTAssertEqual(stages, [.dial, .alerts, .saving, .session, .session, .everything])
    }

    func test_단순하게_골라도_써_본_세션_모드는_남는다() {
        XCTAssertEqual(stage(new: false, pref: .simple), .saving)
        XCTAssertEqual(stage(new: false, pref: .simple, session: true), .session)
    }

    func test_단순하게_고른_사람은_완주해도_저절로_돌아오지_않는다() {
        XCTAssertEqual(stage(new: false, runs: 50, pref: .simple), .saving)
    }

    func test_모든_기능_보기는_언제나_전부다() {
        XCTAssertEqual(stage(new: true, pref: .all), .everything)
        XCTAssertEqual(stage(new: false, pref: .all), .everything)
    }

    func test_복잡한지는_기존_사용자에게_한_번만_묻는다() {
        XCTAssertTrue(BlankStart.shouldAskComplexity(isNewInstall: false, preference: .automatic, alreadyAsked: false))
        XCTAssertFalse(BlankStart.shouldAskComplexity(isNewInstall: false, preference: .automatic, alreadyAsked: true))
        XCTAssertFalse(BlankStart.shouldAskComplexity(isNewInstall: true, preference: .automatic, alreadyAsked: false))
        XCTAssertFalse(BlankStart.shouldAskComplexity(isNewInstall: false, preference: .all, alreadyAsked: false))
    }

    func test_수업은_한_번에_하나씩_놓친_것부터() {
        XCTAssertNil(BlankStart.dueLesson(completions: 0, learned: []))
        XCTAssertEqual(BlankStart.dueLesson(completions: 1, learned: []), .moreAlerts)
        XCTAssertEqual(BlankStart.dueLesson(completions: 3, learned: []), .moreAlerts)
        XCTAssertEqual(BlankStart.dueLesson(completions: 3, learned: [.moreAlerts]), .templates)
        XCTAssertNil(BlankStart.dueLesson(completions: 3, learned: [.moreAlerts, .templates]))
        XCTAssertEqual(BlankStart.dueLesson(completions: 4, learned: [.moreAlerts, .templates]), .overtime)
    }

    func test_차오르기는_첫_시작_전에는_열_때마다_쓰던_사람에게는_한_번() {
        XCTAssertTrue(BlankStart.shouldPlayDialFill(timerStarts: 0, alreadyPlayed: true))
        XCTAssertTrue(BlankStart.shouldPlayDialFill(timerStarts: 20, alreadyPlayed: false))
        XCTAssertFalse(BlankStart.shouldPlayDialFill(timerStarts: 20, alreadyPlayed: true))
    }
}
