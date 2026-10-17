//
//  ContentView.swift
//  toki
//
//  Created by POS on 7/7/25.
//

import OSLog
import SwiftData
import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TimerUnifiedView()
            .onAppear {
                configureMacWindowIfNeeded()
                #if DEBUG
                // 스크린샷 장면에서는 권한 창이 화면을 가린다.
                if ScreenshotScene.isActive { return }
                #endif
                // Sound/Vibration 알림 Request Permission
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge]) { _, error in
                        if let error = error {
                            RereminderApp.log.error("알림 권한 요청 오류: \(String(describing: error), privacy: .public)")
                        }
                    }
            }
            #if targetEnvironment(macCatalyst)
            // macOS: 큰 화면에 맞춰 글자를 한 단계 키운다
            .environment(\.dynamicTypeSize, .xLarge)
            #endif
    }

    /// Mac(Catalyst)에서 타이머 앱에 어울리는 창 크기로 제약한다.
    private func configureMacWindowIfNeeded() {
        #if targetEnvironment(macCatalyst)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            // 타이머만 남는 컴팩트 창
            windowScene.sizeRestrictions?.minimumSize = CGSize(width: 300, height: 380)
            windowScene.sizeRestrictions?.maximumSize = CGSize(width: 460, height: 620)
            // 타이틀바를 콘텐츠와 통합해 군더더기 줄이기
            windowScene.titlebar?.titleVisibility = .hidden
            windowScene.titlebar?.toolbar = nil
        }
        #endif
    }
}
