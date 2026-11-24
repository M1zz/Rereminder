//
//  MenuBarManager.swift
//  Rereminder
//
//  Mac Catalyst 전용 — RereminderMenuBar.bundle(AppKit)을 런타임 로드해서
//  메뉴바에 타이머 남은 시간을 표시한다
//
//  번들이 아직 임베드되지 않은 빌드에서는 조용히 no-op (iOS에서는 통째로 컴파일 제외)
//

import Foundation

#if targetEnvironment(macCatalyst)
import UIKit

@MainActor
final class MenuBarManager {
    static let shared = MenuBarManager()

    /// 번들이 아직 없을 때 받은 목록 — 번들을 올리면 넘긴다.
    private var setups: [[String: String]] = []

    /// 마지막으로 알린 상태 — 일시정지 버튼이 멈출지 이어 갈지 가른다.
    private var lastState: TimerState = .idle

    private var controller: NSObject?

    /// ⚠️ 메뉴의 버튼은 화면(`TimerUnifiedView`)을 직접 부르지 않는다. 화면은 **창에 묶여 있어서**,
    ///    창을 닫으면 함께 사라지고 메뉴를 눌러도 아무 일도 없었다. 그래서 위젯·잠금화면 버튼과 같은 길로 보낸다:
    ///    요청을 남기고(`QuickStartShelf` · `LiveActivityCommandStore`) 알린다. 창이 있으면 그 자리에서 받고,
    ///    없으면 창을 다시 연다 — 새 창이 뜨면서 저장된 타이머를 되살린 **뒤** 남은 요청을 처리한다.
    private init() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: Notification.Name("RRMenuBarPauseTapped"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.send(self?.lastState == .paused ? .resume : .pause) }
        }
        center.addObserver(
            forName: Notification.Name("RRMenuBarStopTapped"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.send(.stop) }
        }
        center.addObserver(
            forName: Notification.Name("RRMenuBarStartTapped"), object: nil, queue: .main
        ) { [weak self] note in
            guard let id = note.userInfo?["id"] as? String else { return }
            Task { @MainActor in self?.start(id) }
        }
        center.addObserver(
            forName: Notification.Name("RRMenuBarOpenTapped"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.showWindow() }
        }
    }

    private func send(_ command: LiveActivityCommand) {
        if !command.dispatch() { showWindow() }
    }

    private func start(_ id: String) {
        QuickStartShelf.request(templateID: id)
        NotificationCenter.default.post(name: .quickStartRequested, object: nil)
        if QuickStartShelf.hasPendingRequest { showWindow() }
    }

    /// 창이 있으면 앞으로, 닫혀 있으면 다시 연다.
    func showWindow() {
        let hasWindow = UIApplication.shared.connectedScenes.contains { $0 is UIWindowScene }
        if !hasWindow {
            UIApplication.shared.requestSceneSessionActivation(
                UIApplication.shared.openSessions.first { $0.role == .windowApplication },
                userActivity: nil, options: nil, errorHandler: nil)
        }
        bringAppForward()
    }

    /// PlugIns 안의 메뉴바 번들을 로드하고 상태 아이템 생성
    func setUpIfAvailable() {
        guard controller == nil else { return }

        guard let url = Bundle.main.builtInPlugInsURL?
                .appendingPathComponent("RereminderMenuBar.bundle") else {
            NSLog("%@", "🖥️ MenuBar: PlugIns URL 없음")
            return
        }
        guard let bundle = Bundle(url: url) else {
            NSLog("%@", "🖥️ MenuBar: 번들 없음 — \(url.path)")
            return
        }
        guard bundle.load() else {
            NSLog("%@", "🖥️ MenuBar: 번들 로드 실패 — \(url.path)")
            return
        }
        guard let principal = bundle.principalClass as? NSObject.Type else {
            NSLog("%@", "🖥️ MenuBar: principalClass 없음 — \(String(describing: bundle.principalClass))")
            return
        }
        let instance = principal.init()
        controller = instance
        _ = instance.perform(NSSelectorFromString("show"))
        pushSetups()
        NSLog("%@", "🖥️ MenuBar: 상태 아이템 생성 완료")
    }

    /// 메뉴에서 바로 걸 목록 — 저장한 설정(위젯과 같은 순서·이름) 뒤에 포모도로.
    /// ⚠️ 거는 길은 위젯과 같다(`apply(template:)`). 메뉴에는 무엇을 보여 줄지만 넘긴다.
    func setSetups(_ items: [QuickStartItem]) {
        setups = items.map { item in
            ["id": item.id, "title": item.durationText, "subtitle": item.name, "symbol": "play.fill"]
        } + [[
            "id": Pomodoro.menuID,
            "title": String(localized: "Pomodoro"),
            "subtitle": Pomodoro.shapeText,
            "symbol": "repeat",
        ]]
        pushSetups()
    }

    private func pushSetups() {
        guard let controller else { return }
        _ = controller.perform(NSSelectorFromString("setSetups:"), with: setups as NSArray)
    }

    /// 앱 창을 앞으로 가져온다 — 메뉴에서 고른 시작을 경고가 붙잡았을 때도. 안 그러면 뒤에 있는 창에 뜬
    /// 경고를 아무도 못 보고, 메뉴를 눌렀는데 아무 일도 없는 것처럼 보인다.
    func bringAppForward() {
        _ = controller?.perform(NSSelectorFromString("activateApp"))
    }

    /// 타이머 상태를 메뉴바에 반영
    func update(remaining: TimeInterval, state: TimerState) {
        lastState = state
        guard let controller else { return }

        let stateString: String
        switch state {
        case .running, .overtime: stateString = "running"
        case .paused: stateString = "paused"
        default: stateString = "idle"
        }

        // 끝나는 시각을 함께 넘긴다 — 창을 닫으면 이 값을 보내 줄 화면이 없어서, 메뉴 막대가 스스로 센다.
        let info: [String: Any] = [
            "text": TimeMapper.formatRemaining(remaining),
            "state": stateString,
            "endDate": Date().addingTimeInterval(remaining).timeIntervalSince1970,
        ]
        _ = controller.perform(NSSelectorFromString("update:"), with: info as NSDictionary)
    }
}
#endif
