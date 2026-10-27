//
//  NoticeSettingView.swift
//  Rereminder
//
//  Created by POS on 7/8/25.
//

import SwiftUI
import UserNotifications
import LeeoKit
import StoreKit

struct NoticeSettingView: View {
    /// 설정 행에 지금 고른 모양 이름·실루엣을 같이 보여주려고 읽는다.
    @AppStorage("ringMode") private var ringMode: RingMode = .sound
    @AppStorage("pushEnabled") private var pushEnabled: Bool = true
    @AppStorage("toastEnabled") private var toastEnabled: Bool = true
    /// ⚠️ **기본값은 꺼짐이다 — 켜 두지 말 것.** 이건 무음 모드와 집중 모드를 뚫고 알람 볼륨으로
    ///    우는 전체 화면 알람이다. 회의 중에 타이머를 건 사람에게 이게 기본으로 울리면 그건
    ///    기능이 아니라 사고다(이 앱은 잔소리가 되는 순간 지워진다).
    ///    2.2.2 까지 이 값의 기본이 `true` 였지만 토글이 아무 일도 하지 않아 아무도 몰랐다.
    @AppStorage("useAlarmKit") private var useAlarmKit: Bool = false
    @AppStorage("testModeEnabled") private var testModeEnabled: Bool = false
    @AppStorage("testModeMultiplier") private var testModeMultiplier: Double = 1.0
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @ObservedObject private var store = StoreManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showAlarmKitInfo = false
    @State private var showAlarmPermissionDenied = false
    @State private var showOnboarding = false
    @State private var showTestModeInfo = false
    @State private var showPermissionGuide = false
    @State private var showPaywall = false
    /// 창단 후원자의 혜택 변경 안내 — 설정에서 언제든 다시 열 수 있다.
    @State private var showFounderWelcome = false
    @State private var showLegacyFreeNotice = false
    @State private var showLostProResult = false
    @State private var lostProRecovered = false
    /// 달라진 점 안내에서 "Pro 알아보기"를 눌렀다 — 시트가 닫힌 뒤 페이월을 연다.
    @State private var showPaywallAfterLegacyNotice = false
    @State private var showFeedback = false
    /// App Store 코드 사용 시트(오퍼 코드·인앱결제 프로모션 코드).
    @State private var showRedeemCode = false
    /// App Store 의 구독 관리 시트.
    @State private var showManageSubscription = false
    /// 구독 졸업(평생으로 바꾸기) 시트.
    @State private var showGraduation = false
    /// 이번 버전에 새로 생긴 것 — 업데이트 뒤 한 번 뜬 안내를 여기서 다시 연다.
    @State private var showWhatsNew = false

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
                    // 누르면 **지금 누리는 혜택과 그 양**을 본다(`ProBenefitsView`).
                    // 산 사람에게 "활성화됨" 한 줄은 영수증일 뿐이다 — 무엇을 얼마나 쓰고 있는지가 보여야 산 값이 보인다.
                    NavigationLink {
                        ProBenefitsView()
                    } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(AppName.pro)
                                    .font(.headline)
                                // 값을 먼저 치른 사람에게는 표식이 남아 있어야 한다 —
                                // 안내는 한 번뿐이지만 대접받고 있다는 사실은 계속 보여야 한다.
                                if FoundingSupporter.isFounder {
                                    FounderBadge()
                                }
                            }
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
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    }
                    .accessibilityHint(String(localized: "Shows what Pro unlocks and how much you use it"))

                    // 약속의 상설 위치. 안내 화면은 한 번만 뜨므로, 다시 읽고 싶은 사람은 여기로 온다.
                    if FoundingSupporter.isFounder {
                        FounderPromiseRow()
                        Button {
                            showFounderWelcome = true
                        } label: {
                            HStack {
                                Text("See what's changing")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if store.canRemember {
                    // 기억 트림만 가진 사람 — 산 것을 먼저 확인시키고, 올리는 길은 그 아래 한 줄로만 둔다.
                    // 누르면 기억으로 열린 것과 그 양, Pro 에서 더 열리는 것을 본다(`ProBenefitsView`).
                    NavigationLink {
                        ProBenefitsView()
                    } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bookmark.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remember")
                                .font(.headline)
                            Text("Your setups are remembered")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    }
                    .accessibilityHint(String(localized: "Shows what Remember unlocks and how much you use it"))
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Text("Upgrade to Pro")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                                Text("Unlock all features · Yearly or lifetime")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 개편 전부터 무료로 쓰던 사람 — 안내는 한 번 뜨므로, 다시 읽을 자리를 여기 둔다.
                    if LegacyFreeNotice.isEligible {
                        Button {
                            showLegacyFreeNotice = true
                        } label: {
                            HStack {
                                Text("What changed for you")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // 연 구독 중인 사람. 구독 관리와 '평생으로 바꾸기' 를 늘 여기 둔다(구독 중일 때만).
                // 평생 Pro 를 이미 가졌으면(졸업 뒤 해지 전) 바꾸기 줄은 빼고 관리만 남긴다.
                if store.subscriptionTier > .free {
                    Button {
                        showManageSubscription = true
                    } label: {
                        HStack {
                            Text(LeeoLadderText.manageSubscription)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    if !StoreManager.storedPurchaseFlag {
                        Button {
                            showGraduation = true
                        } label: {
                            HStack {
                                Label(LeeoLadderText.switchToLifetimeEntry, systemImage: "infinity")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }

                // ⚠️ 기억 트림만 산 사람에게도 보인다 — 그랜드파더링·창단 후원자가 기억을 산 뒤 재설치하면
                //    Pro 가 사라진 채 기억만 남는데, 이 줄이 무료 칸 안에만 있으면 되살릴 길이 없었다.
                if !store.isPro {
                    // "예전에 Pro 였는데 사라졌어요" — 앱을 지웠다 깐 그랜드파더링 사용자의 자격이
                    // UserDefaults 에만 있어 통째로 사라지던 시절이 있었다(2.2.8 에서 Keychain 에도
                    // 남기게 고쳤다). 남은 기록으로 되살릴 수 있으면 여기서 되살린다.
                    Button {
                        lostProRecovered = StoreManager.recoverLostEntitlementIfPossible()
                        showLostProResult = true
                    } label: {
                        HStack {
                            Text("Had Pro before but it is gone?")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // 할인·선물로 받은 코드를 여기서 바로 쓴다 — App Store 앱으로 나갔다 오지 않아도 된다.
                    Button {
                        showRedeemCode = true
                    } label: {
                        HStack {
                            Label("Redeem Code", systemImage: "giftcard")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }

                }
            }

            // 선물·응원 — 상품이 App Store 에서 와야 선다(`GiftAndTipSection`).
            GiftAndTipSection()

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

            // ⚠️ **되풀이·알람·햅틱은 있는 줄 몰라서 안 쓰인다.** 제보로 들어온 요청 셋 중 둘이
            //    이미 있는 기능이었다. 그래서 설정 안쪽이 아니라 알림 구역 **맨 앞**에 세운다.
            Section {
                NavigationLink {
                    FeatureIntroView()
                } label: {
                    Label(String(localized: "Things you might not know"),
                          systemImage: "sparkles")
                }
            }

            PersistentAlertSection()

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
                        Text("End with a full alarm")
                        Button(action: {
                            showAlarmKitInfo.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                // ⚠️ 권한은 **여기서** 묻는다. 타이머를 시작하는 순간에 시스템 창을 띄우면
                //    그 타이머는 이미 놓친 것이다. 거부당하면 토글을 되돌린다 —
                //    켜져 있는데 울리지 않는 것이 가장 나쁜 상태다.
                .onChange(of: useAlarmKit) { _, isOn in
                    guard isOn else {
                        RereminderAlarmManager.shared.cancelFinishAlarm()
                        return
                    }
                    Task { @MainActor in
                        if await RereminderAlarmManager.shared.requestAuthorization() == false {
                            useAlarmKit = false
                            showAlarmPermissionDenied = true
                        }
                    }
                }

                if useAlarmKit {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Rings at alarm volume, through Silent Mode and Focus",
                              systemImage: "speaker.wave.3.fill")
                        Label("Keeps ringing until you press Stop",
                              systemImage: "bell.badge.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }

                Toggle("Send Push Notification", isOn: $pushEnabled)
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
                        if !store.isPro {
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

            // ⚠️ **피드백은 Help 안에 두지 말 것.** 예전에는 "How to Use" 밑 여섯 번째 줄에
            //    묻혀 있었는데, 그 섹션은 부제까지 "첫 실행 안내가 전부 여기 있습니다"라
            //    **사용법 문서로 읽힌다.** 불만이 있는 사람은 도움말을 열지 않는다.
            //    통계는 어디서 떨어지는지까지만 말해 주고, 왜 그런지는 이 줄로만 들어온다.
            Section(header: Text("Feedback"),
                    footer: Text("The developer reads every message. Tell us what you need or what felt off.")) {
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

                // 메일 앱으로 바로 — 스크린샷을 붙이거나 긴 이야기를 쓰고 싶은 사람은 이쪽이 편하다.
                if let mailURL = Self.developerMailURL {
                    Link(destination: mailURL) {
                        HStack {
                            Label("Email the Developer", systemImage: "at")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                // 앞으로 만들 기능 — 원본은 RereminderRoadmap.swift
                NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }

                // 핸들(@lee25_ios)만 고유명사이고 문장은 언어별로 번역돼 있다.
                Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                    HStack {
                        Label("Instagram DM (@lee25_ios)", systemImage: "paperplane.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                    FeatureIntroView()
                } label: {
                    Label("Things you might not know", systemImage: "sparkles")
                }

                // 업데이트 뒤 한 번만 뜨는 안내를 다시 본다.
                Button {
                    showWhatsNew = true
                } label: {
                    HStack {
                        Label("What's New", systemImage: "gift")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(.primary)

                NavigationLink {
                    MultiDeviceGuideView()
                } label: {
                    Label("Use on All Your Devices", systemImage: "square.stack.3d.up.fill")
                }
                .foregroundStyle(.primary)

                // 같은 개발자가 만든 다른 앱 — 이 앱과 함께 쓰는 순간을 앱마다 한 줄로.
                LeeoFamilySettingsRow<RereminderSpec>()

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

                // 개발자 전용 — 버전 행 7번 탭으로 노출
                if masterModeEnabled {
                    developerLinks
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
        .alert("What is a full alarm?", isPresented: $showAlarmKitInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("When the timer ends, your iPhone rings like an alarm clock instead of showing a notification.\n\nIt plays at alarm volume even in Silent Mode or a Focus, takes over the whole screen, and keeps ringing until you press Stop. Snooze gives you five more minutes.\n\nUse it when you must not miss the end - a workout set, a break you keep skipping. Leave it off for quiet places.")
        }
        .alert("Alarm permission needed", isPresented: $showAlarmPermissionDenied) {
            Button("Open Settings", action: openSettings)
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow alarms for Rereminder in Settings to use the full alarm.")
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
            OnboardingFlowView(isPresented: $showOnboarding)
                .environmentObject(screenVM)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(onClose: { showWhatsNew = false })
        }
        .offerCodeRedemption(isPresented: $showRedeemCode) { _ in
            // 시트가 닫히는 즉시 권한을 다시 읽는다 — 그래야 자물쇠가 그 자리에서 풀린다.
            Task { await store.verifyCurrentEntitlements() }
        }
        .paywallGate(isPresented: $showPaywall)
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .sheet(isPresented: $showGraduation) {
            SubscriptionGraduationSheet()
        }
        .alert(lostProRecovered
               ? String(localized: "Your Pro access is back")
               : String(localized: "We could not find a record on this device"),
               isPresented: $showLostProResult) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(lostProRecovered
                 ? String(localized: "Everything is unlocked again. Sorry for the trouble.")
                 : String(localized: "If you bought Pro, open the Pro screen above and tap Restore Purchases. If you had it for free as an early user, send us a message from Feedback below and we will bring it back for you."))
        }
        .sheet(isPresented: $showLegacyFreeNotice, onDismiss: {
            guard showPaywallAfterLegacyNotice else { return }
            showPaywallAfterLegacyNotice = false
            showPaywall = true
        }) {
            LegacyFreeNoticeView(isFirstShowing: false, onSeePro: { showPaywallAfterLegacyNotice = true })
        }
        .sheet(isPresented: $showFounderWelcome) {
            // 설정에서 다시 열어 본 것이라 "봤음" 표시를 다시 남기지 않는다.
            FounderWelcomeView(isFirstShowing: false)
        }
    }
}

// MARK: - 화면 조각·도움 함수

extension NoticeSettingView {
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

        NavigationLink {
            PreflightReportView()
        } label: {
            Label { Text(verbatim: "출시 점검 (개발자)") } icon: { Image(systemName: "checklist") }
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

    /// 개발자에게 보내는 메일 주소(mailto). 제목에 앱 이름·버전을 미리 넣어 두면 받는 쪽이 어느 앱인지 바로 안다.
    static var developerMailURL: URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = RereminderSpec.developerEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "\(AppName.display) \(version)")]
        return components.url
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
