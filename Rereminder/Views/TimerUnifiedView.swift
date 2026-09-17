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

    // 창단 후원자에게 혜택 변경을 알리는 화면 — 최초 1회.
    // ⚠️ 그랜드파더링 안내보다 **우선한다** — 같은 말을 더 자세히 하므로, 둘 다 띄우면 겹친다.
    @State private var showFounderWelcome = false
    /// 개편 전부터 무료로 쓰던 사람에게 달라진 점 안내 (`LegacyFreeNotice`).
    @State private var showLegacyFreeNotice = false
    /// 혜택 변경 안내 둘 중 하나가 떠 있는가 — 떠 있으면 다른 안내는 전부 양보한다.
    private var isShowingPlanChangeNotice: Bool { showFounderWelcome || showLegacyFreeNotice }

    // 가끔 먼저 물어보는 의견 요청 — 조건 판정은 FeedbackNudge가 한다
    @State private var showFeedbackNudge = false
    @State private var showFeedbackSheet = false

    // 타이머를 실제로 걸었을 때 한 번 물어보는 기기 보유 질문(워치 → 맥).
    // 물어볼지 말지는 DeviceOwnership이 정한다 — "없다"고 한 기기는 다시 꺼내지 않는다.
    @State private var deviceQuestion: DeviceOwnership.Device?

    // 여러 날 반복해서 건 설정을 앱이 먼저 알아채고 "저장해 둘까요?"라고 묻는다.
    // 판정은 RepeatDetector 가 한다 — 한 설정에 한 번, 전체 상한까지만.
    @State private var repeatProposal: RepeatDetector.Config?

    // "지금이 그 시간"일 때 그 설정을 올려 드릴지 묻는다(같은 요일·비슷한 시각의 반복).
    @State private var timeSuggestion: RepeatDetector.Config?

    // 세션을 끝낸 직후 "다음 자리 언제세요?"를 묻는다 — 주기가 긴 사람(학회 발표자·분기
    // 워크숍 진행자)은 석 달 뒤에 앱을 기억하지 못한다. 판정은 NextOccasionReminder 가 한다.
    @State private var showNextOccasion = false

    // 무료 사용자가 "기억하려면 Pro" 를 누른 자리 — 템플릿 페이월로 연다.
    @State private var showRememberPaywall = false
    /// 안내 시트에서 "Pro 알아보기"를 눌렀다 — 시트가 다 닫힌 뒤에 페이월을 연다(겹치면 안 뜬다).
    @State private var showRememberPaywallAfterNotice = false
    // 다음 자리 전날, 무료 사용자에게 "이게 Pro 가 매번 하는 일"이라고 알려 준다(`RememberPitch` ③).
    @State private var eveNotice: NextOccasionReminder.Booking?
    /// 이번 실행에서 다이얼이 기본값으로 돌아간 무료 사용자의 **지난번 설정**.
    /// 사용자가 손으로 그 설정에 다시 맞추면 한 번 말을 건다(`checkReentry`). 앱이 대신 올려 준 경우는 아니다.
    @State private var reentryTarget: RepeatDetector.Config?

    /// Pro 상태를 관찰한다 — `ProGate` 는 static 이라 구매 직후 알림 문구가 갈라지지 않게 함께 본다.
    @ObservedObject private var store = StoreManager.shared

    private var canRememberSetup: Bool { store.isPro || ProGate.canRememberSetup }

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
            // "기억하려면 Pro" — 반복 감지·다시 연 순간의 한 줄·전날 안내가 모두 여기로 온다.
            .paywallGate(isPresented: $showRememberPaywall, feature: .unlimitedTemplates)
            .toast(toast)
            .alert(String(localized: "Thank you for being an early user 💙"), isPresented: $showGrandfatherThanks) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: "All Pro features — Session Mode, section scripts, unlimited templates, overtime tracking and history — are yours free forever. Nothing you had has been taken away."))
            }
            // 값을 먼저 치른 사람에게 "무엇이 바뀌고, 무엇은 그대로인지"를 보여 준다.
            // 알림 한 줄로는 "내가 산 게 값이 떨어졌나"라는 불안이 풀리지 않는다.
            .sheet(isPresented: $showFounderWelcome) {
                FounderWelcomeView()
            }
            // 개편 전부터 무료로 쓰던 사람 — 얻은 것·잃은 것·그대로 남은 것을 그대로 적어 보여 준다.
            .sheet(isPresented: $showLegacyFreeNotice, onDismiss: {
                guard showRememberPaywallAfterNotice else { return }
                showRememberPaywallAfterNotice = false
                showRememberPaywall = true
            }) {
                LegacyFreeNoticeView(onSeePro: { showRememberPaywallAfterNotice = true })
            }
            // 석 달 뒤에 돌아와 주길 기대하지 않는다 — 전날 저녁에 앱이 먼저 찾아간다.
            .sheet(isPresented: $showNextOccasion) {
                NextOccasionSheet(mainSec: screenVM.normalizedCurrentConfig.mainSec,
                                  offsets: screenVM.normalizedCurrentConfig.offsets,
                                  completions: Int(UsageMetrics.value(.timerCompletions)))
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
            // 무료 사용자에게는 같은 순간이 "기억하려면 Pro" 가 된다(한 번뿐 — `maxFreeProposals`).
            .alert(String(localized: "You use this setup a lot"),
                   isPresented: repeatProposalBinding,
                   presenting: repeatProposal) { config in
                if canRememberSetup {
                    Button(String(localized: "Save as template")) {
                        RepeatDetector.markProposed(config)
                        screenVM.saveCurrentAsTemplate()
                    }
                    // 거절해도 markProposed 한다 — 다시 묻지 않기 위해서다.
                    Button(String(localized: "Not now"), role: .cancel) {
                        RepeatDetector.markProposed(config)
                    }
                } else {
                    Button(String(localized: "Remember it with Pro")) {
                        RepeatDetector.markProposed(config, asFree: true)
                        AnalyticsManager.log(.rememberPitchTapped(kind: "repeat"))
                        ProMention.markTapped()
                        // 다이얼에 먼저 올려 둔다 — 결제하면 바로 저장할 수 있고, 안 해도 오늘은 쓴다.
                        reentryTarget = nil
                        screenVM.applyRepeatConfig(mainSec: config.mainSec, offsets: config.offsets, toast: false)
                        screenVM.rememberRecall = nil
                        showRememberPaywall = true
                    }
                    Button(String(localized: "Not now"), role: .cancel) {
                        RepeatDetector.markProposed(config, asFree: true)
                    }
                }
            } message: { config in
                if canRememberSetup {
                    Text(String(localized: "Saving it means one tap to start next time."))
                } else if ProMention.usesSessionCopy {
                    Text(String(localized: "You've run \(TimeMapper.clockText(config.mainSec)) with \(config.offsets.count) alerts on different days. Pro saves it with your section names and scripts, ready for the next session."))
                } else {
                    Text(String(localized: "You've run \(TimeMapper.clockText(config.mainSec)) with \(config.offsets.count) alerts on different days. Pro remembers it, so next time it's already on the dial."))
                }
            }
            // 예약해 둔 자리의 전날 — 설정은 이미 다이얼에 올렸고, 무료 사용자에게만 그 뜻을 말해 준다.
            .alert(String(localized: "Tomorrow's setup is ready"),
                   isPresented: eveNoticeBinding,
                   presenting: eveNotice) { _ in
                Button(String(localized: "See Pro")) {
                    AnalyticsManager.log(.rememberPitchTapped(kind: "eve"))
                    ProMention.markTapped()
                    showRememberPaywall = true
                }
                Button(String(localized: "OK"), role: .cancel) {}
            } message: { booking in
                if ProMention.usesSessionCopy {
                    Text(String(localized: "Your \(TimeMapper.clockText(booking.mainSec)) setup with \(booking.offsets.count) alerts is back on the dial. Pro saves setups like this with your section names and scripts."))
                } else {
                    Text(String(localized: "Your \(TimeMapper.clockText(booking.mainSec)) setup with \(booking.offsets.count) alerts is back on the dial. This is what Pro does every time you open the app."))
                }
            }
            // 저장 제안이 "이 설정을 기억해 둘까"라면, 이건 "지금 이걸 하려던 참 아닌가"다.
            .alert(String(localized: "Same time as usual"),
                   isPresented: timeSuggestionBinding,
                   presenting: timeSuggestion) { config in
                Button(String(localized: "Set it up")) {
                    RepeatDetector.markTimeSuggested(config)
                    reentryTarget = nil
                    screenVM.applyRepeatConfig(mainSec: config.mainSec, offsets: config.offsets)
                }
                Button(String(localized: "Not now"), role: .cancel) {
                    RepeatDetector.markTimeSuggested(config)
                }
            } message: { config in
                Text(String(localized: "You usually run \(TimeMapper.clockText(config.mainSec)) with \(config.offsets.count) alerts around now."))
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhase(oldPhase, newPhase)
            }
            .onChange(of: screenVM.state) { oldState, newState in
                handleStateChange(oldState, newState)
            }
            .onChange(of: dialFingerprint) { _, _ in
                checkReentry()
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
                    .accessibilityLabel(String(localized: "Session Mode"))
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

        // 지난 예약은 치운다 — 남겨 두면 "예약이 있다"고 판단해 영영 다시 묻지 않는다.
        NextOccasionReminder.clearIfPassed()

        // 창단 후원자 자격을 먼저 확정한다 — 안내를 띄울지 판단하기 전에.
        // 결제 시각을 아는 StoreKit 조회는 느리므로, 지금 상태만으로 되는 판정을 먼저 한다.
        let windowWasOpen = FoundingSupporter.windowClosedAt == nil
        FoundingSupporter.refreshFromCurrentState()
        Task { await FoundingSupporter.refreshFromStoreKit() }

        // 혜택 변경 안내 (최초 1회). 그랜드파더링 안내와 **같은 말을 더 자세히** 하므로,
        // 이게 뜨는 차례면 그쪽은 본 것으로 처리해 두 번 뜨지 않게 한다.
        if FoundingSupporter.shouldAnnounce {
            UserDefaults.standard.set(true, forKey: Self.grandfatherThankedKey)
            showFounderWelcome = true
            AnalyticsManager.log(.founderWelcomeShown)
        }

        // 개편 전부터 무료로 쓰던 사람 — 흔적은 창이 닫히기 **전** 상태까지 봐야 한다.
        // ⚠️ 이 판정과 창 닫기는 `seedTemplatesIfNeeded` 보다 **앞에** 있어야 한다. 시드가 먼저 심기면
        //    새로 설치한 사람의 시드가 "창보다 먼저 만든 템플릿"이 되어 신규 사용자 전원이 이 안내를 본다.
        LegacyFreeNotice.refresh(context: context, windowJustClosed: windowWasOpen)
        if !showFounderWelcome,
           LegacyFreeNotice.shouldAnnounce(isPro: StoreManager.isProUser, isFounder: FoundingSupporter.isFounder) {
            showLegacyFreeNotice = true
            AnalyticsManager.log(.rememberPitchShown(kind: "legacy"))
            ProMention.markMentioned(.legacy)
        }

        // 실행 횟수를 올린 뒤에 판정한다 — 순서가 뒤바뀌면 10회째가 아니라 11회째에 뜬다.
        // ⚠️ 혜택 변경 안내보다 **뒤에서** 판정하고 양보한다. 알림창이 먼저 뜨면 그 시트가 가려져
        //    뜨지 못한다(시뮬레이터에서 실제로 그랬다). 의견 요청은 다음 차례에 와도 되지만
        //    혜택 변경 안내는 그날이 아니면 의미가 줄어든다.
        if !isShowingPlanChangeNotice, FeedbackNudge.isDue(policy: Self.satisfactionPolicy) {
            FeedbackNudge.markShown()
            showFeedbackNudge = true
        }

        // 그랜드파더링된 기존 사용자에게 무료 Pro 안내 (최초 1회)
        if !isShowingPlanChangeNotice,
           StoreManager.isGrandfathered,
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
        // 예약해 둔 자리의 전날이면 그 설정이 오늘의 주인공이다 — 다른 제안은 모두 건너뛴다.
        guard !prepareOccasionEveIfDue() else { return finishSetupOnAppear() }
        // 복원된 그 설정이 여러 날 반복된 것이면 저장을 먼저 제안한다(복원 **뒤에** 판단해야 한다).
        // ⚠️ 셋 중 **하나만** 띄운다 — 앱을 열자마자 두 번 물으면 둘 다 안 읽힌다.
        //    (시간대 제안 → 저장 제안 → 무료 사용자의 "지난번엔 이랬어요" 한 줄)
        if !offerTimeOfDaySetupIfDue(), !offerToSaveRecurringSetupIfDue() {
            showRememberRecallIfDue()
        }
        armReentryWatch()
        finishSetupOnAppear()
    }

    /// 화면이 뜰 때 마지막에 하는 플랫폼 설정 — 안내 판정이 어디서 끝나든 반드시 돈다.
    private func finishSetupOnAppear() {

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
            // 전날 알림을 탭해 돌아온 경우 — 콜드 런치가 아니어도 설정을 올려 준다.
            prepareOccasionEveIfDue()
            // 며칠씩 살아 있는 프로세스에서도 "오늘 열었다"를 놓치지 않게 복귀마다 확인한다.
            ActivityReporter.reportForegroundOpen()
            // ⚠️ **구매 권한을 복귀마다 다시 확인한다.** 프로모션 코드 교환·가족 공유·다른 기기
            //    구매는 전부 앱 밖(App Store)에서 일어나고 흐름은 언제나 "앱 → App Store → 복귀"다.
            //    예전에는 이 시점에 아무것도 하지 않아, 코드를 교환하고 돌아와도 잠긴 그대로였다
            //    (`verifyCurrentEntitlements` 는 정의만 있고 호출부가 한 곳도 없었다).
            Task { await StoreManager.shared.verifyCurrentEntitlements() }
        }
    }

    private func handleStateChange(_ oldState: TimerState, _ newState: TimerState) {
        UIApplication.shared.isIdleTimerDisabled =
            (newState == .running || newState == .paused || newState == .overtime)

        // 걸기 시작하면 "다시 맞추셨네요" 한 줄은 할 일을 다했다 — 끝난 화면에 다시 서지 않게 치운다.
        if newState == .running { screenVM.rememberReentry = nil }

        // 막 시작한 순간에만 — 일시정지에서 돌아올 때마다 물으면 잔소리가 된다.
        if newState == .running, oldState != .paused { askOrRemindAboutDevices() }

        // 끝까지 마친 순간에만 — 도중에 멈춘 사람에게 "다음 자리"를 묻는 건 눈치가 없다.
        if newState == .finished, oldState != .finished { offerNextOccasionIfDue() }

        #if targetEnvironment(macCatalyst)
        MenuBarManager.shared.update(remaining: screenVM.remaining, state: newState)
        #endif
    }

    // MARK: - 다음 자리 예약

    /// 세션을 끝낸 직후 "다음 자리가 언제인가요?"를 한 번 묻는다.
    ///
    /// ⚠️ `RepeatDetector` 로는 이 사람을 못 잡는다 — 그쪽은 **주 단위 반복**을 보는 장치라
    ///    분기 주기(학회 발표·분기 워크숍)에는 영영 걸리지 않는다. 그래서 별도 경로다.
    /// ⚠️ 다른 안내가 뜨는 차례면 양보한다 — 완주 직후는 만족도 게이트도 노리는 자리다.
    private func offerNextOccasionIfDue() {
        guard !showOnboarding else { return }
        guard !showFeedbackNudge, !showGrandfatherThanks, !isShowingPlanChangeNotice,
              deviceQuestion == nil, repeatProposal == nil, timeSuggestion == nil else { return }

        let config = screenVM.normalizedCurrentConfig
        let repeatsWeekly = RepeatDetector.distinctDays(
            of: .init(mainSec: config.mainSec, offsets: config.offsets)
        ) >= 2

        guard NextOccasionReminder.shouldAsk(
            didUseSessionMode: screenVM.currentMode == .presentation,
            completions: Int(UsageMetrics.value(.timerCompletions)),
            repeatsWeekly: repeatsWeekly
        ) else { return }

        NextOccasionReminder.markAsked()
        showNextOccasion = true
    }

    // MARK: - 반복 설정 저장 제안

    private var repeatProposalBinding: Binding<Bool> {
        Binding(get: { repeatProposal != nil },
                set: { if !$0 { repeatProposal = nil } })
    }

    private var timeSuggestionBinding: Binding<Bool> {
        Binding(get: { timeSuggestion != nil },
                set: { if !$0 { timeSuggestion = nil } })
    }

    /// 같은 요일·비슷한 시각에 되풀이하던 설정이 있으면 그걸로 올려 드릴지 묻는다.
    /// - Returns: 물었으면 `true` — 그러면 저장 제안은 이번에 건너뛴다.
    @discardableResult
    private func offerTimeOfDaySetupIfDue() -> Bool {
        guard isIdle, !showOnboarding else { return false }
        guard !showFeedbackNudge, !showGrandfatherThanks, !isShowingPlanChangeNotice, deviceQuestion == nil else { return false }
        guard let config = RepeatDetector.timeOfDaySuggestion() else { return false }

        // 이미 그 설정이 다이얼에 올라와 있으면 권할 것이 없다(마지막 사용 설정이 그것이었던 경우).
        let current = screenVM.normalizedCurrentConfig
        guard RepeatDetector.Config(mainSec: current.mainSec, offsets: current.offsets) != config else {
            return false
        }

        timeSuggestion = config
        return true
    }

    /// 지금 다이얼에 올라온 설정이 **여러 날 반복된 것인데 아직 저장돼 있지 않으면** 한 번 묻는다.
    ///
    /// 무료 사용자에게는 같은 순간이 "기억하려면 Pro" 가 된다 — **한 번뿐**이고
    /// (`RepeatDetector.maxFreeProposals`), 누르면 저장 대신 페이월을 연다. 문구가 처음부터
    /// Pro 라고 말하므로 "권해 놓고 누르는 순간 막는" 일은 없다.
    /// ⚠️ 무료는 콜드 런치에 다이얼이 기본값이라 **마지막으로 쓴 설정**으로 판단한다 —
    ///    다이얼로 보면 무료에서는 반복이 영영 잡히지 않는다.
    /// ⚠️ 다른 안내가 뜨는 차례면 양보한다 — 한 화면에 두 개가 겹치면 둘 다 읽히지 않는다.
    /// ⚠️ 대기 중일 때만. 타이머가 도는 중에 저장 이야기를 꺼내면 화면의 주인공을 가린다.
    /// - Returns: 띄웠으면 `true`.
    @discardableResult
    private func offerToSaveRecurringSetupIfDue() -> Bool {
        guard isIdle, !showOnboarding else { return false }
        guard !showFeedbackNudge, !showGrandfatherThanks, !isShowingPlanChangeNotice, deviceQuestion == nil else { return false }

        let canSave = canRememberSetup
        if !canSave, !LeeoRemoteFlags.isEnabled(RereminderFlag.rememberPitchEnabled) { return false }
        // 무료에게 이 제안은 Pro 권유다 — 설치당 예산 안에서만(`ProMention`).
        if !canSave, !ProMention.canMention(.repeatSetup, isPro: false) { return false }

        let config: RepeatDetector.Config
        if canSave {
            let cfg = screenVM.normalizedCurrentConfig
            config = RepeatDetector.Config(mainSec: cfg.mainSec, offsets: cfg.offsets)
        } else {
            guard let lastUsed = screenVM.lastUsedSetup else { return false }
            config = lastUsed
        }
        guard RepeatDetector.shouldPropose(config,
                                           isAlreadySaved: hasTemplate(matching: config),
                                           canSave: canSave) else { return false }

        repeatProposal = config
        if !canSave {
            AnalyticsManager.log(.rememberPitchShown(kind: "repeat"))
            ProMention.markMentioned(.repeatSetup)
        }
        return true
    }

    // MARK: - "앱이 기억한다" 를 보여 주는 자리 (RememberPitch)

    /// 무료 사용자가 앱을 다시 열어 다이얼이 기본값으로 돌아갔을 때, 다이얼 아래에
    /// "지난번엔 25:00, 알림 3개였어요" 한 줄을 세운다. 모달이 아니다 — 하루 한 번, 일주일까지.
    private func showRememberRecallIfDue() {
        guard isIdle, !showOnboarding, screenVM.currentMode == .timer else { return }
        guard !showFeedbackNudge, !showGrandfatherThanks, !isShowingPlanChangeNotice, deviceQuestion == nil else { return }
        guard LeeoRemoteFlags.isEnabled(RereminderFlag.rememberPitchEnabled) else { return }
        guard ProMention.canMention(.recall, isPro: canRememberSetup) else { return }

        let defaultConfig = RepeatDetector.Config(
            mainSec: TimerScreenViewModel.DefaultSetup.mainSeconds,
            offsets: Array(TimerScreenViewModel.DefaultSetup.offsets)
        )
        guard let config = RememberPitch.recallLine(lastUsed: screenVM.lastUsedSetup,
                                                    canRemember: canRememberSetup,
                                                    isAtDefaultSetup: screenVM.isAtDefaultSetup,
                                                    defaultConfig: defaultConfig) else { return }
        RememberPitch.markRecallShown()
        screenVM.rememberRecall = config
        AnalyticsManager.log(.rememberPitchShown(kind: "recall"))
        ProMention.markMentioned(.recall)
    }

    // MARK: - 손으로 다시 맞춘 순간

    private var dialFingerprint: String {
        let config = screenVM.normalizedCurrentConfig
        return "\(config.mainSec)|\(config.offsets)"
    }

    /// 콜드 런치에 다이얼이 기본값으로 돌아간 무료 사용자라면 지난번 설정을 기억해 둔다.
    private func armReentryWatch() {
        guard !canRememberSetup, isIdle, screenVM.isAtDefaultSetup,
              let lastUsed = screenVM.lastUsedSetup else { return }
        let defaultConfig = RepeatDetector.Config(
            mainSec: TimerScreenViewModel.DefaultSetup.mainSeconds,
            offsets: Array(TimerScreenViewModel.DefaultSetup.offsets).sorted()
        )
        guard lastUsed != defaultConfig else { return }
        reentryTarget = lastUsed
    }

    /// 사용자가 다이얼을 **손으로** 지난번 설정에 다시 맞췄으면 한 줄로 말을 건다.
    ///
    /// "지난번엔 이랬어요"(열 때)보다 이 순간이 낫다 — 불편을 방금 몸으로 겪었다.
    /// ⚠️ 드래그 도중 그 값을 스쳐 지나갈 수 있으므로 1초 머문 뒤에 판단한다.
    /// ⚠️ 한 실행에 한 번, 설치당으로는 `ProMention` 예산 안에서 한 번이다.
    private func checkReentry() {
        guard let target = reentryTarget else { return }
        let current = screenVM.normalizedCurrentConfig
        guard RepeatDetector.Config(mainSec: current.mainSec, offsets: current.offsets) == target else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            let settled = screenVM.normalizedCurrentConfig
            guard reentryTarget == target,
                  RepeatDetector.Config(mainSec: settled.mainSec, offsets: settled.offsets) == target else { return }
            reentryTarget = nil

            guard isIdle, !canRememberSetup, !isShowingPlanChangeNotice,
                  repeatProposal == nil, timeSuggestion == nil, eveNotice == nil,
                  LeeoRemoteFlags.isEnabled(RereminderFlag.rememberPitchEnabled),
                  ProMention.canMention(.reentry, isPro: false) else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                screenVM.rememberRecall = nil
                screenVM.rememberReentry = target
            }
            AnalyticsManager.log(.rememberPitchShown(kind: "reentry"))
            ProMention.markMentioned(.reentry)
        }
    }

    private var eveNoticeBinding: Binding<Bool> {
        Binding(get: { eveNotice != nil },
                set: { if !$0 { eveNotice = nil } })
    }

    /// 예약해 둔 자리의 **전날 저녁부터 그날까지** 앱을 열면, 그때 쓰던 설정을 다이얼에 올린다.
    ///
    /// 예약 시트가 "이 설정 그대로 준비해 둘게요"라고 약속했으므로 **Pro·무료 모두** 올린다.
    /// 무료 사용자에게는 여기에 "이게 Pro 가 매번 하는 일" 이라는 말을 얹는다 — 체험은 이날 한 번이다.
    /// ⚠️ 한 예약에 한 번만 — 그 뒤에 사용자가 바꾼 설정을 다시 덮으면 안 된다.
    /// - Returns: 올렸으면 `true`.
    @discardableResult
    private func prepareOccasionEveIfDue() -> Bool {
        guard isIdle, !showOnboarding else { return false }
        guard let booking = RememberPitch.eveBookingToPrepare(NextOccasionReminder.booking) else { return false }

        RememberPitch.markEvePrepared(booking)
        screenVM.rememberRecall = nil
        withAnimation(.easeInOut(duration: 0.25)) {
            reentryTarget = nil
            screenVM.applyRepeatConfig(mainSec: booking.mainSec, offsets: booking.offsets, toast: false)
        }

        // 혜택 변경 안내가 떠 있으면 알림창은 그 시트에 가려 뜨지 못한다 — 토스트로 알린다.
        // 설정을 올려 주는 건 약속이라 늘 하고, "이게 Pro 가 하는 일" 이라는 말만 예산 안에서 한다.
        if canRememberSetup || !LeeoRemoteFlags.isEnabled(RereminderFlag.rememberPitchEnabled)
            || isShowingPlanChangeNotice || !ProMention.canMention(.eve, isPro: false) {
            toast.show(Toast(String(localized: "Tomorrow's setup is back on the dial"), duration: 3.0))
        } else {
            eveNotice = booking
            AnalyticsManager.log(.rememberPitchShown(kind: "eve"))
            ProMention.markMentioned(.eve)
        }
        return true
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
        // 혜택 변경 안내가 떠 있으면 양보한다 — 그 화면 뒤에서 질문이 쌓이면 둘 다 안 읽힌다.
        guard !isShowingPlanChangeNotice else { return }
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
