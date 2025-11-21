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
    @AppStorage("useAlarmKit") private var useAlarmKit: Bool = true
    @EnvironmentObject var appStateManager: AppStateManager
    @State private var showAlarmKitInfo = false
    @State private var showOnboarding = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16){
                    Text("알림 스타일")
                    Picker("notice", selection: $ringMode) {
                        ForEach(RingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section(header: Text("알림 방식")) {
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
            }

            Section {
                Toggle("토스트 메세지 표시", isOn: $toastEnabled)
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func shareApp() {
        guard let appURL = URL(string: "https://apps.apple.com/app/toki") else { return }

        let activityViewController = UIActivityViewController(
            activityItems: [
                "멘토링과 발표를 위한 타이머 앱 Toki를 확인해보세요!",
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
