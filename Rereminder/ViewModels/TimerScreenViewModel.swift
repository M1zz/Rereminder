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

enum AppMode: String, CaseIterable {
    case timer, presentation
}

@MainActor
final class TimerScreenViewModel: ObservableObject {
    @Published var mainMinutes: Int = 10
    @Published var mainSeconds: Int = 0
    @Published var selectedOffsets: Set<Int> = [60] {  // 무료 기본 1개 (1분)
        didSet { sortedOffsetsDesc = selectedOffsets.sorted(by: >) }
    }
    private(set) var sortedOffsetsDesc: [Int] = [60]
    @Published private(set) var configuredMainSeconds: Int = 600
    @Published var showTimerAlert: Bool = false
    @Published var prealertMessages: [Int: String] = [:]
    @Published var finishMessage: String = ""
    @Published var showPermissionWarning: Bool = false

    // MARK: - Presentation Mode
    @Published var currentMode: AppMode = .timer
    @Published var presentationSections: [PresentationSection] = []
    /// 파생 구간의 사용자 지정 이름 (구간 인덱스 → 이름, 비어있으면 placeholder 사용)
    @Published var sectionNames: [Int: String] = [:]

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

        // iCloud KVS 기반 기기 간(iPhone ↔ Mac) 동기화 콜백
        setupCloudSync()
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

    // MARK: - Cloud Sync (iPhone ↔ Mac, 단일 진입점)

    private func setupCloudSync() {
        CloudTimerSyncManager.shared.onRemoteSnapshot = { [weak self] snapshot in
            guard let self = self else { return }
            let device = snapshot.sourceDeviceName

            switch snapshot.state {
            case .running:
                guard let endDate = snapshot.endDate else { return }
                // 이미 같은 타이머를 실행 중이면 무시 (중복 적용 방지)
                if self.timerVM.state == .running,
                   let localEnd = self.timerVM.engine.endDate,
                   abs(localEnd.timeIntervalSince(endDate)) < 1.0 { return }

                self.applyCloudUIFields(mainSeconds: snapshot.mainSeconds, offsets: snapshot.prealertOffsets)
                self.timerVM.applyCloudRunning(
                    mainSeconds: snapshot.mainSeconds,
                    prealertOffsets: snapshot.prealertOffsets,
                    name: snapshot.name,
                    endDate: endDate
                )
                self.showToast?(String(localized: "☁️ Timer synced from \(device)"))

            case .paused:
                guard snapshot.mainSeconds > 0 else { return }
                self.applyCloudUIFields(mainSeconds: snapshot.mainSeconds, offsets: snapshot.prealertOffsets)
                self.timerVM.applyCloudPause(
                    mainSeconds: snapshot.mainSeconds,
                    prealertOffsets: snapshot.prealertOffsets,
                    name: snapshot.name,
                    remaining: snapshot.remaining
                )
                self.showToast?(String(localized: "☁️ Paused from \(device)"))

            case .idle:
                guard self.timerVM.state != .idle else { return }
                self.timerVM.applyCloudStop()
                self.showToast?(String(localized: "☁️ Stopped from \(device)"))
            }
        }
    }

    private func applyCloudUIFields(mainSeconds sec: Int, offsets: [Int]) {
        mainMinutes = sec / 60
        mainSeconds = sec % 60
        configuredMainSeconds = sec
        selectedOffsets = Set(offsets)
    }

    // MARK: - Cold Launch Restore

    /// 앱 시작 시 타이머 상태 복원 시도
    func restoreTimerIfNeeded() {
        guard timerVM.state == .idle else { return }

        if timerVM.restoreIfNeeded() {
            // 복원 성공 — UI 상태 동기화
            if let cfg = timerVM.engine.config {
                let mainSec = Int(cfg.mainDuration)
                mainMinutes = mainSec / 60
                mainSeconds = mainSec % 60
                configuredMainSeconds = mainSec
                selectedOffsets = Set(cfg.prealertOffsetsSec.map { Int($0) })
            }
        }

        // KVS는 앱을 깨우지 못하므로, 다른 기기의 마지막 상태를 여기서 반영
        // (다른 기기에서 시작/정지된 타이머가 로컬 복원 결과를 덮어쓴다)
        CloudTimerSyncManager.shared.applyStoredSnapshotIfNeeded()
    }

    // MARK: - Context

    func attachContext(_ ctx: ModelContext) {
        configService.attachContext(ctx)
    }

    func seedTemplatesIfNeeded() {
        configService.seedIfNeeded()
    }

    // MARK: - Computed State

    var state: TimerState { timerVM.state }
    var remaining: TimeInterval { timerVM.remaining }

    /// 다음 알림까지 남은 시간 텍스트
    var nextAlertText: String {
        guard state == .running || state == .overtime else { return "" }
        let remaining = timerVM.remaining
        if remaining < 0 { return "" }

        let upcomingAlerts = sortedOffsetsDesc
            .filter { Double($0) < remaining }

        if let nextAlert = upcomingAlerts.first {
            let timeUntilNext = remaining - Double(nextAlert)
            let minutes = Int(timeUntilNext) / 60
            let seconds = Int(timeUntilNext) % 60
            let alertLabel = nextAlert < 60
                ? String(localized: "\(nextAlert) sec")
                : String(localized: "\(nextAlert / 60) min")

            if minutes > 0 {
                return String(localized: "Next: \(alertLabel) alert (\(minutes) min \(seconds) sec left)")
            } else {
                return String(localized: "Next: \(alertLabel) alert (\(seconds) sec left)")
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
        persistLastUsedConfig(mainSec: t.mainSeconds, offsets: t.prealertOffsetsSec)
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

    // MARK: - Template Quick Bar (다이얼 아래 저장·템플릿 칩)

    /// 현재 다이얼 설정을 저장 규칙과 동일하게 정규화한 값
    var normalizedCurrentConfig: (mainSec: Int, offsets: [Int]) {
        let secPart = max(0, min(59, mainSeconds))
        let mainSec = max(0, mainMinutes) * 60 + secPart
        let offsets = Array(selectedOffsets.filter { $0 > 0 && $0 < mainSec }).sorted()
        return (mainSec, offsets)
    }

    /// 현재 설정을 템플릿으로 저장한다 (타이머 시작 없음)
    func saveCurrentAsTemplate() {
        let cfg = normalizedCurrentConfig
        guard cfg.mainSec > 0 else { return }
        configService.saveIfNeeded(
            mainSec: cfg.mainSec,
            offsets: cfg.offsets,
            prealertMessages: prealertMessages,
            finishMessage: finishMessage.isEmpty ? nil : finishMessage
        )
        showToast?(String(localized: "Template saved"))
    }

    /// 템플릿 설정만 다이얼에 반영한다 (apply(template:)와 달리 시작하지 않음)
    func load(template t: Timer) {
        mainMinutes = max(0, t.mainSeconds) / 60
        mainSeconds = max(0, t.mainSeconds) % 60
        selectedOffsets = Set(t.prealertOffsetsSec)
        prealertMessages = t.prealertMessages
        finishMessage = t.finishMessage ?? ""
        initialConfiguration()
    }

    // MARK: - Last Used Config (재실행 시 다이얼 복원)

    private static let lastUsedConfigKey = "rereminder.lastUsedConfig.v1"
    private var didRestoreLastUsedConfig = false

    private struct LastUsedConfig: Codable {
        let mainSeconds: Int
        let offsets: [Int]
        let prealertMessages: [Int: String]
        let finishMessage: String
    }

    private func persistLastUsedConfig(mainSec: Int, offsets: [Int]) {
        let cfg = LastUsedConfig(
            mainSeconds: mainSec,
            offsets: offsets,
            prealertMessages: prealertMessages,
            finishMessage: finishMessage
        )
        if let data = try? JSONEncoder().encode(cfg) {
            UserDefaults.standard.set(data, forKey: Self.lastUsedConfigKey)
        }
    }

    /// 앱 시작 시 마지막으로 사용한 타이머 설정을 다이얼에 복원한다 (타이머 시작은 하지 않음).
    /// 실행 중 타이머 복원(restoreTimerIfNeeded)이 성공했으면 건드리지 않는다.
    func restoreLastUsedConfigIfNeeded() {
        guard !didRestoreLastUsedConfig else { return }
        didRestoreLastUsedConfig = true
        guard timerVM.state == .idle,
              let data = UserDefaults.standard.data(forKey: Self.lastUsedConfigKey),
              let cfg = try? JSONDecoder().decode(LastUsedConfig.self, from: data),
              cfg.mainSeconds > 0 else { return }

        mainMinutes = cfg.mainSeconds / 60
        mainSeconds = cfg.mainSeconds % 60
        selectedOffsets = Set(cfg.offsets)
        prealertMessages = cfg.prealertMessages
        finishMessage = cfg.finishMessage
        initialConfiguration()
    }

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
            persistLastUsedConfig(mainSec: mainSec, offsets: normalizedOffsets)
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

// MARK: - Presentation Mode

extension TimerScreenViewModel {
    /// 섹션 배열을 다이얼 상태(총 시간·알림 오프셋·메시지)에 반영 (시작하지 않음)
    /// 발표 모드 진입/구간 편집 후 다이얼과 구간 링이 섹션을 미리 보여주도록 한다
    func applyPresentationSections() {
        guard !presentationSections.isEmpty else { return }

        let totalSeconds = presentationSections.reduce(0) { $0 + $1.durationSeconds }
        guard totalSeconds > 0 else { return }

        // 섹션 경계를 remaining time 기준 pre-alert 오프셋으로 변환
        // 예: Intro(5분) + Main(20분) + Q&A(5분) = 총 30분 (1800초)
        // → Intro 끝: remaining = 1500초, Main 끝: remaining = 300초
        var offsets: [Int] = []
        var messages: [Int: String] = [:]
        var accumulated = 0

        for section in presentationSections {
            accumulated += section.durationSeconds
            let remainingAtEnd = totalSeconds - accumulated

            // 마지막 섹션은 타이머 종료와 동일하므로 pre-alert 불필요
            if remainingAtEnd > 0 && section.alertAtEnd {
                offsets.append(remainingAtEnd)
                messages[remainingAtEnd] = "\(section.name) complete"
            }
        }

        mainMinutes = totalSeconds / 60
        mainSeconds = totalSeconds % 60
        selectedOffsets = Set(offsets)
        prealertMessages = messages
        finishMessage = "Presentation complete"
        configuredMainSeconds = totalSeconds
    }

    /// 다이얼의 알림 지점을 경계로 placeholder 섹션 생성 (발표 탭 파생 모델)
    /// 예: 15분 타이머 + 5분 전 알림 → Section 1(0~10분), Section 2(10~15분)
    func syncSectionsFromAlerts() {
        let mainSec = mainMinutes * 60 + mainSeconds
        guard mainSec > 0 else {
            presentationSections = []
            return
        }
        let boundaries = selectedOffsets
            .filter { $0 > 0 && $0 < mainSec }
            .map { mainSec - $0 }
            .sorted()
        let points = [0] + boundaries + [mainSec]
        presentationSections = (0..<(points.count - 1)).map { i in
            let custom = (sectionNames[i] ?? "").trimmingCharacters(in: .whitespaces)
            return PresentationSection(
                name: custom.isEmpty ? String(localized: "Section \(i + 1)") : custom,
                durationSeconds: points[i + 1] - points[i]
            )
        }
    }

    /// 섹션 배열을 기존 pre-alert 시스템으로 변환하여 타이머 시작
    func startPresentation() {
        guard !presentationSections.isEmpty else { return }

        let totalSeconds = presentationSections.reduce(0) { $0 + $1.durationSeconds }
        guard totalSeconds > 0 else { return }

        applyPresentationSections()
        let offsets = Array(selectedOffsets)
        let messages = prealertMessages

        let template = Timer(
            name: makePresentationName(),
            mainSeconds: totalSeconds,
            prealertOffsetsSec: offsets.sorted(),
            prealertMessages: messages,
            finishMessage: finishMessage,
            label: "Presentation",
            colorHex: Timer.presetColors["Presentation"] ?? "#FF3B30",
            isPresentation: true,
            sectionsData: try? JSONEncoder().encode(presentationSections)
        )

        timerVM.configure(from: template)
        configuredMainSeconds = totalSeconds

        if timerVM.appStateManager?.notificationAuthStatus == .denied,
           UserDefaults.standard.bool(forKey: "useAlarmKit") {
            showPermissionWarning = true
            return
        }

        timerVM.start()
    }

    /// 발표 이름 자동 생성
    private func makePresentationName() -> String {
        let totalSeconds = presentationSections.reduce(0) { $0 + $1.durationSeconds }
        let minutes = totalSeconds / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m Presentation"
            }
            return "\(hours)h Presentation"
        }
        return "\(minutes)m Presentation"
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
