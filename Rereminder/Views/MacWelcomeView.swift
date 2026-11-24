//
//  MacWelcomeView.swift
//  Rereminder
//
//  **맥에서 쓰는 법** 세 장 — 알림 켜기 → 메뉴 막대 → 단축키·창 닫기. 맥에서만 뜬다(2026-11-25).
//
//  왜: 맥의 알림은 화면을 보지 않을 때 닿는 유일한 길인데, 시스템 창 한 번으로 묻고 끝나 꺼진 채로 쓰는 사람이
//  있었다(개발자의 맥도 그랬다). 메뉴 막대에서 바로 거는 것도 알려 주지 않으면 아무도 모른다.
//
//  언제: 새로 설치한 사람은 첫 그림이 끝난 순간(알림 권한도 여기서 묻는다), 쓰던 사람은 앱을 열 때 한 번.
//  다른 안내가 뜨는 차례면 양보한다(`TimerUnifiedView.setupOnAppear`). 설정 ▸ 도움말에서 다시 연다.
//
//  ⚠️ 셋째 장의 "창을 닫아도 메뉴 막대에서 계속 센다"는 `MenuBarManager` 가 지킨다 — 그 길을 바꾸면 이 문구도 볼 것.
//

import SwiftUI
import UserNotifications

enum MacWelcome {
    private static let seenKey = "macWelcome.seen.v1"

    /// 맥에서 아직 본 적이 없다.
    static var isDue: Bool {
        #if targetEnvironment(macCatalyst)
        return !UserDefaults.standard.bool(forKey: seenKey)
        #else
        return false
        #endif
    }

    static func markSeen() {
        UserDefaults.standard.set(true, forKey: seenKey)
    }
}

struct MacWelcomeView: View {
    let onClose: () -> Void

    @State private var page = 0
    @State private var settings: UNNotificationSettings?
    @Environment(\.scenePhase) private var scenePhase

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                notificationsPage.tag(0)
                menuBarPage.tag(1)
                keepWorkingPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageDots
                .padding(.bottom, 16)

            Button {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    onClose()
                }
            } label: {
                Text(page < pageCount - 1 ? "Next" : "Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .task { await refreshSettings() }
        // 시스템 설정에서 켜고 돌아오면 바로 "켜져 있어요"로 바뀐다.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshSettings() } }
        }
        // 다 본 뒤가 아니라 닫힐 때 기록한다 — 다른 창에 밀려 닫혀도 다음에 다시 온다(그 경우는 위에서 막는다).
        .onDisappear { MacWelcome.markSeen() }
    }

    // MARK: - 1. 알림

    private var notificationsPage: some View {
        page(symbol: "bell.badge.fill",
             title: "Turn on notifications",
             message: "On a Mac, an alert only reaches you as a notification. If they're off, nothing rings while you're in another app.") {
            switch settings?.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Label("Notifications are on", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                // 배너는 몇 초 뒤 사라진다 — 몰입해 있으면 놓친다. 지속적으로 바꾸면 닫을 때까지 남는다.
                if settings?.alertStyle != .alert {
                    Text("Tip: set the alert style to Persistent so it stays until you close it.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    openSettingsButton
                }
            case .denied:
                Label("Notifications are off for Rereminder", systemImage: "bell.slash.fill")
                    .font(.headline)
                    .foregroundStyle(DSColor.negativeSoft)
                openSettingsButton
            default:
                Button {
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound, .badge])
                        await refreshSettings()
                    }
                } label: {
                    Label("Allow notifications", systemImage: "bell.fill")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var openSettingsButton: some View {
        Button {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } label: {
            Label("Open System Settings", systemImage: "gear")
                .font(.headline)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - 2. 메뉴 막대

    private var menuBarPage: some View {
        page(symbol: "menubar.rectangle",
             title: "Start from the menu bar",
             message: "Click the timer at the top of the screen to start a saved setup or a Pomodoro without opening this window.") {
            // 메뉴 막대에 실제로 보이는 모양 그대로
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text(verbatim: "24:58")
                    .monospacedDigit()
            }
            .font(.title3.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .accessibilityHidden(true)
        }
    }

    // MARK: - 3. 손을 떼지 않고

    private var keepWorkingPage: some View {
        page(symbol: "keyboard",
             title: "Keep your hands on the keyboard",
             message: "Close the window and the timer keeps counting in the menu bar.") {
            HStack(spacing: 12) {
                Text(verbatim: "space")
                    .font(.body.weight(.semibold).monospaced())
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary, lineWidth: 1))
                    .accessibilityHidden(true)
                Text("Start, pause, or resume")
                    .font(.body)
            }
        }
    }

    // MARK: - 조각

    private func page<Content: View>(symbol: String, title: LocalizedStringKey, message: LocalizedStringKey,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: symbol)
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            content()
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    private func refreshSettings() async {
        settings = await UNUserNotificationCenter.current().notificationSettings()
    }
}
