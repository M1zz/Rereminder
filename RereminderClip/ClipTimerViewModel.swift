//
//  ClipTimerViewModel.swift
//  RereminderClip
//
//  본 앱의 TimerEngine을 그대로 쓰되, 클립에 필요한 만큼만 노출한다.
//  (발표 모드·템플릿·통계는 전체 앱 기능)
//
//  시간 편집은 메인 앱과 같은 규칙을 따른다.
//  - 대기 중에는 `mainAngle`(1° = 10초, 최대 2바퀴)이 시간의 원본이고,
//    링·드래그 핸들·종 노브가 모두 이 각도 위에서 움직인다.
//  - 실행 중에는 남은 비율로 바뀐다.
//

import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class ClipTimerViewModel: ObservableObject {

    /// 한 번에 고를 수 있는 총 시간 프리셋 (초)
    static let durationPresets: [Int] = [10 * 60, 30 * 60, 60 * 60]

    // MARK: - Published State

    /// 대기 중 시간의 원본 — 메인 앱과 같은 각도 좌표 (1° = 10초)
    @Published private(set) var mainAngle: Double = TimeMapper.secondsToAngle(from: 30 * 60)

    /// "끝나기 N초 전" 알림 지점 (내림차순). 처음엔 자동 배분, 사용자가 종을 옮기면 그 값을 따른다.
    @Published private(set) var alertOffsets: [Int] = ClipAlertPlanner.offsets(totalSeconds: 30 * 60)

    @Published private(set) var remaining: TimeInterval = 30 * 60
    @Published private(set) var state: TimerState = .idle

    /// 알림 권한을 거절당해 백그라운드 알림이 안 갈 수 있는 상태
    @Published private(set) var notificationsDenied = false

    /// 전체 앱 설치를 권하는 App Store 오버레이 표시 여부
    @Published var showAppStoreOverlay = false

    /// 사용자가 종을 한 번이라도 옮겼는지 — 옮긴 뒤에는 시간이 바뀌어도 자동 재배분하지 않는다.
    private var hasCustomizedAlerts = false

    // MARK: - Derived

    var totalSeconds: Int { max(TimeMapper.angleToSeconds(from: mainAngle), 10) }

    var isRunning: Bool { state == .running || state == .overtime }

    /// 시간·알림 지점 편집은 대기 중에만 (메인 앱과 동일)
    var isEditable: Bool { state == .idle }

    /// 남은 비율 (실행 중 링 좌표)
    var remainingRatio: CGFloat {
        CGFloat(max(0, min(1, remaining / TimeInterval(max(1, totalSeconds)))))
    }

    // MARK: - Engine

    private let engine = TimerEngine()

    init() {
        engine.onTick = { [weak self] value in
            Task { @MainActor in self?.remaining = value }
        }
        engine.onPreAlert = { [weak self] _ in
            Task { @MainActor in ring() }
        }
        engine.onFinish = { [weak self] in
            Task { @MainActor in self?.handleFinish() }
        }
    }

    // MARK: - 시간 편집

    /// 다이얼 드래그 — 메인 앱과 같은 각도 좌표를 그대로 받는다.
    func updateMainAngle(_ angle: Double) {
        guard isEditable else { return }
        mainAngle = max(0, min(angle, TimeMapper.maxAngle))
        remaining = TimeInterval(totalSeconds)
        reseedAlertsIfNeeded()
    }

    func selectDuration(_ seconds: Int) {
        guard isEditable else { return }
        mainAngle = TimeMapper.secondsToAngle(from: seconds)
        remaining = TimeInterval(totalSeconds)
        reseedAlertsIfNeeded()
    }

    /// 종 노브 드래그 — 옮긴 지점이 총 시간 안이면 반영한다.
    func moveAlert(from oldOffset: Int, to newOffset: Int) {
        guard isEditable else { return }
        var offsets = Set(alertOffsets)
        offsets.remove(oldOffset)
        if newOffset > 0 && newOffset < totalSeconds {
            offsets.insert(newOffset)
        }
        alertOffsets = offsets.sorted(by: >)
        hasCustomizedAlerts = true
    }

    /// 사용자가 손댄 적 없을 때만 총 시간에 맞춰 알림 지점을 다시 잡는다.
    private func reseedAlertsIfNeeded() {
        guard !hasCustomizedAlerts else {
            // 시간이 줄어 총 시간 밖으로 나간 지점은 버린다.
            alertOffsets = alertOffsets.filter { $0 > 0 && $0 < totalSeconds }
            return
        }
        alertOffsets = ClipAlertPlanner.offsets(totalSeconds: totalSeconds)
    }

    // MARK: - 타이머 제어

    func start() {
        requestNotificationAuthorizationIfNeeded()
        engine.configure(
            mainSeconds: totalSeconds,
            prealertOffsetsSec: alertOffsets,
            name: ""
        )
        engine.start()
        state = engine.state
    }

    func pause() {
        engine.pause()
        state = engine.state
    }

    func resume() {
        engine.resume()
        state = engine.state
    }

    func reset() {
        engine.stop()
        state = engine.state
        remaining = TimeInterval(totalSeconds)
    }

    /// 앱이 포그라운드로 돌아오면 남은 시간을 절대 시각 기준으로 다시 맞춘다.
    func refreshOnForeground() {
        engine.recalculateOnForeground()
        state = engine.state
    }

    // MARK: - App Clip 호출 URL

    /// `https://.../clip?minutes=30` 형태의 호출 URL에서 시작 시간을 읽는다.
    /// 값이 없거나 범위를 벗어나면 기본값(30분)을 유지한다.
    func handle(invocationURL: URL?) {
        guard let invocationURL,
              let components = URLComponents(url: invocationURL, resolvingAgainstBaseURL: false),
              let raw = components.queryItems?.first(where: { $0.name == "minutes" })?.value,
              let minutes = Int(raw),
              (1...120).contains(minutes) else { return }

        selectDuration(minutes * 60)
    }

    // MARK: - Private

    private func handleFinish() {
        state = engine.state
        ring()
        // 타이머를 끝까지 경험한 시점 = 전체 앱을 권하기 가장 좋은 순간
        showAppStoreOverlay = true
    }

    private func requestNotificationAuthorizationIfNeeded() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            // App Clip 카드에서 이미 허용했으면(.ephemeral 포함) 다시 묻지 않는다.
            guard settings.authorizationStatus == .notDetermined else {
                await MainActor.run {
                    self.notificationsDenied = (settings.authorizationStatus == .denied)
                }
                return
            }
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            await MainActor.run { self.notificationsDenied = !granted }
        }
    }
}
