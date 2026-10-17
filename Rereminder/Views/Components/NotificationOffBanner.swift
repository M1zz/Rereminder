//
//  NotificationOffBanner.swift
//  Rereminder
//
//  알림 권한이 꺼져 있을 때 원 아래에 서는 한 줄. 누르면 **알림 설정 화면**으로 바로 간다.
//  언제 서는지는 `NotificationOffNotice` 가 정한다.
//
//  ⚠️ **모달이 아니다.** 알림창으로 띄우면 앱을 열 때마다 무언가를 닫아야 하는 앱이 된다.
//     시작하는 순간의 알림창(`TimerScreenViewModel.holdForPermissionWarning`)은 따로 있다.
//

import SwiftUI

struct NotificationOffBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Button {
                ActivityReporter.log("notification_off_banner_tapped")
                // 앱 설정 첫 화면이 아니라 알림 설정으로 바로 — 한 단계라도 더 들어가야 하면 그만둔다.
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(alignment: .center, spacing: DSSpacing.xs) {
                    Image(systemName: "bell.slash.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DSColor.negativeSoft)
                    Text(String(localized: "Notifications are off, so nothing rings once the screen is off."))
                        .font(DSFont.callout)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(localized: "Turn On"))
                        .font(DSFont.callout.weight(.semibold))
                        .foregroundStyle(DSColor.negativeSoft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(String(localized: "Opens notification settings")))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Close"))
        }
        .padding(.leading, DSSpacing.md)
        .padding(.trailing, DSSpacing.xs)
        .padding(.vertical, DSSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(DSColor.negativeSoft.opacity(0.12))
        )
        .onAppear { ActivityReporter.log("notification_off_banner_shown") }
    }
}
