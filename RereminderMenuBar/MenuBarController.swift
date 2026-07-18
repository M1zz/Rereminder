//
//  MenuBarController.swift
//  RereminderMenuBar
//
//  Mac Catalyst 앱이 런타임에 로드하는 AppKit 번들 — 메뉴바 타이머 표시
//
//  통신 규약 (같은 프로세스):
//  - 앱 → 번들: perform(Selector) 호출 ("show", "hide", "update:")
//  - 번들 → 앱: NotificationCenter post ("RRMenuBarPauseTapped", "RRMenuBarStopTapped")
//  - 문구는 앱 메인 번들의 String Catalog를 그대로 사용 (Bundle.main)
//

import AppKit

@objc(RRMenuBarController)
public final class RRMenuBarController: NSObject {

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var pauseItem: NSMenuItem?
    private var stopItem: NSMenuItem?

    /// 현재 상태 ("running" | "paused" | "idle") — 메뉴 문구 갱신용
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
            case "running":
                button.title = " \(text)"
                self.pauseItem?.title = self.localized("Pause")
                self.pauseItem?.isEnabled = true
                self.stopItem?.isEnabled = true
            case "paused":
                button.title = " ⏸ \(text)"
                self.pauseItem?.title = self.localized("Resume")
                self.pauseItem?.isEnabled = true
                self.stopItem?.isEnabled = true
            default:
                button.title = ""
                self.pauseItem?.isEnabled = false
                self.stopItem?.isEnabled = false
            }
        }
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

        let pause = NSMenuItem(
            title: localized("Pause"),
            action: #selector(pauseTapped), keyEquivalent: ""
        )
        pause.target = self
        pause.isEnabled = false
        menu.addItem(pause)
        pauseItem = pause

        let stop = NSMenuItem(
            title: localized("Stop"),
            action: #selector(stopTapped), keyEquivalent: ""
        )
        stop.target = self
        stop.isEnabled = false
        menu.addItem(stop)
        stopItem = stop

        menu.addItem(.separator())

        let open = NSMenuItem(
            title: localized("Open Rereminder"),
            action: #selector(openTapped), keyEquivalent: ""
        )
        open.target = self
        menu.addItem(open)

        item.menu = menu
        statusItem = item
    }

    // MARK: - Bundle → App (NotificationCenter)

    @objc private func pauseTapped() {
        NotificationCenter.default.post(name: Notification.Name("RRMenuBarPauseTapped"), object: nil)
    }

    @objc private func stopTapped() {
        NotificationCenter.default.post(name: Notification.Name("RRMenuBarStopTapped"), object: nil)
    }

    @objc private func openTapped() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Localization (앱 메인 번들의 String Catalog 사용)

    private func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }
}
