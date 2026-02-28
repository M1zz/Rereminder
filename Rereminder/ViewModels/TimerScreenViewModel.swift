//
//  TimerScreenViewModel.swift
//  Rereminder
//
//  Created by xa on 8/27/25.
//
//  리팩토링: AngleCalculator, TimerConfigService 분리
//  Watch 콜백은 여기서만 관리 (TimerViewModel 중복 제거)
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class TimerScreenViewModel: ObservableObject {
    @Published var mainMinutes: Int = 10
    @Published var mainSeconds: Int = 0
    @Published var selectedOffsets: Set<Int> = [60, 300]  // 무료 기본 2개 (1분, 5분)
    @Published private(set) var configuredMainSeconds: Int = 600
    @Published var showTimerAlert: Bool = false
    @Published var prealertMessages: [Int: String] = [:]
    @Published var finishMessage: String = ""
    @Published var showPermissionWarning: Bool = false

    let timerVM: TimerViewModel
    let configService = TimerConfigService()
    var showToast: ((String) -> Void)?

    private var bag = Set<AnyCancellable>()

    // MARK: - Init

    init(timerVM: TimerViewModel? = nil) {
        let vm = timerVM ?? TimerViewModel()
        self.timerVM = vm

        vm.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)

        vm.onTimerFinish = { [weak self] in
            self?.showTimerAlert = true
        }

        // Watch 콜백은 여기서만 등록 (TimerViewModel에서는 제거됨)
        setupWatchConnectivity()
    }

    // MARK: - Watch Connectivity (단일 진입점)

    private func setupWatchConnectivity() {
        let connectivity = WatchConnectivityManager.shared

        connectivity.onTimerStart = { [weak self] syncData in
            guard let self = self else { return }
            let mainSeconds = Int(syncData.duration)
            self.mainMinutes = mainSeconds / 60
            self.mainSeconds = mainSeconds % 60
            self.selectedOffsets = Set(syncData.prealertOffsets)
            self.applyCurrentSettings()
            self.timerVM.start()
            self.showToast?("⌚️ Timer started from Watch")
        }

        connectivity.onTimerPause = { [weak self] in
            self?.timerVM.pause()
            self?.showToast?("⌚️ Paused from Watch")
        }

        connectivity.onTimerResume = { [weak self] in
            self?.timerVM.resume()
            self?.showToast?("⌚️ Resumed from Watch")
        }

        connectivity.onTimerStop = { [weak self] in
            self?.timerVM.stop()
            self?.showToast?("⌚️ Stopped from Watch")
        }
    }

    // MARK: - Context

    func attachContext(_ ctx: ModelContext) {
        configService.attachContext(ctx)
    }

    // MARK: - Computed State

    var state: TimerState { timerVM.state }
    var remaining: TimeInterval { timerVM.remaining }

    /// 다음 알림까지 남은 시간 텍스트
    var nextAlertText: String {
        guard state == .running || state == .overtime else { return "" }
        let remaining = timerVM.remaining
        if remaining < 0 { return "" }

        let upcomingAlerts = selectedOffsets
            .sorted(by: >)
            .filter { Double($0) < remaining }

        if let nextAlert = upcomingAlerts.first {
            let timeUntilNext = remaining - Double(nextAlert)
            let minutes = Int(timeUntilNext) / 60
            let seconds = Int(timeUntilNext) % 60
            let alertMinutes = nextAlert / 60

            if minutes > 0 {
                return String(localized: "Next: \(alertMinutes) min alert (\(minutes) min \(seconds) sec left)")
            } else {
                return String(localized: "Next: \(alertMinutes) min alert (\(seconds) sec left)")
            }
        } else {
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60
            if minutes > 0 {
                return String(localized: "Next: End alert (\(minutes) min \(seconds) sec left)")
            } else if seconds > 0 {
                return String(localized: "Next: End alert (\(seconds) sec left)")
            }
            return ""
        }
    }

    // MARK: - Timer Actions

    func initialConfiguration() {
        justConfigure(save: false, toast: false)
    }

    func applyCurrentSettings() {
        justConfigure(save: true, toast: true)
    }

    func cancel() {
        showToast?("Cancel")
        timerVM.stop()
        justConfigure(save: false, toast: false)
    }

    func apply(template t: Timer) {
        timerVM.configure(from: t)
        configuredMainSeconds = t.mainSeconds
        mainMinutes = max(0, t.mainSeconds) / 60
        mainSeconds = max(0, t.mainSeconds) % 60
        selectedOffsets = Set(t.prealertOffsetsSec)
        prealertMessages = t.prealertMessages
        finishMessage = t.finishMessage ?? ""
        showTemplateApplyToast(for: t)
        timerVM.start()
    }

    func start() {
        if timerVM.appStateManager?.notificationAuthStatus == .denied,
           UserDefaults.standard.bool(forKey: "useAlarmKit") {
            showPermissionWarning = true
            return
        }
        showToast?("Start")
        timerVM.start()
    }

    func pause() {
        showToast?("Pause")
        timerVM.pause()
    }

    func resume() {
        showToast?("Resume")
        timerVM.resume()
    }

    // MARK: - Formatting (delegates to TimeMapper)

    func timeString(from interval: TimeInterval) -> String {
        TimeMapper.formatRemaining(interval)
    }

    func showPrealertToast(for seconds: Int, isEnabled: Bool) {
        let minutes = seconds / 60
        let message = isEnabled ? "\(minutes) min pre-alert set" : "\(minutes) min pre-alert off"
        showToast?(message)
    }

    func showTemplateApplyToast(for template: Timer) {
        let mMain = template.mainSeconds / 60
        let sMain = template.mainSeconds % 60
        let mainLabel = sMain > 0 ? "Main \(mMain) min \(sMain) sec" : "Main \(mMain) min"
        let preList = template.prealertOffsetsSec
            .sorted()
            .map { "\($0/60) min" }
            .joined(separator: ", ")
        let message = preList.isEmpty ? "\(mainLabel), Pre-alert: none" : "\(mainLabel), Pre-alert: \(preList)"
        showToast?(message)
    }

    // MARK: - Internal Configure

    private func justConfigure(save: Bool, toast: Bool) {
        let secPart = max(0, min(59, mainSeconds))
        let mainSec = max(0, mainMinutes) * 60 + secPart

        let normalizedOffsets: [Int] = Array(
            selectedOffsets.filter { $0 > 0 && $0 < mainSec }
        ).sorted()

        let timerName = configService.makeAutoName(mainSec: mainSec)

        let temp = Timer(
            name: timerName,
            mainSeconds: mainSec,
            prealertOffsetsSec: normalizedOffsets,
            prealertMessages: prealertMessages,
            finishMessage: finishMessage.isEmpty ? nil : finishMessage
        )
        timerVM.configure(from: temp)
        configuredMainSeconds = mainSec

        if save {
            configService.saveIfNeeded(
                mainSec: mainSec,
                offsets: normalizedOffsets,
                prealertMessages: prealertMessages,
                finishMessage: finishMessage.isEmpty ? nil : finishMessage
            )
        }

        if toast {
            let mainLabel = secPart > 0 ? "\(mainMinutes)min \(secPart)sec" : "\(mainMinutes)min"
            let preText = normalizedOffsets.map { "\($0/60)min" }.sorted().joined(separator: ", ")
            timerVM.showToast?(
                "Timer applied: \(mainLabel)" + (preText.isEmpty ? "" : " / Pre-alert \(preText)")
            )
        }
    }
}

// MARK: - Angle Binding (delegates to TimeMapper)

extension TimerScreenViewModel {
    var mainAngle: Double {
        get {
            let totalSeconds = max(0, mainMinutes) * 60 + max(0, min(59, mainSeconds))
            return TimeMapper.secondsToAngle(from: totalSeconds)
        }
        set {
            let totalSeconds = TimeMapper.angleToSeconds(from: newValue)
            mainMinutes = totalSeconds / 60
            mainSeconds = totalSeconds % 60
        }
    }

    var configureMainAngle: Double {
        TimeMapper.secondsToAngle(from: configuredMainSeconds)
    }
}
