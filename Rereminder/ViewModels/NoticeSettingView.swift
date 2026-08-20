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
    @State private var showFeedback = false

    // 내 기기 — 타이머 중에 물어본 답이 여기에 저장된다.
    // ⚠️ 키 문자열은 DeviceOwnership.answerKey 와 같아야 한다(@AppStorage 는 리터럴만 받는다).
    @AppStorage("device.owns.watch") private var watchOwnershipRaw = DeviceOwnership.Answer.unknown.rawValue
    @AppStorage("device.owns.mac") private var macOwnershipRaw = DeviceOwnership.Answer.unknown.rawValue

    // 연결 상태 — 워치는 WatchConnectivity가 실시간으로, 맥은 iCloud에 남긴 표시로 알아낸다.
    @ObservedObject private var watchLink = WatchConnectivityManager.shared
    @State private var macPresence: DevicePresence.Status = .away(lastSeen: nil)
    /// 눌러서 연 "어떻게 연결하나" 안내의 대상 기기.
    @State private var connectionHelpDevice: DeviceOwnership.Device?

    // 마스터 모드(개발자) — Info의 버전 행 7번 탭으로 토글, 피드백 인박스 진입점 노출
    @AppStorage("masterModeEnabled") private var masterModeEnabled = false
    @State private var versionTapCount = 0

    // 미리 알림 프리셋 편집
    @AppStorage(AlertPresets.storageKey) private var alertPresetsRaw = AlertPresets.defaultRaw
    private struct PresetEditTarget: Identifiable {
        let id: Int  // 편집할 프리셋 인덱스, 새 프리셋은 -1
    }
    @State private var editingPreset: PresetEditTarget?

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
                            // 기존 사용자에게는 평생 무료임을 명시해 손해 보지 않았음을 안심시킨다
                            Text(StoreManager.isGrandfathered
                                 ? String(localized: "Free forever as an early supporter 🎉")
                                 : String(localized: "All features unlocked"))
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

            Section {
                // 알림 문구 편집 — 하단 탭에서 설정 하위로 이동
                NavigationLink {
                    NotificationMessageSettingView()
                } label: {
                    Label("Messages", systemImage: "text.bubble")
                }
            }

            // 타이머 화면 알림 버튼 행에 표시되는 프리셋 시간
            Section(header: Text("Alert Presets")) {
                let presets = AlertPresets.decode(alertPresetsRaw)
                ForEach(Array(presets.enumerated()), id: \.element) { index, sec in
                    Button {
                        editingPreset = PresetEditTarget(id: index)
                    } label: {
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(DSColor.marker)
                            Text(presetLabel(sec))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { indexSet in
                    var list = presets
                    list.remove(atOffsets: indexSet)
                    // 최소 1개는 유지
                    if !list.isEmpty {
                        alertPresetsRaw = AlertPresets.encode(list)
                    }
                }

                Button {
                    editingPreset = PresetEditTarget(id: -1)
                } label: {
                    Label("Add Preset", systemImage: "plus.circle.fill")
                }
                .sheet(item: $editingPreset) { target in
                    let presets = AlertPresets.decode(alertPresetsRaw)
                    TimePresetEditorSheet(
                        title: target.id >= 0 ? "Edit Alert Preset" : "Add Preset",
                        showSeconds: true,
                        initialSeconds: target.id >= 0 && target.id < presets.count
                            ? presets[target.id]
                            : 120
                    ) { totalSeconds in
                        guard totalSeconds > 0 else { return }
                        var list = presets
                        if target.id >= 0 && target.id < list.count {
                            list[target.id] = totalSeconds
                        } else {
                            list.append(totalSeconds)
                        }
                        alertPresetsRaw = AlertPresets.encode(list)
                    }
                    .presentationDetents([.height(320)])
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

            // 타이머를 쓰는 중에 물어본 답이 여기로 온다. 여기서 바꾸면 안내도 따라 바뀐다 —
            // "없음"으로 두면 그 기기 이야기는 다시 나오지 않는다.
            Section(header: Text("My Devices"),
                    footer: Text("Rereminder points you to the devices you have, and stays quiet about the ones you don't. Set a device to No and it won't be mentioned again.")) {
                deviceOwnershipRow(title: "Apple Watch", systemImage: "applewatch", raw: $watchOwnershipRaw)
                // 가지고 있다고 한 기기만 연결 상태를 보여준다 — 없는 기기의 연결 상태는 의미가 없다.
                if watchOwnershipRaw == DeviceOwnership.Answer.yes.rawValue,
                   let watch = watchConnectionDisplay {
                    connectionRow(watch, device: .watch)
                }
                deviceOwnershipRow(title: "Mac", systemImage: "laptopcomputer", raw: $macOwnershipRaw)
                // 맥에서 돌 때는 맥의 연결 상태 줄을 감춘다 — 자기 자신은 세지 않으므로
                // 늘 "연결 안 됨"으로 보인다(맥 앞에 앉은 사람에게는 헛소리다).
                if macOwnershipRaw == DeviceOwnership.Answer.yes.rawValue,
                   DevicePresence.currentPlatform != .mac {
                    connectionRow(macConnectionDisplay, device: .mac)
                }
            }

            Section(header: Text("Help"), footer: Text("Everything from the first-run walkthrough is here — including how to use Rereminder on Apple Watch, Mac, widgets, and Siri.")) {
                Button {
                    showOnboarding = true
                } label: {
                    HStack {
                        Label("How to Use This App", systemImage: "book.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                NavigationLink {
                    MultiDeviceGuideView()
                } label: {
                    Label("Use on All Your Devices", systemImage: "square.stack.3d.up.fill")
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

                // CloudKit 직접 제출 (메일 앱 불필요) — 실패 시 FeedbackView 내부에서 이메일 폴백
                Button {
                    showFeedback = true
                } label: {
                    HStack {
                        Label("Send Feedback", systemImage: "envelope.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                // 개발자 전용 — 버전 행 7번 탭으로 노출
                if masterModeEnabled {
                    developerLinks
                }

                // TODO: localize (handle is a proper noun, shown as-is)
                Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                    HStack {
                        Label("Instagram DM (@lee25_ios)", systemImage: "paperplane.fill")
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
                .contentShape(Rectangle())
                .onTapGesture(perform: handleVersionTap)
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
        .onAppear {
            // 화면을 열 때 지금 상태를 다시 읽는다(워치는 그 사이 꺼졌을 수 있다).
            watchLink.refreshLinkStatus()
            NSUbiquitousKeyValueStore.default.synchronize()
            macPresence = DevicePresence.status(of: .mac)
        }
        // 다른 기기가 표시를 남기면 iCloud가 알려준다 — 화면을 열어 둔 채로도 따라간다.
        .onReceive(NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            macPresence = DevicePresence.status(of: .mac)
        }
        .sheet(item: $connectionHelpDevice) { device in
            DeviceConnectionHelpView(device: device)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
        .paywallGate(isPresented: $showPaywall)
    }

    /// 개발자(마스터 모드) 전용 진입점 — 본문 타입체크 부담을 줄이려 별도 프로퍼티로 분리
    @ViewBuilder
    private var developerLinks: some View {
        NavigationLink {
            FeedbackInboxView()
        } label: {
            Label(String(localized: "Feedback Inbox (Developer)"), systemImage: "tray.full.fill")
        }

        NavigationLink {
            UsageStatsView()
        } label: {
            Label(String(localized: "Usage Stats (Developer)"), systemImage: "chart.bar.fill")
        }
    }

    /// Info의 버전 행 7번 탭 → 마스터 모드(개발자) 토글
    private func handleVersionTap() {
        versionTapCount += 1
        guard versionTapCount >= 7 else { return }
        versionTapCount = 0
        masterModeEnabled.toggle()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 프리셋 초 → "1:00" 표기 (M:SS 통일)
    private func presetLabel(_ sec: Int) -> String { TimeMapper.mmss(sec) }

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

    /// 기기 하나의 보유 여부 행 — 값은 문자열(`DeviceOwnership.Answer`)로 저장된다.
    /// "아직 안 물어봄"을 남겨 두는 이유: 그 상태여야 타이머 중에 한 번 물어볼 수 있다.
    private func deviceOwnershipRow(title: LocalizedStringKey,
                                    systemImage: String,
                                    raw: Binding<String>) -> some View {
        let selection = Binding<DeviceOwnership.Answer>(
            get: { DeviceOwnership.Answer(rawValue: raw.wrappedValue) ?? .unknown },
            set: { raw.wrappedValue = $0.rawValue }
        )
        return Picker(selection: selection) {
            Text("Not answered yet").tag(DeviceOwnership.Answer.unknown)
            Text("I have one").tag(DeviceOwnership.Answer.yes)
            Text("I don't have one").tag(DeviceOwnership.Answer.no)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    /// 연결 상태 한 줄에 필요한 것 — 심볼·색·문구.
    private struct ConnectionDisplay {
        let symbol: String
        let tint: Color
        let text: LocalizedStringKey
        /// 아래에 작게 붙는 보충 설명(기기 이름이나 마지막 활동 시각). 없으면 nil.
        let detail: String?
    }

    /// 워치: WatchConnectivity가 지금 통신되는지를 그대로 말해 준다.
    /// 알 수 없는 기기(맥)에서는 nil — 모르는 걸 "연결 안 됨"이라고 하면 거짓말이 된다.
    private var watchConnectionDisplay: ConnectionDisplay? {
        switch watchLink.linkStatus {
        case .unavailable:
            return nil
        case .connected:
            return ConnectionDisplay(symbol: "applewatch.radiowaves.left.and.right",
                                     tint: .green, text: "Connected", detail: nil)
        case .notReachable:
            return ConnectionDisplay(symbol: "applewatch.slash",
                                     tint: .secondary, text: "Not connected", detail: nil)
        case .appNotInstalled:
            return ConnectionDisplay(symbol: "applewatch.slash",
                                     tint: .orange,
                                     text: "The app isn't installed on your Apple Watch", detail: nil)
        case .notPaired:
            return ConnectionDisplay(symbol: "applewatch.slash",
                                     tint: .secondary,
                                     text: "No Apple Watch is paired with this iPhone", detail: nil)
        }
    }

    /// 맥: 아이폰에서 볼 방법이 없어 iCloud에 남긴 표시로 판단한다.
    /// 그래서 "연결됨"은 실시간 연결이 아니라 **최근에 그 맥에서 앱이 켜져 있었다**는 뜻이다.
    private var macConnectionDisplay: ConnectionDisplay {
        switch macPresence {
        case .connected(let name):
            return ConnectionDisplay(symbol: "antenna.radiowaves.left.and.right",
                                     tint: .green, text: "Connected",
                                     detail: name.isEmpty ? nil : name)
        case .away(let lastSeen):
            return ConnectionDisplay(symbol: "antenna.radiowaves.left.and.right.slash",
                                     tint: .secondary, text: "Not connected",
                                     detail: lastSeen.map(Self.lastActiveText))
        }
    }

    /// 상태만 보여주고 끝내지 않는다 — 누르면 무엇을 하면 되는지 알려 준다.
    private func connectionRow(_ display: ConnectionDisplay,
                               device: DeviceOwnership.Device) -> some View {
        Button {
            connectionHelpDevice = device
        } label: {
            connectionRowLabel(display)
        }
        .buttonStyle(.plain)
    }

    private func connectionRowLabel(_ display: ConnectionDisplay) -> some View {
        HStack(spacing: 10) {
            Image(systemName: display.symbol)
                .foregroundStyle(display.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(display.text)
                    .font(.subheadline)
                    .foregroundStyle(display.tint == .secondary ? .secondary : .primary)
                if let detail = display.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows how to connect this device"))
    }

    /// "3일 전에 마지막으로 켜짐" — 상대 시각 표기는 시스템이 번역해 준다.
    private static func lastActiveText(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return String(format: String(localized: "Last active %@"), relative)
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
