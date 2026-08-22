//
//  TimerUnifiedView.swift
//  Rereminder
//
//  Created by xa on 8/28/25.
//

import Foundation
import SwiftUI
import SwiftData
import TipKit
import LeeoKit

/// 여러 기기(워치·위젯·Siri·Mac)에서도 쓸 수 있다는 걸 설정 버튼 위에 살짝 알려주는 팁.
/// 타이머를 두 번 이상 완료한 뒤(=앱을 실제로 써 본 사용자)에만 노출한다.
@available(iOS 17.0, *)
struct MultiDeviceTip: Tip {
    /// 타이머 완료 이벤트 — 도너를 여러 번 쌓아 노출 조건을 만든다
    static let timerCompleted = Event(id: "multiDeviceTip.timerCompleted")

    var title: Text {
        Text("tip_multidevice_title")
    }
    var message: Text? {
        Text("tip_multidevice_message")
    }
    var image: Image? {
        Image(systemName: "square.stack.3d.up.fill")
    }
    var rules: [Rule] {
        #Rule(Self.timerCompleted) { $0.donations.count >= 2 }
    }
}

/// popoverTip은 iOS 17+ 전용이라 가용성 가드를 한 곳에 모은 모디파이어.
/// 하위 버전에서는 아무 것도 붙이지 않는다.
private struct PresentationModeTipAnchor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.popoverTip(PresentationModeTip(), arrowEdge: .top)
        } else {
            content
        }
    }
}

private struct MultiDeviceTipAnchor: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.popoverTip(MultiDeviceTip(), arrowEdge: .top)
        } else {
            content
        }
    }
}

struct TimerUnifiedView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var screenVM = TimerScreenViewModel()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @StateObject private var toast = ToastManager()
    @StateObject private var appStateManager = AppStateManager()

    @State private var showHistory = false
    @State private var showProPaywall = false
    @State private var paywallStage: ProGate.PaywallStage = .second

    // 기존 사용자 무료 Pro(그랜드파더링) 안내 — 최초 1회만 표시
    private static let grandfatherThankedKey = "rereminder.grandfather.thanked"
    @State private var showGrandfatherThanks = false

    // 가끔 먼저 물어보는 의견 요청 — 조건 판정은 FeedbackNudge가 한다
    @State private var showFeedbackNudge = false
    @State private var showFeedbackSheet = false

    // 타이머를 실제로 걸었을 때 한 번 물어보는 기기 보유 질문(워치 → 맥).
    // 물어볼지 말지는 DeviceOwnership이 정한다 — "없다"고 한 기기는 다시 꺼내지 않는다.
    @State private var deviceQuestion: DeviceOwnership.Device?

    // 여러 날 반복해서 건 설정을 앱이 먼저 알아채고 "저장해 둘까요?"라고 묻는다.
    // 판정은 RepeatDetector 가 한다 — 한 설정에 한 번, 전체 상한까지만.
    @State private var repeatProposal: RepeatDetector.Config?

    /// 지금 다이얼에 올라온 설정과 같은 템플릿을 이미 갖고 있는가.
    /// (저장돼 있으면 제안할 이유가 없다 — 이미 앱이 기억하고 있다.)
    @Query private var savedTemplates: [Timer]

    /// 타이머가 실행 중이 아닐 때만 모드 전환 허용
    private var isIdle: Bool {
        screenVM.state == .idle || screenVM.state == .finished
    }

    /// 모드 세그먼트 바인딩 — 발표는 5+5 trial 평가, 실행 중에는 전환 차단
    private var modeBinding: Binding<AppMode> {
        Binding(
            get: { screenVM.currentMode },
            set: { newMode in
                guard newMode != screenVM.currentMode else { return }

                // 실행 중 전환 차단은 의도된 동작 — 이유를 토스트로 안내
                guard isIdle else {
                    toast.show(Toast(String(localized: "Stop the timer to switch modes")))
                    return
                }

                guard newMode == .presentation else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        screenVM.currentMode = .timer
                    }
                    return
                }

                switch ProGate.evaluate(.presentationMode) {
                case .allowed, .allowedWithTrial:
                    withAnimation(.easeInOut(duration: 0.3)) {
                        screenVM.currentMode = .presentation
                    }
                    ProGate.recordUsage(.presentationMode)
                    AnalyticsManager.log(.presentationModeStarted)
                    FeatureTips.markPresentationModeUsed()
                case .blocked(let stage):
                    paywallStage = stage
                    showProPaywall = true
                    AnalyticsManager.log(.premiumTrialExhausted(
                        feature: .presentationMode,
                        stage: stage
                    ))
                }
            }
        )
    }

    private func enterPresentationAfterExtension() {
        screenVM.currentMode = .presentation
        ProGate.recordUsage(.presentationMode)
        AnalyticsManager.log(.presentationModeStarted)
        FeatureTips.markPresentationModeUsed()
    }

    var body: some View {
        mainContent
            .paywallGate(
                isPresented: $showProPaywall,
                feature: .presentationMode,
                stage: paywallStage,
                onAcceptExtension: enterPresentationAfterExtension
            )
            .toast(toast)
            .alert(String(localized: "Thank you for being an early user 💙"), isPresented: $showGrandfatherThanks) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: "All Pro features — Presentation Mode, unlimited pre-alerts, overtime tracking, and timer history — are yours free forever. Nothing you had has been taken away."))
            }
            .onAppear(perform: setupOnAppear)
            // 사용 중 적절한 시점에 "즐겁게 쓰고 계신가요?" → 👍 앱스토어 리뷰 / 👎 피드백.
            // 실행 3회·설치 2일·타이머 완료 3회 이상, 버전당 1회, 120일 쿨다운(정책 내장).
            .leeoSatisfactionCheck(RereminderSpec.self, policy: Self.satisfactionPolicy)
            // 만족도 게이트가 뜰 차례가 아닐 때만, 가끔 먼저 "불편한 점 없으세요?"를 묻는다.
            // 통계는 어디서 떨어지는지까지만 말해 준다 — 왜 그런지는 여기로만 들어온다.
            .alert(String(localized: "Anything bothering you?"), isPresented: $showFeedbackNudge) {
                Button(String(localized: "Leave Feedback")) {
                    AnalyticsManager.log(.feedbackNudgeAccepted)
                    showFeedbackSheet = true
                }
                Button(String(localized: "Later"), role: .cancel) {}
                Button(String(localized: "Don't Show Again")) { FeedbackNudge.snooze() }
            } message: {
                Text(String(localized: "Tell us what you need or what felt off — the developer reads every message."))
            }
            .sheet(isPresented: $showFeedbackSheet) {
                FeedbackView()
            }
            // 타이머가 돌기 시작한 순간에 묻는다 — "지금 손목에서도 볼 수 있어요"가 바로 확인되는 때다.
            // 답은 설정(내 기기)에 저장되고, 없다고 하면 그 기기 이야기는 두 번 다시 꺼내지 않는다.
            .alert(deviceQuestionTitle, isPresented: deviceQuestionBinding, presenting: deviceQuestion) { device in
                Button(String(localized: "Yes, I have one")) { answerDeviceQuestion(device, owns: true) }
                Button(String(localized: "No, I don't"), role: .cancel) { answerDeviceQuestion(device, owns: false) }
            } message: { device in
                Text(deviceQuestionMessage(device))
            }
            // 반복을 앱이 먼저 알아챈다 — 저장은 사용자가 결심해야 하는 일이었고, 결심은 잘 안 난다.
            .alert(String(localized: "You use this setup a lot"),
                   isPresented: repeatProposalBinding,
                   presenting: repeatProposal) { config in
                Button(String(localized: "Save as template")) {
                    RepeatDetector.markProposed(config)
                    screenVM.saveCurrentAsTemplate()
                }
                // 거절해도 markProposed 한다 — 다시 묻지 않기 위해서다.
                Button(String(localized: "Not now"), role: .cancel) {
                    RepeatDetector.markProposed(config)
                }
            } message: { _ in
                Text(String(localized: "Saving it means one tap to start next time."))
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhase(oldPhase, newPhase)
            }
            .onChange(of: screenVM.state) { oldState, newState in
                handleStateChange(oldState, newState)
            }
            .onChange(of: screenVM.remaining) { _, newValue in
                #if targetEnvironment(macCatalyst)
                MenuBarManager.shared.update(remaining: newValue, state: screenVM.state)
                #endif
            }
    }

    // MARK: - Sub Views

    /// 하단 바: 왼쪽 = 모드 세그먼트(타이머·발표), 오른쪽 = 도구(템플릿·설정)
    private var mainContent: some View {
        NavigationStack {
            // 두 모드 모두 다이얼 화면 사용 — 발표 모드는 구간 링·구간 편집 모달이 추가됨
            TimerMainView()
                .padding()
                .toolbar { bottomToolbar }
                // 타이머 화면 어디를 탭해도 키보드 내림 (버튼·드래그 등 기존 조작은 그대로)
                // NavigationStack 전체에 붙이면 push된 설정 Form의 행 탭과 경합해 터치가 씹힘
                .simultaneousGesture(TapGesture().onEnded {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                })
        }
        .environmentObject(screenVM)
        // 온보딩은 **여기서** 띄운다 — 고른 상황을 다이얼에 올리고 템플릿까지 저장하므로
        // `screenVM` 이 있는 자리여야 한다(예전엔 ContentView 에 있어서 손이 닿지 않았다).
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView(isPresented: $showOnboarding)
                .environmentObject(screenVM)
        }
        .sheet(isPresented: $showHistory) {
            TimerTemplateView { selected in
                screenVM.apply(template: selected)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ToolbarContentBuilder
    private var bottomToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            // ⚠️ Picker("", …)는 빈 문자열을 문자열 카탈로그에 추출시켜 다국어 검사를 막는다.
            //    라벨은 제대로 주고 화면에서만 숨긴다.
            Picker(selection: modeBinding) {
                Image(systemName: "timer")
                    .accessibilityLabel(String(localized: "Timer"))
                    .tag(AppMode.timer)
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .accessibilityLabel(String(localized: "Presentation"))
                    .tag(AppMode.presentation)
            } label: {
                Text(String(localized: "Mode"))
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            // 타이머를 두 번 이상 완주한 뒤, 발표 모드를 아직 안 써 봤을 때만 알려준다
            .modifier(PresentationModeTipAnchor())

            Spacer()

            Button {
                showHistory = true
            } label: {
                Image(systemName: "list.bullet")
            }
            .accessibilityLabel(String(localized: "Saved timers"))

            NavigationLink {
                NoticeSettingView()
                    .environmentObject(appStateManager)
                    .environmentObject(screenVM)
            } label: {
                Image(systemName: "gearshape")
                    .modifier(MultiDeviceTipAnchor())
            }
            .accessibilityLabel(String(localized: "Settings"))
        }
    }

    // MARK: - Actions

    /// 만족도 게이트 조건 — 의견 요청(FeedbackNudge)이 "게이트가 뜰 차례인지"를 볼 때도 같은 값을 봐야
    /// 한 실행에서 두 번 묻는 일이 없다. 그래서 한 곳에 둔다.
    static let satisfactionPolicy = LeeoReviewPolicy(
        minLaunches: 3,
        minDaysSinceInstall: 2,
        minSignificantEvents: 3
    )

    private func setupOnAppear() {
        // 콜드 런치에서는 scenePhase onChange 가 오지 않는다 — 여기서도 표시를 남긴다.
        DevicePresence.beginHeartbeat()

        // 사람이 실제로 화면을 본 순간 = 실행 1회 + 오늘의 활동(app_open).
        // 콜드 런치는 scenePhase onChange가 안 오므로 여기서 남긴다(내부 쓰로틀로 중복 없음).
        ActivityReporter.reportForegroundOpen()

        // 실행 횟수를 올린 뒤에 판정한다 — 순서가 뒤바뀌면 10회째가 아니라 11회째에 뜬다.
        if FeedbackNudge.isDue(policy: Self.satisfactionPolicy) {
            FeedbackNudge.markShown()
            showFeedbackNudge = true
        }

        // 그랜드파더링된 기존 사용자에게 무료 Pro 안내 (최초 1회)
        if StoreManager.isGrandfathered,
           !UserDefaults.standard.bool(forKey: Self.grandfatherThankedKey) {
            UserDefaults.standard.set(true, forKey: Self.grandfatherThankedKey)
            showGrandfatherThanks = true
        }

        screenVM.attachContext(context)
        screenVM.seedTemplatesIfNeeded()
        screenVM.timerVM.showToast = { toast.show(Toast($0)) }
        screenVM.showToast = { toast.show(Toast($0)) }
        screenVM.timerVM.appStateManager = appStateManager
        screenVM.timerVM.modelContext = context
        screenVM.initialConfiguration()
        screenVM.restoreTimerIfNeeded()
        // 다이나믹 아일랜드에서 눌러 둔 명령을 먼저 적용하고, 남은 활동이 있으면 치운다
        screenVM.applyPendingLiveActivityCommand()
        screenVM.cleanUpOrphanLiveActivities()
        // 실행 중 타이머가 없으면 마지막 사용 설정을 다이얼에 복원
        screenVM.restoreLastUsedConfigIfNeeded()
        // 복원된 그 설정이 여러 날 반복된 것이면 저장을 먼저 제안한다(복원 **뒤에** 판단해야 한다)
        offerToSaveRecurringSetupIfDue()

        #if targetEnvironment(macCatalyst)
        // 지금 맥에서 돌고 있으니 "맥 있으세요?"를 물어볼 이유가 없다 — 아는 건 묻지 않는다.
        DeviceOwnership.markUsed(.mac)

        // 메뉴바 타이머 (RereminderMenuBar 번들이 임베드된 빌드에서만 동작)
        MenuBarManager.shared.setUpIfAvailable()
        MenuBarManager.shared.onPauseToggle = {
            if screenVM.state == .running || screenVM.state == .overtime {
                screenVM.pause()
            } else if screenVM.state == .paused {
                screenVM.resume()
            }
        }
        MenuBarManager.shared.onStop = {
            screenVM.cancel()
        }
        MenuBarManager.shared.update(remaining: screenVM.remaining, state: screenVM.state)
        #endif
    }

    private func handleScenePhase(_: ScenePhase, _ newPhase: ScenePhase) {
        appStateManager.updateState(newPhase)
        // 다른 기기(맥)에서 "이 기기 켜져 있어요"를 볼 수 있게 표시를 남긴다.
        // 앞에 있는 동안만 — 뒤로 가면 멈춰야 "연결됨"이 거짓말이 되지 않는다.
        if newPhase == .active {
            DevicePresence.beginHeartbeat()
        } else {
            DevicePresence.endHeartbeat()
        }
        if newPhase == .active {
            screenVM.timerVM.engine.recalculateOnForeground()
            handleControlWidgetAction()
            screenVM.applyPendingLiveActivityCommand()
            // 며칠씩 살아 있는 프로세스에서도 "오늘 열었다"를 놓치지 않게 복귀마다 확인한다.
            ActivityReporter.reportForegroundOpen()
        }
    }

    private func handleStateChange(_ oldState: TimerState, _ newState: TimerState) {
        UIApplication.shared.isIdleTimerDisabled =
            (newState == .running || newState == .paused || newState == .overtime)

        // 막 시작한 순간에만 — 일시정지에서 돌아올 때마다 물으면 잔소리가 된다.
        if newState == .running, oldState != .paused { askOrRemindAboutDevices() }

        #if targetEnvironment(macCatalyst)
        MenuBarManager.shared.update(remaining: screenVM.remaining, state: newState)
        #endif
    }

    // MARK: - 반복 설정 저장 제안

    private var repeatProposalBinding: Binding<Bool> {
        Binding(get: { repeatProposal != nil },
                set: { if !$0 { repeatProposal = nil } })
    }

    /// 지금 다이얼에 올라온 설정이 **여러 날 반복된 것인데 아직 저장돼 있지 않으면** 한 번 묻는다.
    ///
    /// ⚠️ 다른 안내가 뜨는 차례면 양보한다 — 한 화면에 두 개가 겹치면 둘 다 읽히지 않는다.
    /// ⚠️ 대기 중일 때만. 타이머가 도는 중에 저장 이야기를 꺼내면 화면의 주인공을 가린다.
    private func offerToSaveRecurringSetupIfDue() {
        guard isIdle, !showOnboarding else { return }
        guard !showFeedbackNudge, !showGrandfatherThanks, deviceQuestion == nil else { return }

        let cfg = screenVM.normalizedCurrentConfig
        let config = RepeatDetector.Config(mainSec: cfg.mainSec, offsets: cfg.offsets)
        guard RepeatDetector.shouldPropose(config, isAlreadySaved: hasTemplate(matching: config)) else { return }

        repeatProposal = config
    }

    /// 같은 시간·같은 알림 지점의 템플릿이 이미 있는가.
    /// (문구까지 같아야 하는 `TemplateQuickBar` 의 판정보다 느슨하다 — 여기서 묻는 것은
    ///  "이 상황을 앱이 기억하고 있나"이고, 문구가 달라도 기억은 하고 있는 것이다.)
    private func hasTemplate(matching config: RepeatDetector.Config) -> Bool {
        savedTemplates.contains {
            $0.mainSeconds == config.mainSec && $0.prealertOffsetsSec.sorted() == config.offsets
        }
    }

    // MARK: - 기기 보유 질문 / 안내

    /// 타이머를 걸 때마다 한 번씩 확인한다 — 물어볼 게 있으면 묻고, 없으면 가끔 권한다.
    /// 둘 중 하나만 한다(같은 실행에서 질문과 안내가 겹치면 시끄럽다).
    private func askOrRemindAboutDevices() {
        let starts = Int(UsageMetrics.value(.timerStarts))

        if let device = DeviceOwnership.pendingQuestion(timerStarts: starts) {
            deviceQuestion = device
            return
        }
        // 가지고 있다고 했는데 아직 그 기기에서 안 써 본 사람에게만, 다섯 번 걸 때마다 한 번.
        if let device = DeviceOwnership.pendingReminder(timerStarts: starts) {
            DeviceOwnership.markReminderShown(device, atStart: starts)
            toast.show(Toast(deviceReminderText(device), duration: 3.0))
        }
    }

    private var deviceQuestionBinding: Binding<Bool> {
        Binding(get: { deviceQuestion != nil },
                set: { if !$0 { deviceQuestion = nil } })
    }

    private var deviceQuestionTitle: String {
        switch deviceQuestion {
        case .mac:            return String(localized: "Do you have a Mac?")
        case .watch, .none:   return String(localized: "Do you have an Apple Watch?")
        }
    }

    private func deviceQuestionMessage(_ device: DeviceOwnership.Device) -> String {
        switch device {
        case .watch: return String(localized: "If you do, you can check the remaining time right on your wrist while the timer runs.")
        case .mac:   return String(localized: "If you do, Rereminder can show the remaining time in your Mac menu bar.")
        }
    }

    /// 답을 저장하고, 있다고 했으면 그 자리에서 어디를 보면 되는지 알려준다.
    private func answerDeviceQuestion(_ device: DeviceOwnership.Device, owns: Bool) {
        DeviceOwnership.record(owns ? .yes : .no, for: device)
        deviceQuestion = nil
        guard owns else { return }   // 없다고 한 기기는 안내도 하지 않는다
        toast.show(Toast(deviceGuidanceText(device), duration: 3.0))
    }

    private func deviceGuidanceText(_ device: DeviceOwnership.Device) -> String {
        switch device {
        case .watch: return String(localized: "Now check the remaining time on your Apple Watch too")
        case .mac:   return String(localized: "Now check the remaining time in your Mac menu bar too")
        }
    }

    private func deviceReminderText(_ device: DeviceOwnership.Device) -> String {
        switch device {
        case .watch: return String(localized: "Open Rereminder on your Apple Watch to follow along")
        case .mac:   return String(localized: "Open Rereminder on your Mac to follow along")
        }
    }

    private func handleControlWidgetAction() {
        let shared = UserDefaults(suiteName: "group.leeo.toki")
        guard let action = shared?.string(forKey: "controlWidgetAction") else { return }
        shared?.removeObject(forKey: "controlWidgetAction")

        switch action {
        case "start":
            if screenVM.state == .idle || screenVM.state == .finished {
                if let siriDuration = shared?.object(forKey: "siriTimerDuration") as? Int, siriDuration > 0 {
                    shared?.removeObject(forKey: "siriTimerDuration")
                    screenVM.mainMinutes = siriDuration / 60
                    screenVM.mainSeconds = siriDuration % 60
                    screenVM.initialConfiguration()
                }
                screenVM.start()
            }
        case "stop":
            if screenVM.state == .running || screenVM.state == .paused || screenVM.state == .overtime {
                screenVM.cancel()
            }
        case "pause":
            if screenVM.state == .running {
                screenVM.pause()
            }
        case "resume":
            if screenVM.state == .paused {
                screenVM.resume()
            }
        default:
            break
        }
    }
}
