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
    }

    func attachContext(_ ctx: ModelContext) {
        self.context = ctx
    }

    var state: TimerState { timerVM.state }
    var remaining: TimeInterval { timerVM.remaining }

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
        showTemplateApplyToast(for: t)
        timerVM.start()
    }

    func start() { 
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
        let total = max(0, Int(interval.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
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
            prealertOffsetsSec: normalizedOffsets
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
           top.prealertOffsetsSec == offsets {
            return
        }

        let entry = Timer(
            name: makeTemplateName(mainSec: mainSec, offsets: offsets),
            mainSeconds: mainSec,
            prealertOffsetsSec: offsets
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
    static let maxSeconds = 3600
    static let maxAngle = Double(maxSeconds) / secondsPerDegree
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
