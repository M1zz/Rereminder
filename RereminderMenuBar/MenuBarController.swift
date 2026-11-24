//
//  MenuBarController.swift
//  RereminderMenuBar
//
//  Mac Catalyst 앱이 런타임에 로드하는 AppKit 번들 — 메뉴바 타이머 표시
//
//  통신 규약 (같은 프로세스):
//  - 앱 → 번들: perform(Selector) 호출 ("show", "hide", "update:", "setSetups:")
//  - 번들 → 앱: NotificationCenter post ("RRMenuBarPauseTapped", "RRMenuBarStopTapped",
//              "RRMenuBarStartTapped" userInfo ["id"])
//  - 문구는 앱 메인 번들의 String Catalog를 그대로 사용 (Bundle.main)
//

import AppKit

@objc(RRMenuBarController)
public final class RRMenuBarController: NSObject {

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()

    /// 현재 상태 ("running" | "paused" | "idle") — 메뉴를 열 때 무엇을 낼지
    private var currentState = "idle"

    // MARK: - App → Bundle API

    @objc public func show() {
        DispatchQueue.main.async { self.makeStatusItemIfNeeded() }
    }

    @objc public func hide() {
        DispatchQueue.main.async {
            if let item = self.statusItem {
                NSStatusBar.system.removeStatusItem(item)
                self.statusItem = nil
            }
        }
    }

    /// info: ["text": "12:34", "state": "running"|"paused"|"idle"]
    @objc public func update(_ info: [String: Any]) {
        DispatchQueue.main.async {
            guard let button = self.statusItem?.button else { return }
            let text = info["text"] as? String ?? ""
            let state = info["state"] as? String ?? "idle"
            self.currentState = state

            switch state {
            case "running": button.title = " \(text)"
            case "paused": button.title = " ⏸ \(text)"
            default: button.title = ""
            }
        }
    }

    /// 메뉴에서 바로 거는 설정. info: ["id", "title", "subtitle"] — 앱이 순서·문구까지 정해 넘긴다.
    private var setups: [[String: String]] = []

    @objc public func setSetups(_ list: NSArray) {
        let parsed = list.compactMap { $0 as? [String: String] }
        DispatchQueue.main.async { self.setups = parsed }
    }

    // MARK: - Status Item

    private func makeStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "timer",
            accessibilityDescription: "Rereminder"
        )
        item.button?.imagePosition = .imageLeading
        item.button?.font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize, weight: .medium
        )

        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    /// 메뉴는 열 때마다 지금 상태로 다시 짠다.
    /// 쉬는 동안: 저장한 설정 → 포모도로 → 열기 → 종료. 도는 동안: 일시정지·정지 → 열기 → 종료.
    /// ⚠️ 도는 중에는 거는 항목을 내지 않는다 — 앱도 도는 타이머를 덮지 않는다(위젯·제어센터와 같은 규칙).
    private func rebuildMenu() {
        menu.removeAllItems()

        if currentState == "idle" {
            for setup in setups {
                let start = NSMenuItem(
                    title: setup["title"] ?? "",
                    action: #selector(startTapped(_:)), keyEquivalent: ""
                )
                start.target = self
                start.representedObject = setup["id"]
                if let subtitle = setup["subtitle"], !subtitle.isEmpty { start.subtitle = subtitle }
                start.image = NSImage(systemSymbolName: setup["symbol"] ?? "play.fill",
                                      accessibilityDescription: nil)
                menu.addItem(start)
            }
            if !setups.isEmpty { menu.addItem(.separator()) }
        } else {
            let pause = NSMenuItem(
                title: localized(currentState == "paused" ? "Resume" : "Pause"),
                action: #selector(pauseTapped), keyEquivalent: ""
            )
            pause.target = self
            menu.addItem(pause)

            let stop = NSMenuItem(
                title: localized("Stop"),
                action: #selector(stopTapped), keyEquivalent: ""
            )
            stop.target = self
            menu.addItem(stop)

            menu.addItem(.separator())
        }

        let open = NSMenuItem(
            title: localized("Open Rereminder"),
            action: #selector(openTapped), keyEquivalent: ""
        )
        open.target = self
        menu.addItem(open)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: localized("Quit Rereminder"),
            action: #selector(quitTapped), keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Bundle → App (NotificationCenter)

    @objc private func pauseTapped() {
        NotificationCenter.default.post(name: Notification.Name("RRMenuBarPauseTapped"), object: nil)
    }

    @objc private func stopTapped() {
        NotificationCenter.default.post(name: Notification.Name("RRMenuBarStopTapped"), object: nil)
    }

    @objc private func startTapped(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        NotificationCenter.default.post(
            name: Notification.Name("RRMenuBarStartTapped"), object: nil, userInfo: ["id": id]
        )
    }

    @objc private func openTapped() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    @objc private func quitTapped() {
        NSApp.terminate(nil)
    }

    // MARK: - Localization (앱 메인 번들의 String Catalog 사용)

    private func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}

extension RRMenuBarController: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }
}
