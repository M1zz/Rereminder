//
//  TimerScreenViewModel.swift
//  Toki
//
//  Created by xa on 8/27/25.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class TimerScreenViewModel: ObservableObject {
    @Published var mainMinutes: Int = 10
    @Published var mainSeconds: Int = 0
    @Published var selectedOffsets: Set<Int> = [60, 180, 300]  // prealert settings
    @Published private(set) var configuredMainSeconds: Int = 600
    @Published var showTimerAlert: Bool = false  // 전체 화면 알림 표시
    @Published var prealertMessages: [Int: String] = [:]  // 예비 알림 커스텀 메시지
    @Published var finishMessage: String = ""  // 종료 알림 커스텀 메시지
    @Published var showPermissionWarning: Bool = false  // 권한 경고 표시

    let timerVM: TimerViewModel
    var showToast: ((String) -> Void)?

    private var context: ModelContext?
    private var bag = Set<AnyCancellable>()

    private let limit: Int = 10  // 템플릿 개수 제한 확대 (3 → 10)
    
    // broadcast 'timerVM' to 'ContentView'
    init(timerVM: TimerViewModel? = nil) {
        let vm = timerVM ?? TimerViewModel()
        self.timerVM = vm

        vm.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)

        // 타이머 종료 시 전체 화면 알림 표시
        vm.onTimerFinish = { [weak self] in
            print("🔔 TimerScreenViewModel: showTimerAlert = true 설정")
            self?.showTimerAlert = true
            print("🔔 TimerScreenViewModel: showTimerAlert 현재 값 = \(self?.showTimerAlert ?? false)")
        }

        // Watch로부터 타이머 메시지 수신
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        let connectivity = WatchConnectivityManager.shared

        // Watch에서 타이머 시작
        connectivity.onTimerStart = { [weak self] syncData in
            guard let self = self else { return }

            // 타이머 설정 적용
            let mainSeconds = Int(syncData.duration)
            self.mainMinutes = mainSeconds / 60
            self.mainSeconds = mainSeconds % 60
            // Watch에서 분 단위로 오는 데이터를 초 단위로 변환
            self.selectedOffsets = Set(syncData.prealertOffsets.map { $0 * 60 })

            // 타이머 시작
            self.applyCurrentSettings()
            self.timerVM.start()

            self.showToast?("⌚️ Watch에서 타이머 시작")
        }

        // Watch에서 타이머 일시정지
        connectivity.onTimerPause = { [weak self] in
            self?.timerVM.pause()
            self?.showToast?("⌚️ Watch에서 일시정지")
        }

        // Watch에서 타이머 재개
        connectivity.onTimerResume = { [weak self] in
            self?.timerVM.resume()
            self?.showToast?("⌚️ Watch에서 재개")
        }

        // Watch에서 타이머 중지
        connectivity.onTimerStop = { [weak self] in
            self?.timerVM.stop()
            self?.showToast?("⌚️ Watch에서 중지")
        }
    }

    func attachContext(_ ctx: ModelContext) {
        self.context = ctx
    }

    var state: TimerState { timerVM.state }
    var remaining: TimeInterval { timerVM.remaining }

    /// 다음 알림까지 남은 시간 텍스트
    var nextAlertText: String {
        guard state == .running || state == .overtime else { return "" }

        let remaining = timerVM.remaining

        // 오버타임이면 알림 없음
        if remaining < 0 {
            return ""
        }

        // 예비 알림 중에서 아직 발생하지 않은 것 찾기 (내림차순 정렬)
        let upcomingAlerts = selectedOffsets
            .sorted(by: >)  // 큰 것부터 (가장 먼 알림부터)
            .filter { Double($0) < remaining }

        if let nextAlert = upcomingAlerts.first {
            let timeUntilNext = remaining - Double(nextAlert)
            let minutes = Int(timeUntilNext) / 60
            let seconds = Int(timeUntilNext) % 60

            let alertMinutes = nextAlert / 60

            if minutes > 0 {
                return String(localized: "다음: \(alertMinutes)분 알림 (\(minutes)분 \(seconds)초 후)")
            } else {
                return String(localized: "다음: \(alertMinutes)분 알림 (\(seconds)초 후)")
            }
        } else {
            // 모든 예비 알림이 지나갔으면 종료 알림까지 시간
            let minutes = Int(remaining) / 60
            let seconds = Int(remaining) % 60

            if minutes > 0 {
                return String(localized: "다음: 종료 알림 (\(minutes)분 \(seconds)초 후)")
            } else if seconds > 0 {
                return String(localized: "다음: 종료 알림 (\(seconds)초 후)")
            } else {
                return ""
            }
        }
    }

    /// 앱 진입시 표시될 타이머 세팅
    func initialConfiguration() {
        justConfigure(save: false, toast: false)
    }

    /// 타이머의 설정을 '적용' 하는 경우
    func applyCurrentSettings() {
        justConfigure(save: true, toast: true)
    }

    /// 타이머를 '취소' 하는 경우
    func cancel() {
        showToast?("취소")
        timerVM.stop()
        justConfigure(save: false, toast: false)
    }

    /// 내역에서 타이머를 선택하여 '적용'하는 경우
    func apply(template t: Timer) {
        timerVM.configure(from: t)
        configuredMainSeconds = t.mainSeconds
        mainMinutes = max(0, t.mainSeconds) / 60
        mainSeconds = max(0, t.mainSeconds) % 60
        selectedOffsets = Set(t.prealertOffsetsSec)  // 예비 알림도 동기화
        prealertMessages = t.prealertMessages  // 커스텀 메시지 불러오기
        finishMessage = t.finishMessage ?? ""  // 종료 메시지 불러오기
        showTemplateApplyToast(for: t)
        timerVM.start()
    }

    func start() {
        // 권한 확인 후 경고 표시 (향상된 알림 사용 시에만)
        if timerVM.appStateManager?.notificationAuthStatus == .denied,
           UserDefaults.standard.bool(forKey: "useAlarmKit") {
            showPermissionWarning = true
            return
        }

        showToast?("시작")
        timerVM.start()
    }
    func pause() {
        showToast?("일시정지")
        timerVM.pause()
    }
    func resume() {
        showToast?("재개")
        timerVM.resume()
    }

    func timeString(from interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        if total < 0 {
            // 초과 시간 표시
            let absTotal = abs(total)
            let m = absTotal / 60
            let s = absTotal % 60
            return String(format: "+%02d:%02d", m, s)
        } else {
            let m = total / 60
            let s = total % 60
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    func showPrealertToast(for seconds: Int, isEnabled: Bool) {
        let minutes = seconds / 60
        let message = isEnabled ? "\(minutes)분 예비 알림 설정" : "\(minutes)분 예비 알림 해제"
        showToast?(message)
    }
    
    func showTemplateApplyToast(for template: Timer) {
        let mMain = template.mainSeconds / 60
        let sMain = template.mainSeconds % 60
        
        let mainLabel = sMain > 0 ? "메인 \(mMain)분 \(sMain)초" : "메인 \(mMain)분"
        
        let preList = template.prealertOffsetsSec
            .sorted()
            .map { "\($0/60)분" }
            .joined(separator: ", ")
        
        let message = preList.isEmpty ? "\(mainLabel), 예비: 없음" : "\(mainLabel), 예비: \(preList)"
        showToast?(message)
    }

    func justConfigure(save: Bool, toast: Bool) {
        let secPart = max(0, min(59, mainSeconds))
        let mainSec = max(0, mainMinutes) * 60 + secPart

        let normalizedOffsets: [Int] = Array(
            selectedOffsets
                .filter { $0 > 0 && $0 < mainSec }
        ).sorted()

        let temp = Timer(
            name: "dummy time setting",
            mainSeconds: mainSec,
            prealertOffsetsSec: normalizedOffsets,
            prealertMessages: prealertMessages,
            finishMessage: finishMessage.isEmpty ? nil : finishMessage
        )
        timerVM.configure(from: temp)
        configuredMainSeconds = mainSec

        if save {
            saveIfNeeded(mainSec: mainSec, offsets: normalizedOffsets)
        }

        if toast {
            let mainLabel = secPart > 0 ? "\(mainMinutes)분 \(secPart)초" : "\(mainMinutes)분"
            let preText = normalizedOffsets.map { "\($0/60)분" }.sorted().joined(separator: ", ")
            timerVM.showToast?(
                "타이머 적용: \(mainLabel)" + (preText.isEmpty ? "" : " / 예비 \(preText)")
            )
        }
    }

    private func makeTemplateName(mainSec: Int, offsets: [Int]) -> String {
        let m = max(0, mainSec) / 60
        let s = max(0, mainSec) % 60
        let base = s > 0 ? "메인 \(m)분 \(s)초" : "메인 \(m)분"
        if offsets.isEmpty { return base }
        let pre = offsets.map { "\($0/60)" }.joined(separator: "·")
        return "\(base) / 예비 \(pre)분"
    }
}


extension TimerScreenViewModel {
    private func fetchRecents() -> [Timer] {
        guard let ctx = context else { return [] }
        let desc = FetchDescriptor<Timer>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? ctx.fetch(desc)) ?? []
    }

    private func saveIfNeeded(mainSec: Int, offsets: [Int]) {
        guard let ctx = context else { return }

        // don't save duplicated template
        let currentTop = fetchRecents().first
        if let top = currentTop,
           top.mainSeconds == mainSec,
           top.prealertOffsetsSec == offsets,
           top.prealertMessages == prealertMessages,
           top.finishMessage == (finishMessage.isEmpty ? nil : finishMessage) {
            return
        }

        let entry = Timer(
            name: makeTemplateName(mainSec: mainSec, offsets: offsets),
            mainSeconds: mainSec,
            prealertOffsetsSec: offsets,
            prealertMessages: prealertMessages,
            finishMessage: finishMessage.isEmpty ? nil : finishMessage
        )
        ctx.insert(entry)
        try? ctx.save()

        // delete old template
        let recents = fetchRecents()
        if recents.count > limit {
            for old in recents.dropFirst(limit) {
                ctx.delete(old)
            }
            try? ctx.save()
        }
    }
}

extension TimerScreenViewModel {
    var mainAngle: Double {
        get {
            let totalSeconds = max(0, mainMinutes) * 60 + max(0, min(59, mainSeconds))
            return TimeMapper.secondsToAngle(from: totalSeconds)
        }
        set {
            let totalSeconds = TimeMapper.angleToSeconds(from: newValue)
            let m = totalSeconds / 60
            let s = totalSeconds % 60
            self.mainMinutes = m
            self.mainSeconds = s
        }
    }
    var configureMainAngle: Double {
        TimeMapper.secondsToAngle(from: configuredMainSeconds)
    }
}

enum TimeMapper {
    static let secondsPerDegree = 10.0  // 1° = 10초
    static let maxSeconds = 7200  // 120분
    static let maxAngle = Double(maxSeconds) / secondsPerDegree  // 720도 (2바퀴)
    static let tickCount = 60

    static func secondsToAngle(from s: Int) -> Double {
        let clamped = max(0, min(s, maxSeconds))
        return Double(clamped) / secondsPerDegree
    }
    static func angleToSeconds(from a: Double) -> Int {
        let clamped = max(0, min(a, maxAngle))
        return Int(round(clamped)) * Int(secondsPerDegree)
    }
}
