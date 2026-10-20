//
//  GiftAndTipSection.swift
//  Rereminder
//
//  설정의 **선물·응원** 줄. Pro 칸 바로 아래에 선다.
//
//  - 선물: Pro 를 다른 사람에게 보낸다(보내는 사람은 소모성 선물 상품을 산다). 받은 코드는 여기서 넣는다.
//    받는 사람은 `com.xa.toki.pro` 를 산 것과 같아진다(`RereminderSpec.giftConfig`).
//  - 응원(팁): 이미 다 가진 사람이 조금 더 내고 싶을 때. 아무것도 열지 않는다.
//
//  ⚠️ 상품이 App Store 에서 와야 줄이 선다(`isAvailable`). App Store Connect 에 상품을 만들기 전에
//     이 빌드가 나가도 빈 줄이나 눌러도 안 되는 줄은 보이지 않는다.
//     단, 이미 결제했거나 주고받은 선물이 있는 사람에게는 선물 줄이 늘 보인다 — 상품을 못 불러온 날에도
//     그 사람이 코드를 다시 보거나 문의까지 갈 길이 있어야 한다.
//  ⚠️ 문구는 LeeoKit 카탈로그에 있다(`LeeoGiftText`, `LeeoTipText`) — 24개 언어가 이미 들어 있다.
//  ⚠️ 엔진(`LeeoGiftStore`·`LeeoTipJar`)은 따로 관찰해야 한다. 상품은 앱이 뜬 뒤에 오는데
//     `StoreManager` 는 그 변화를 알리지 않는다.
//

import SwiftUI
import LeeoKit

struct GiftAndTipSection: View {
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        if let gift = store.gift {
            GiftRows(gift: gift, isPro: store.isPro)
        }
        if let tipJar = store.tipJar {
            TipRow(tipJar: tipJar)
        }
    }
}

private struct GiftRows: View {
    @ObservedObject var gift: LeeoGiftStore
    let isPro: Bool
    @State private var showSupport = false

    var body: some View {
        if gift.isAvailable || gift.pendingCount > 0 || !gift.sentGifts.isEmpty || gift.redeemed != nil {
            Section {
                NavigationLink {
                    // 선물이 안 되면 결제 번호·코드를 붙여 문의하게 한다 — 막힌 사람을 놓치지 않게.
                    LeeoGiftView<RereminderSpec>(gift: gift, showsRedeemLink: false,
                                                 onContactSupport: { showSupport = true })
                } label: {
                    Label(LeeoGiftText.sendEntry, systemImage: "gift.fill")
                }
                // 이미 Pro 인 사람은 받을 것이 없다 — 받은 적이 있으면 그 기록을 볼 수 있게만 남긴다.
                if !isPro || gift.redeemed != nil {
                    NavigationLink {
                        LeeoGiftRedeemView<RereminderSpec>(gift: gift,
                                                           onContactSupport: { showSupport = true })
                    } label: {
                        Label(LeeoGiftText.redeemEntry, systemImage: "giftcard")
                    }
                }
            }
            .sheet(isPresented: $showSupport) {
                FeedbackView()
            }
        }
    }
}

private struct TipRow: View {
    @ObservedObject var tipJar: LeeoTipJar

    var body: some View {
        if tipJar.isAvailable {
            Section {
                NavigationLink {
                    LeeoTipJarView<RereminderSpec>(tipJar: tipJar)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LeeoTipText.entry)
                            Text(LeeoTipText.entrySubtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "heart.fill")
                    }
                }
            }
        }
    }
}
