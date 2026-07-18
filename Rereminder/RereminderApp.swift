//
//  RereminderApp.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import SwiftUI
import TipKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct RereminderApp: App {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif

        // 기존 한국어 ringMode 값 마이그레이션
        RingMode.migrateIfNeeded()

        // WatchConnectivity 초기화
        _ = WatchConnectivityManager.shared

        // iCloud KVS 동기화 초기화 (iPhone ↔ Mac 타이머 동기화)
        _ = CloudTimerSyncManager.shared

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
