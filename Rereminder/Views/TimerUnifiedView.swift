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
            .leeoSatisfactionCheck(
                RereminderSpec.self,
                policy: LeeoReviewPolicy(
                    minLaunches: 3,
                    minDaysSinceInstall: 2,
                    minSignificantEvents: 3
                )
            )
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
            Picker("", selection: modeBinding) {
                Image(systemName: "timer")
                    .accessibilityLabel(String(localized: "Timer"))
                    .tag(AppMode.timer)
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .accessibilityLabel(String(localized: "Presentation"))
                    .tag(AppMode.presentation)
            }
            .pickerStyle(.segmented)
            .fixedSize()

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

    private func setupOnAppear() {
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
