//
//  RereminderApp.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import OSLog
import SwiftData
import SwiftUI
import TipKit
import LeeoKit

@main
struct RereminderApp: App {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    /// 켤 때마다 같은 자리에서 죽는 일(크래시 루프)을 알아챈다. 두 번 연속 끝나지 못했으면 이번 실행은
    /// **세이프 모드** — 기기 간 동기화를 쉬고, 돌던 타이머·마지막 설정을 되살리지 않고 빈 다이얼로 연다
    /// (되살리는 저장 상태가 원인일 때 그걸 또 읽으면 영영 못 연다). 첫 화면이 3초 살아 있으면 성공으로 친다
    /// (`TimerUnifiedView.finishSetupOnAppear`). 다음 실행은 평소대로 연다.
    static let launchGuard = LeeoCrashLoopGuard(name: "app", defaults: .standard)
    /// 이번 실행이 세이프 모드인가 — `init` 에서 한 번 정해진다.
    static var isSafeLaunch: Bool { launchGuard.isInSafeMode }

    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.xa.toki", category: "app")
    /// 시작에서 무거운 구간(저장소 열기)을 Instruments 의 os_signpost 로 본다.
    static let signposter = OSSignposter(subsystem: Bundle.main.bundleIdentifier ?? "com.xa.toki",
                                         category: "launch")

    init() {
        // 백업 금고는 맨 먼저 — 예약된 복원을 저장소(SwiftData · 앱 그룹 defaults)가 열리기 전에 적용한다.
        LeeoVault.start(RereminderSpec.self)

        // 분석 이벤트 → 익명 사용 허브 전송 훅 — 다른 어떤 로그보다 먼저 꽂아야 유실이 없다
        AnalyticsManager.eventSink = { ActivityReporter.log($0) }

        // 크래시 루프 판정은 무엇보다 먼저 — 아래 시작 작업 중 하나가 원인일 수 있다.
        let safeLaunch = Self.launchGuard.beginLaunch()
        if safeLaunch {
            Self.log.error("직전 실행이 연달아 끝나지 못했다 — 세이프 모드로 연다")
        }
        if LeeoRemoteFlags.isEnabled(RereminderFlag.usageReportingEnabled) {
            // 끝나지 못한 실행 수를 허브로 보낸다(설치당 소수, 보내면 0 으로 돌아간다).
            Task { await Self.launchGuard.reportIncompleteLaunches(to: LeeoUsageReporter(spec: RereminderSpec.self)) }
        }

        // 원격 킬스위치 갱신 — 이번 실행은 캐시로 동작, 다음 실행부터 반영 (6시간 쓰로틀)
        LeeoRemoteFlags(spec: RereminderSpec.self, appGroupSuiteName: "group.leeo.toki")
            .refreshInBackground(RereminderFlag.self)

        // MetricKit 크래시/행 수집 — 구독만 하고 즉시 반환 (런치 비용 0)
        LeeoDiagnostics.shared.start(
            spec: RereminderSpec.self,
            isEnabled: { LeeoRemoteFlags.isEnabled(RereminderFlag.diagnosticsEnabled) }
        )

        // 기존 한국어 ringMode 값 마이그레이션
        RingMode.migrateIfNeeded()

        // 알림 버튼(정지·다시 알림)을 받는 델리게이트 — 되풀이 알림을 끌 수 있는 유일한 경로다
        AlertNotificationDelegate.install()

        // WatchConnectivity 초기화
        _ = WatchConnectivityManager.shared

        // iCloud KVS 동기화 초기화 (iPhone ↔ Mac 타이머 동기화) — 킬스위치로 차단 가능
        // 세이프 모드에서는 쉰다 — 다른 기기의 상태를 받아 덮는 길이 시작에서 가장 많은 것을 건드린다.
        if LeeoRemoteFlags.isEnabled(RereminderFlag.cloudSyncEnabled), !safeLaunch {
            _ = CloudTimerSyncManager.shared
        }

        // TipKit (iOS 17+)
        if #available(iOS 17.0, *) {
            try? Tips.configure()
            #if DEBUG
            // 스크린샷 장면에 팁 풍선이 끼지 않게.
            if ScreenshotScene.isActive { Tips.hideAllTipsForTesting() }
            #endif
        }

        #if targetEnvironment(macCatalyst)
        // 메뉴바는 뷰 수명주기와 무관하게 앱 시작 시 바로 생성
        MenuBarManager.shared.setUpIfAvailable()
        #endif

        // 앱 시작 시 UIWindow tintColor를 즉시 설정하여 색상 깜빡임 방지
        ThemeManager.applyInitialTint()

        // 익명 사용 스냅샷을 iCloud로 전송 (백그라운드, 12시간 쓰로틀)
        // ⚠️ "사람이 앱을 열었다"는 신호는 여기가 아니라 화면이 실제로 뜨는 경로에서 남긴다
        //    (TimerUnifiedView의 scenePhase → ActivityReporter.reportForegroundOpen()).
        ActivityReporter.reportProcessStart()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let shot = ReviewShot.giftProductID {
                ReviewShotView(productID: shot)
                    .preferredColorScheme(.dark)
                    .tint(themeManager.accentColor)
            } else {
                mainWindow
            }
            #else
            mainWindow
            #endif
        }
        .modelContainer(Self.sharedModelContainer)
    }

    private var mainWindow: some View {
            ContentView()
                .storeFallbackNotice()
                // 아이폰 듀오: 창 크기·접힌 선을 재서 아래로 흘린다. 접혀 있으면 아무것도 바뀌지 않는다.
                // 맨 바깥에 건다 — 루트에서 띄우는 시트·알림창도 접힘을 알아야 선을 비켜 선다.
                .foldAware()
                .preferredColorScheme(themeManager.colorScheme)
                .tint(themeManager.accentColor)
                .environmentObject(storeManager)
                .environmentObject(themeManager)
                // 연 구독 중인 사람에게 때가 되면 평생으로 바꾸는 길을 한 번 보인다.
                .subscriptionGraduationPrompt()
                // 개발자가 보낸 의견에 답장하면, 앱이 앞으로 올 때 답장을 시트로 보여 준다 (LeeoKit).
                .leeoFeedbackReplyNotice(RereminderSpec.self)
    }

    // MARK: - SwiftData

    /// 템플릿·기록 저장소. **CloudKit 동기화는 꺼 둔다.**
    ///
    /// ⚠️ `.modelContainer(for:)` 의 기본값은 `cloudKitDatabase: .automatic` 이라,
    ///    앱에 iCloud(CloudKit) 엔타이틀먼트가 있으면 이 **로컬** 스토어까지 CloudKit 스키마
    ///    규칙을 따지게 된다: 모든 속성이 optional 이거나 기본값이 있어야 하고, 관계도 optional
    ///    이어야 하며, `@Attribute(.unique)` 는 쓸 수 없다. `Timer`·`TimerRecord` 는 셋 다
    ///    어기므로 **스토어가 통째로 로드에 실패했고, 템플릿·기록이 하나도 저장되지 않았다**
    ///    (피드백 허브용 iCloud 엔타이틀먼트가 붙은 2026-07-19 이후 조용히. 화면에는 아무
    ///    오류도 뜨지 않고 콘솔에만 "Store failed to load" 가 찍힌다 — "저장이 안 된다"는
    ///    제보의 정체다).
    ///
    /// 기기 간 타이머 동기화는 CloudKit 이 아니라 `CloudTimerSyncManager`(iCloud KVS)가 한다.
    /// 나중에 템플릿까지 동기화하고 싶다면 엔타이틀먼트가 아니라 **모델을 먼저** 위 규칙에
    /// 맞춰야 한다(unique 제거 + 마이그레이션).
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Timer.self, TimerRecord.self])
        // 앱 그룹 컨테이너 — 위젯·인텐트와 같은 자리를 쓰던 기존 스토어 경로를 유지한다
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.leeo.toki"),
            cloudKitDatabase: .none
        )
        let state = RereminderApp.signposter.beginInterval("ModelContainer")
        defer { RereminderApp.signposter.endInterval("ModelContainer", state) }
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            RereminderApp.log.fault("SwiftData 컨테이너 로드 실패 — 이번 실행은 저장되지 않는다: \(String(describing: error), privacy: .public)")
            // 앱을 죽이지는 않는다. 타이머 자체는 SwiftData 없이도 돌아간다.
            // 메모리 스토어는 파일·CloudKit 규칙을 타지 않아 실패할 길이 없다 — 여기서 실패하면 되돌아갈 곳도 없다.
            return StoreFallback.memoryContainer(schema: schema, after: error)
        }
    }()
}

// MARK: - 저장소를 못 연 날
//
// 원래 저장소를 못 열면 이번 실행만 메모리에서 연다. 디스크의 기록은 건드리지 않는다.
// 예전에는 아무 말 없이 넘어가서, 사용자는 저장되는 줄 알고 계속 적었다 — 이제는 알린다.

enum StoreFallback {
    /// 이번 실행이 임시(메모리) 저장소로 열렸는가
    private(set) static var isActive = false

    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 메모리 저장소마저 안 되는 건 스키마 자체가 잘못된 것 — 개발 중에 바로 드러난다
            fatalError("메모리 저장소도 열지 못함: \(error)")
        }
    }
}

extension View {
    /// 임시 저장소로 열렸으면 한 번 알린다. 앱의 맨 바깥 화면에 붙인다.
    func storeFallbackNotice() -> some View {
        modifier(StoreFallbackNotice())
    }
}

private struct StoreFallbackNotice: ViewModifier {
    @State private var isPresented = StoreFallback.isActive

    func body(content: Content) -> some View {
        content.alert("Couldn't open your records", isPresented: $isPresented) {
        } message: {
            Text("Your saved records haven't been deleted. Anything you add now won't be saved, so please close the app and open it again.")
        }
    }
}
