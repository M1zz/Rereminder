//
//  NoticeSettingView.swift
//  Toki
//
//  Created by POS on 7/8/25.
//

import SwiftUI
import UserNotifications

struct NoticeSettingView: View {
    @AppStorage("ringMode") private var ringMode: RingMode = .sound
    @AppStorage("pushEnabled") private var pushEnabled: Bool = true
    @AppStorage("toastEnabled") private var toastEnabled: Bool = true
    #if targetEnvironment(macCatalyst)
    @AppStorage("useAlarmKit") private var useAlarmKit: Bool = false
    #else
    @AppStorage("useAlarmKit") private var useAlarmKit: Bool = true
    #endif
    @AppStorage("testModeEnabled") private var testModeEnabled: Bool = false
    @AppStorage("testModeMultiplier") private var testModeMultiplier: Double = 1.0
    @EnvironmentObject var appStateManager: AppStateManager
    @EnvironmentObject var screenVM: TimerScreenViewModel
    @State private var showAlarmKitInfo = false
    @State private var showOnboarding = false
    @State private var showTestModeInfo = false
    @State private var showPermissionGuide = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16){
                    Text("알림 스타일")
                    Picker("notice", selection: $ringMode) {
                        ForEach(RingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // 권한 거부 경고 배너
            if appStateManager.notificationAuthStatus == .denied {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.title2)
                            Text("알림 권한이 거부되었습니다")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }

                        Text("알림 권한이 없으면 다음 기능이 제대로 작동하지 않습니다:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("예비 알림 (1분, 3분, 5분 등)")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("타이머 종료 알림")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("백그라운드에서 알림 수신")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text("Live Activity (다이나믹 아일랜드)")
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.primary)

                        Divider()

                        VStack(spacing: 8) {
                            Button(action: openSettings) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("설정에서 알림 켜기")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                            }

                            Button(action: { showPermissionGuide = true }) {
                                HStack {
                                    Image(systemName: "info.circle")
                                    Text("권한 설정 방법 보기")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Section(header: Text("알림 방식")) {
                #if !targetEnvironment(macCatalyst)
                Toggle(isOn: $useAlarmKit) {
                    HStack {
                        Text("향상된 알림 사용 (권장)")
                        Button(action: {
                            showAlarmKitInfo.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if useAlarmKit {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("백그라운드에서도 정확한 알림")
                        }
                        .font(.caption)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("자동 권한 관리")
                        }
                        .font(.caption)

                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("중복 알림 방지")
                        }
                        .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                } else {
                    Toggle("푸시 알림 보내기", isOn: $pushEnabled)
                }
                #else
                Toggle("푸시 알림 보내기", isOn: $pushEnabled)
                    .disabled(false)

                Text("macOS에서는 기본 알림만 지원됩니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif

                // 알림 권한 상태 표시
                HStack {
                    Text("알림 권한")
                    Spacer()
                    switch appStateManager.notificationAuthStatus {
                    case .authorized:
                        Label("허용됨", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .denied:
                        Button(action: openSettings) {
                            Label("거부됨 - 설정으로 이동", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    case .notDetermined:
                        Button(action: {
                            appStateManager.requestNotificationPermission()
                        }) {
                            Label("권한 요청", systemImage: "questionmark.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    default:
                        Text("알 수 없음")
                            .foregroundStyle(.secondary)
                    }
                }

                // 테스트 알림 버튼
                if appStateManager.notificationAuthStatus == .authorized {
                    Button(action: {
                        appStateManager.sendTestNotification()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.blue)
                            Text("테스트 알림 보내기")
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .foregroundStyle(.primary)

                    Text("버튼을 누르면 1초 후 테스트 알림이 전송됩니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("토스트 메세지 표시", isOn: $toastEnabled)
            }

            Section(header: Text("테스트 모드")) {
                Toggle(isOn: $testModeEnabled) {
                    HStack {
                        Text("빠른 테스트 모드")
                        Button(action: {
                            showTestModeInfo.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onChange(of: testModeEnabled) { _, newValue in
                    if !newValue {
                        testModeMultiplier = 1.0
                    }
                }

                if testModeEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("시간 배수 선택")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("시간 배수", selection: $testModeMultiplier) {
                            Text("1배속 (실시간)").tag(1.0)
                            Text("10배속").tag(10.0)
                            Text("30배속").tag(30.0)
                            Text("60배속").tag(60.0)
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 4) {
                            if testModeMultiplier == 1.0 {
                                Text("실시간으로 동작합니다")
                            } else {
                                Text("10분 타이머 → 약 \(Int(600 / testModeMultiplier))초 후 종료")
                                Text("1분 타이머 → 약 \(Int(60 / testModeMultiplier))초 후 종료")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                    }
                }
            }

            Section(header: Text("도움말")) {
                Button {
                    showOnboarding = true
                } label: {
                    HStack {
                        Label("앱 사용법 보기", systemImage: "book.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    shareApp()
                } label: {
                    HStack {
                        Label("앱 공유하기", systemImage: "square.and.arrow.up")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    rateApp()
                } label: {
                    HStack {
                        Label("별점 주기", systemImage: "star.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Link(destination: URL(string: "mailto:leeo@kakao.com?subject=Toki%20%ED%94%BC%EB%93%9C%EB%B0%B1")!) {
                    HStack {
                        Label("피드백 보내기", systemImage: "envelope.fill")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(header: Text("정보")) {
                HStack {
                    Text("버전")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appStateManager.checkNotificationPermission()
        }
        .alert("향상된 알림이란?", isPresented: $showAlarmKitInfo) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("타이머 전용 알림 시스템입니다.\n\n• 백그라운드에서도 정확한 시간에 알림이 울립니다\n• 자동으로 권한을 관리하여 편리합니다\n• 중복 알림을 방지하여 깔끔합니다\n• 멘토링이나 발표 시 시간 관리에 최적화되어 있습니다\n\n권장: 향상된 알림을 켜두는 것을 추천합니다")
        }
        .alert("빠른 테스트 모드란?", isPresented: $showTestModeInfo) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("타이머가 실제로 잘 동작하는지 빠르게 확인할 수 있는 모드입니다.\n\n• 10배속: 10분 타이머가 1분 만에 종료됩니다\n• 30배속: 10분 타이머가 20초 만에 종료됩니다\n• 60배속: 10분 타이머가 10초 만에 종료됩니다\n\n알림, 예비 알림, 오버타임 등 모든 기능을 빠르게 테스트할 수 있습니다.\n\n⚠️ 실제 사용 시에는 반드시 테스트 모드를 꺼주세요!")
        }
        .alert("알림 권한 설정 방법", isPresented: $showPermissionGuide) {
            Button("설정으로 이동", role: .none) {
                openSettings()
            }
            Button("닫기", role: .cancel) {}
        } message: {
            Text("""
            아래 단계를 따라 알림 권한을 켜주세요:

            1. '설정으로 이동' 버튼을 누르세요
            2. 설정 앱에서 'Toki' 앱을 찾아주세요
            3. '알림(Notifications)' 메뉴를 선택하세요
            4. '알림 허용(Allow Notifications)'을 켜주세요

            💡 권장 설정:
            • 잠금 화면에 표시
            • 알림 센터에 표시
            • 배너로 표시

            이렇게 하면 타이머 알림을 놓치지 않고 받을 수 있습니다!
            """)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
    }

    private func openSettings() {
        #if targetEnvironment(macCatalyst)
        // macOS에서는 시스템 환경설정의 알림 섹션을 열 수 없으므로 안내 메시지만 표시
        // 사용자가 수동으로 System Settings > Notifications > Toki로 이동해야 함
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func shareApp() {
        guard let appURL = URL(string: "https://apps.apple.com/app/toki") else { return }

        let activityViewController = UIActivityViewController(
            activityItems: [
                String(localized: "share_app_message"),
                appURL
            ],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }

            // iPad용 popover 설정
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = topController.view
                popoverController.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }

            topController.present(activityViewController, animated: true)
        }
    }

    private func rateApp() {
        // App Store 리뷰 페이지로 이동
        if let appStoreURL = URL(string: "https://apps.apple.com/app/toki?action=write-review") {
            UIApplication.shared.open(appStoreURL)
        }
    }
}

#Preview {
    NoticeSettingView()
        .environmentObject(AppStateManager())
}
