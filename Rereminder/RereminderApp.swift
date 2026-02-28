//
//  RereminderApp.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import SwiftUI

@main
struct RereminderApp: App {
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        // WatchConnectivity 초기화
        _ = WatchConnectivityManager.shared

        // 앱 시작 시 UIWindow tintColor를 즉시 설정하여 색상 깜빡임 방지
        ThemeManager.applyInitialTint()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(themeManager.accentColor)
                .environmentObject(storeManager)
                .environmentObject(themeManager)
        }
        .modelContainer(for: [Timer.self, TimerRecord.self])
    }
}
