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

    /// 메뉴바에서 일시정지/재개 눌렀을 때 (앱이 현재 상태에 맞게 처리)
    var onPauseToggle: (() -> Void)?
    /// 메뉴바에서 정지 눌렀을 때
    var onStop: (() -> Void)?

    private var controller: NSObject?

    private init() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: Notification.Name("RRMenuBarPauseTapped"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onPauseToggle?() }
        }
        center.addObserver(
            forName: Notification.Name("RRMenuBarStopTapped"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.onStop?() }
        }
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
        NSLog("%@", "🖥️ MenuBar: 상태 아이템 생성 완료")
    }

    /// 타이머 상태를 메뉴바에 반영
    func update(remaining: TimeInterval, state: TimerState) {
        guard let controller else { return }

        let stateString: String
        switch state {
        case .running, .overtime: stateString = "running"
        case .paused: stateString = "paused"
        default: stateString = "idle"
        }

        let info: [String: Any] = [
            "text": TimeMapper.formatRemaining(remaining),
            "state": stateString,
        ]
        _ = controller.perform(NSSelectorFromString("update:"), with: info as NSDictionary)
    }
}
#endif
