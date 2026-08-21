//
//  RereminderClipApp.swift
//  RereminderClip
//
//  App Clip 진입점.
//  본 앱의 핵심 가치인 "끝나기 전 3번 알림"만 남긴 경량 버전이다.
//

import SwiftUI

@main
struct RereminderClipApp: App {
    @StateObject private var viewModel = ClipTimerViewModel()
    // 클립에서 처음 만난 색·모드가 전체 앱과 달라 보이지 않도록 같은 테마를 쓴다.
    // (클립엔 테마 설정 화면이 없으므로 항상 기본값 = Ocean 블루 + 다크)
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        ThemeManager.applyInitialTint()
    }

    var body: some Scene {
        WindowGroup {
            ClipTimerView()
                .environmentObject(viewModel)
                .tint(themeManager.accentColor)
                .preferredColorScheme(themeManager.colorScheme)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    viewModel.handle(invocationURL: activity.webpageURL)
                }
        }
    }
}
