//
//  TimerMainView+Notices.swift
//  Rereminder
//
//  원 아래 묶음에 서는 안내 한 줄들 — 알림 꺼짐(`NotificationOffBanner`)과
//  "앱이 기억한다" 권유(`RememberRecallLine`). `TimerMainView` 본문이 길어 따로 둔다.
//

import SwiftUI

// MARK: - "앱이 기억한다" 한 줄 (무료 사용자)

extension TimerMainView {
    /// 다시 연 순간(`recall`)·손으로 다시 맞춘 순간(`reentry`)의 한 줄. 둘은 동시에 서지 않는다 —
    /// 앞의 것은 다이얼이 기본값일 때, 뒤의 것은 지난번 설정일 때만 선다.
    /// 알림 권한이 꺼져 있다는 한 줄(`NotificationOffNotice`). 닫으면 며칠 쉬고 다시 나온다.
    @ViewBuilder
    var notificationOffLine: some View {
        if showNotificationOffBanner {
            NotificationOffBanner {
                NotificationOffNotice.dismiss()
                withAnimation(.easeInOut(duration: 0.2)) { showNotificationOffBanner = false }
            }
            .padding(.horizontal)
            .transition(.opacity)
        }
    }

    /// 알림 꺼짐 한 줄을 세울지 다시 판단한다.
    func refreshNotificationOffBanner() {
        let status = appStateManager.notificationAuthStatus
        NotificationOffNotice.resetIfAllowed(authStatus: status)
        let show = NotificationOffNotice.shouldShow(authStatus: status)
        guard show != showNotificationOffBanner else { return }
        withAnimation(.easeInOut(duration: 0.2)) { showNotificationOffBanner = show }
    }

    @ViewBuilder
    var rememberLines: some View {
        // ⚠️ 알림이 꺼져 있다는 한 줄이 서 있으면 Pro 권유는 물러난다 — 핵심 기능이 안 되는
        //    사람에게 결제를 권하는 건 순서가 틀렸다(`NotificationOffNotice`).
        if !showNotificationOffBanner {
            rememberPitchLines
        }
    }

    @ViewBuilder
    private var rememberPitchLines: some View {
        // 무료 사용자가 다시 열었을 때 "지난번엔 이랬어요" 한 줄(`RememberPitch` ①).
        // 다이얼을 바꾸는 순간 물러난다 — 그때는 이미 할 말이 늦었다.
        if let recall = screenVM.rememberRecall,
           screenVM.isAtDefaultSetup, !store.isPro {
            RememberRecallLine(config: recall) {
                withAnimation(.easeInOut(duration: 0.2)) { screenVM.rememberRecall = nil }
            }
            .padding(.horizontal)
            .transition(.opacity)
        }
        // 손으로 지난번 설정에 다시 맞춘 직후의 한 줄 — 그 설정에서 벗어나면 물러난다.
        if let reentry = screenVM.rememberReentry, !store.isPro,
           reentry.mainSec == screenVM.normalizedCurrentConfig.mainSec,
           reentry.offsets == screenVM.normalizedCurrentConfig.offsets {
            RememberRecallLine(config: reentry, kind: .reentry) {
                withAnimation(.easeInOut(duration: 0.2)) { screenVM.rememberReentry = nil }
            }
            .padding(.horizontal)
            .transition(.opacity)
        }
    }
}
