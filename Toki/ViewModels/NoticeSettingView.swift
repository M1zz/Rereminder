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
        }
        .onAppear {
            appStateManager.checkNotificationPermission()
        }
        .alert("향상된 알림이란?", isPresented: $showAlarmKitInfo) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("타이머 전용 알림 시스템입니다.\n\n• 백그라운드에서도 정확한 시간에 알림이 울립니다\n• 자동으로 권한을 관리하여 편리합니다\n• 중복 알림을 방지하여 깔끔합니다\n• 멘토링이나 발표 시 시간 관리에 최적화되어 있습니다\n\n권장: 향상된 알림을 켜두는 것을 추천합니다")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NoticeSettingView()
        .environmentObject(AppStateManager())
}
