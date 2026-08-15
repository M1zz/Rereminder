//
//  TimerUnifiedView.swift
//  Rereminder
//
//  Created by xa on 8/28/25.
//

import Foundation
import SwiftUI
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

        #if targetEnvironment(macCatalyst)
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
        if newPhase == .active {
            screenVM.timerVM.engine.recalculateOnForeground()
            handleControlWidgetAction()
            screenVM.applyPendingLiveActivityCommand()
            // 며칠씩 살아 있는 프로세스에서도 "오늘 열었다"를 놓치지 않게 복귀마다 확인한다.
            ActivityReporter.reportForegroundOpen()
        }
    }

    private func handleStateChange(_: TimerState, _ newState: TimerState) {
        UIApplication.shared.isIdleTimerDisabled =
            (newState == .running || newState == .paused || newState == .overtime)

        #if targetEnvironment(macCatalyst)
        MenuBarManager.shared.update(remaining: screenVM.remaining, state: newState)
        #endif
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
