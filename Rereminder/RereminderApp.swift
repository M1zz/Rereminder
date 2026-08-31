//
//  RereminderApp.swift
//  toki
//
//  Created by POS on 7/7/25.
//

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
        .modelContainer(for: [Timer.self, TimerRecord.self])
    }
}
