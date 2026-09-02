//
//  RereminderApp.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import SwiftData
import SwiftUI
import TipKit
import LeeoKit

@main
struct RereminderApp: App {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        // 분석 이벤트 → 익명 사용 허브 전송 훅 — 다른 어떤 로그보다 먼저 꽂아야 유실이 없다
        AnalyticsManager.eventSink = { ActivityReporter.log($0) }

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
        if LeeoRemoteFlags.isEnabled(RereminderFlag.cloudSyncEnabled) {
            _ = CloudTimerSyncManager.shared
        }

        // TipKit (iOS 17+)
        if #available(iOS 17.0, *) {
            try? Tips.configure()
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
            ContentView()
                .preferredColorScheme(themeManager.colorScheme)
                .tint(themeManager.accentColor)
                .environmentObject(storeManager)
                .environmentObject(themeManager)
        }
        .modelContainer(Self.sharedModelContainer)
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
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            print("❌ SwiftData 컨테이너 로드 실패 — 이번 실행은 저장되지 않는다: \(error)")
            // 앱을 죽이지는 않는다. 타이머 자체는 SwiftData 없이도 돌아간다.
            return try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                                   cloudKitDatabase: .none)
            )
        }
    }()
}
