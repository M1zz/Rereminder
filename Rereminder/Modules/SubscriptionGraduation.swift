//
//  SubscriptionGraduation.swift
//  Rereminder
//
//  구독 졸업: 연 구독 중인 사람에게 평생(졸업가 Pro 평생, `com.xa.toki.pro.graduate`)으로 옮겨 갈 길.
//
//  · 앱이 열릴 때 구독 중이고 때가 됐으면(6개월째 · 갱신 7일 전, 창마다 한 번) 시트를 한 번 띄운다.
//    판정은 LeeoKit 의 `LeeoGraduation.isDue` 다.
//  · 설정의 Pro 칸에는 구독 중일 때만 '평생으로 바꾸기' 줄이 늘 있다(`NoticeSettingView`).
//  · 평생 Pro 를 이미 가졌으면(졸업 뒤 해지 전) 제안하지 않는다.
//
//  ⚠️ 시트가 실제로 보였을 때만 `markOffered` 를 적는다. 다른 시트에 가려 뜨지 못했는데 적어 버리면
//     그 창의 제안이 통째로 사라진다.
//

import SwiftUI
import LeeoKit

/// 졸업 시트 한 장. 설정 줄과 앱 시작 제안이 같은 것을 띄운다.
struct SubscriptionGraduationSheet: View {
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        LeeoGraduationOfferView(graduate: store.product(.proGraduate)) {
            await store.verifyCurrentEntitlements()
        }
        .task { await store.loadProducts() }
        // 졸업했는지는 `purchase_completed:com.xa.toki.pro.graduate` 가 센다.
        .onAppear { LeeoGraduation.markOffered() }
    }
}

/// 앱 시작 때 한 번 졸업을 제안하는 자리.
private struct SubscriptionGraduationPrompt: ViewModifier {
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .task {
                // 첫 화면의 안내들이 먼저 자리를 잡게 둔다.
                try? await Task.sleep(for: .seconds(3))
                if await SubscriptionGraduation.isDue() { isPresented = true }
            }
            .sheet(isPresented: $isPresented) {
                SubscriptionGraduationSheet()
            }
    }
}

enum SubscriptionGraduation {
    /// 지금 졸업을 제안할 때인가.
    @MainActor
    static func isDue(now: Date = Date()) async -> Bool {
        guard !StoreManager.storedPurchaseFlag, !RereminderApp.isSafeLaunch else { return false }
        #if DEBUG
        if ScreenshotScene.isActive { return false }
        #endif
        guard let subscription = await LeeoGraduation.currentSubscription(among: StoreManager.subscriptionProductIDs)
        else { return false }
        return LeeoGraduation.isDue(subscription, now: now, lastOffered: LeeoGraduation.lastOffered())
    }
}

extension View {
    /// 구독 중인 사람에게 때가 되면 졸업(평생으로 바꾸기)을 한 번 제안한다.
    func subscriptionGraduationPrompt() -> some View {
        modifier(SubscriptionGraduationPrompt())
    }
}
