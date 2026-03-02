//
//  NoticeSettingView.swift
//  Rereminder
//
//  Created by POS on 7/8/25.
//

import SwiftUI
import UserNotifications

struct NoticeSettingView: View {
    @AppStorage("ringMode") private var ringMode: RingMode = .sound
    @AppStorage("pushEnabled") private var pushEnabled: Bool = true
    @AppStorage("toastEnabled") private var toastEnabled: Bool = true
    #if targetEnvironment(macCatalyst)
    @AppStorage("useAlarmKit") private var useAlarmKit: Bool = false
    #else
    @AppStorage("useAlarmKit") private var useAlarmKit: Bool = true
    #endif
    @AppStorage("testModeEnabled") private var testModeEnabled: Bool = false
    @AppStorage("testModeMultiplier") private var testModeMultiplier: Double = 1.0
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @ObservedObject private var store = StoreManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showAlarmKitInfo = false
    @State private var showOnboarding = false
    @State private var showTestModeInfo = false
    @State private var showPermissionGuide = false
    @State private var showPaywall = false

    var body: some View {
        Form {
            // Pro 상태 섹션
            Section {
                if store.isPro {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppName.pro)
                                .font(.headline)
                            Text("All features unlocked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to \(AppName.pro)")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Unlock all features · One-time purchase")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                HStack(spacing: 16){
                    Text("Notification Style")
                    Picker("notice", selection: $ringMode) {
                        ForEach(RingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: ringMode) { _, newMode in
                        WatchConnectivityManager.shared.sendRingMode(newMode.rawValue)
                    }
                }
            }

            // 권한 거부 경고 배너
            if appStateManager.notificationAuthStatus == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.title2)
                            Text("Notification permission denied")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }

                        Text("Without notification permission, the following features won't work properly:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Pre-alerts (1 min, 3 min, 5 min, etc.)")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Timer End Alert")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Receive notifications in background")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Live Activity (Dynamic Island)")
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.primary)

                        Divider()

                        VStack(spacing: 8) {
                            Button(action: openSettings) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Enable notifications in Settings")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                            }

                            Button(action: { showPermissionGuide = true }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("How to enable permissions")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Section(header: Text("Notification Method")) {
                #if !targetEnvironment(macCatalyst)
                Toggle(isOn: $useAlarmKit) {
                    HStack {
                        Text("Use Enhanced Notifications (Recommended)")
                        Button(action: {
                            showAlarmKitInfo.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if useAlarmKit {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Accurate notifications in background")
                        }
                        .font(.caption)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Automatic Permission Management")
                        }
                        .font(.caption)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Prevent Duplicate Alerts")
                        }
                        .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                } else {
                    Toggle("Send Push Notification", isOn: $pushEnabled)
                }
                #else
                Toggle("Send Push Notification", isOn: $pushEnabled)
                    .disabled(false)

                Text("Only basic notifications are supported on macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif

                // Notification Permission 상태 표시
                HStack {
                    Text("Notification Permission")
                    Spacer()
                    switch appStateManager.notificationAuthStatus {
                    case .authorized:
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .denied:
                        Button(action: openSettings) {
                            Label("Denied - Go to Settings", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    case .notDetermined:
                        Button(action: {
                            appStateManager.requestNotificationPermission()
                        }) {
                            Label("Request Permission", systemImage: "questionmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    default:
                        Text("Unknown")
                            .foregroundStyle(.secondary)
                    }
                }

                // 테스트 알림 버튼
                if appStateManager.notificationAuthStatus == .authorized {
                    Button(action: {
                        appStateManager.sendTestNotification()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.blue)
                            Text("Send Test Notification")
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .foregroundStyle(.primary)

                    Text("Test notification will be sent 1 second after pressing the button")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Show Toast Messages", isOn: $toastEnabled)
            }

            Section(header: Text("Test Mode")) {
                Toggle(isOn: $testModeEnabled) {
                    HStack {
                        Text("Quick Test Mode")
                        Button(action: {
                            showTestModeInfo.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: testModeEnabled) { _, newValue in
                    if !newValue {
                        testModeMultiplier = 1.0
                    }
                }

                if testModeEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Time Multiplier")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Time Multiplier", selection: $testModeMultiplier) {
                            Text("1x Speed (Real-time)").tag(1.0)
                            Text("10x Speed").tag(10.0)
                            Text("30x Speed").tag(30.0)
                            Text("60x Speed").tag(60.0)
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            if testModeMultiplier == 1.0 {
                                Text("Works in real-time")
                            } else {
                                Text("10 min timer → ends in ~\(Int(600 / testModeMultiplier)) sec")
                                Text("1 min timer → ends in ~\(Int(60 / testModeMultiplier)) sec")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                    }
                }
            }

            Section(header: Text("Appearance")) {
                HStack(spacing: 16) {
                    Text("Mode")
                    Picker("Mode", selection: $themeManager.appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                NavigationLink {
                    ThemeSettingView()
                } label: {
                    HStack {
                        Label("Theme", systemImage: "paintpalette.fill")
                        Spacer()
                        Circle()
                            .fill(ThemeManager.shared.accentColor)
                            .frame(width: 20, height: 20)
                    }
                }
            }

            Section(header: Text("Data")) {
                NavigationLink {
                    TimerHistoryView()
                } label: {
                    HStack {
                        Label("Timer History", systemImage: "chart.bar.fill")
                        Spacer()
                        if !StoreManager.isProUser {
                            ProBadge(small: true)
                        }
                    }
                }
            }

            Section(header: Text("Help")) {
                Button {
                    showOnboarding = true
                } label: {
                    HStack {
                        Label("View App Tutorial", systemImage: "book.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    shareApp()
                } label: {
                    HStack {
                        Label("Share App", systemImage: "square.and.arrow.up")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    rateApp()
                } label: {
                    HStack {
                        Label("Rate App", systemImage: "star.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    ReviewRequestManager.shared.openAppStoreReviewPage()
                } label: {
                    HStack {
                        Label("Write a Review on App Store", systemImage: "square.and.pencil")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Link(destination: URL(string: "mailto:leeo@kakao.com?subject=Rereminder%20%ED%94%BC%EB%93%9C%EB%B0%B1")!) {
                    HStack {
                        Label("Send Feedback", systemImage: "envelope.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Test Mode일 때만 표시
                if testModeEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Info")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Timer completions: \(ReviewRequestManager.shared.getCurrentCompletionCount())")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Button("Reset Completion Count") {
                            ReviewRequestManager.shared.resetCompletionCount()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Info")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appStateManager.checkNotificationPermission()
        }
        .alert("What are Enhanced Notifications?", isPresented: $showAlarmKitInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A dedicated notification system for timers.\n\n• Alerts at exact times even in background\n• Automatic permission management for convenience\n• Prevents duplicate notifications\n• Optimized for time management during mentoring or presentations\n\nRecommended: Keep enhanced notifications enabled")
        }
        .alert("What is Quick Test Mode?", isPresented: $showTestModeInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A mode to quickly verify that the timer works correctly.\n\n• 10x: 10-minute timer finishes in 1 minute\n• 30x: 10-minute timer finishes in 20 seconds\n• 60x: 10-minute timer finishes in 10 seconds\n\nYou can quickly test all features including alerts, pre-alerts, and overtime.\n\n⚠️ Make sure to turn off test mode for actual use!")
        }
        .alert("How to Enable Notifications", isPresented: $showPermissionGuide) {
            Button("Go to Settings", role: .none) {
                openSettings()
            }
            Button("Close", role: .cancel) {}
        } message: {
            Text("Follow these steps to enable notifications:\n\n1. Tap 'Go to Settings' button\n2. Find '\(AppName.display)' app in Settings\n3. Select 'Notifications' menu\n4. Turn on 'Allow Notifications'\n\n💡 Recommended settings:\n• Show on Lock Screen\n• Show in Notification Center\n• Show as Banners\n\nThis ensures you never miss timer alerts!")
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .paywallGate(isPresented: $showPaywall)
    }

    private func openSettings() {
        #if targetEnvironment(macCatalyst)
        // macOS에서는 시스템 환경Settings의 알림 섹션을 열 수 없으므로 안내 메시지만 표시
        // 사용자가 수동으로 System Settings > Notifications > Rereminder로 이동해야 함
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func shareApp() {
        guard let appURL = URL(string: "https://apps.apple.com/app/rereminder-smart-alarm/id6752551268") else { return }

        let activityViewController = UIActivityViewController(
            activityItems: [
                String(localized: "share_app_message"),
                appURL
            ],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }

            // iPad용 popover Settings
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = topController.view
                popoverController.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }

            topController.present(activityViewController, animated: true)
        }
    }

    private func rateApp() {
        // 시스템 네이티브 리뷰 요청 팝업 표시
        ReviewRequestManager.shared.requestReview()
    }
}

#Preview {
    NoticeSettingView()
        .environmentObject(AppStateManager())
}
