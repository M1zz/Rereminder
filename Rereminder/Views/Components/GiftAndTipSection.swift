//
//  GiftAndTipSection.swift
//  Rereminder
//
//  설정 ▸ 요금제와 응원 칸의 **응원 · 선물** 두 줄. 요금제 줄 바로 아래에 선다(클립키보드와 같다).
//
//  - 응원(팁): 이미 다 가진 사람이 조금 더 내고 싶을 때. 아무것도 열지 않는다. 응원한 사람에게는 지금 단계(배지).
//  - 선물하기: 누르면 바로 등급(기억 · Pro)을 고르고 선물하는 화면(`SettingsGiftView`).
//
//  ⚠️ 이 뷰는 바깥 `Section` 안에 들어간다. 여기서 `Section` 을 또 만들지 않는다(겹친 칸이 된다).
//  ⚠️ 상품이 App Store 에서 와야 줄이 선다(`isAvailable`). App Store Connect 에 상품을 만들기 전에
//     이 빌드가 나가도 빈 줄이나 눌러도 안 되는 줄은 보이지 않는다.
//  ⚠️ 문구는 LeeoKit 카탈로그에 있다(`LeeoTipText` · `LeeoGiftText`) — 앱 카탈로그에 다시 적지 않는다.
//

import SwiftUI
import LeeoKit

struct GiftAndTipSection: View {
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        if let tipJar = store.tipJar {
            TipRow(tipJar: tipJar)
        }
        if SettingsGiftView.hasContent(store) {
            NavigationLink {
                SettingsGiftView()
            } label: {
                Label(String(localized: "Send a Gift"), systemImage: "gift.fill")
            }
        }
    }
}

/// 엔진(`LeeoTipJar`)은 따로 관찰해야 한다. 상품은 앱이 뜬 뒤에 오는데 `StoreManager` 는 그 변화를 알리지 않는다.
private struct TipRow: View {
    @ObservedObject var tipJar: LeeoTipJar

    var body: some View {
        if tipJar.isAvailable {
            NavigationLink {
                LeeoTipJarView<RereminderSpec>(tipJar: tipJar)
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LeeoTipText.entry)
                        Text(LeeoTipText.entrySubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LeeoSupporterBadge(tipJar: tipJar)
                            .padding(.top, 4)
                    }
                } icon: {
                    Image(systemName: "heart.fill")
                }
            }
        }
    }
}

/// 설정 ▸ 선물하기. 누르면 바로 등급(기억 · Pro)을 고르고 선물하는 한 화면이다(LeeoKit `LeeoGiftPickerView`).
/// 받은 코드 넣기는 그 화면 맨 아래 링크로 둔다. 선물을 사면 App Store 오퍼 코드 링크가 나오고,
/// 받은 사람은 App Store 에서 "사용" 한 번으로 열린다 — 여는 것은 우리 코드가 아니라 App Store 다(지침 3.1.1).
struct SettingsGiftView: View {
    @ObservedObject private var store = StoreManager.shared
    /// 선물이 안 될 때의 문의 창(결제 번호 · 코드가 붙는다).
    @State private var showSupport = false

    /// 보낼 수 있는 선물, 싼 것(기억)부터. 상품이 App Store 에서 왔거나 이미 보낸 · 준비 중인 결제가 있으면 선다.
    private static func senders(_ store: StoreManager) -> [LeeoGiftStore] {
        store.gifts.filter { $0.isAvailable || $0.pendingCount > 0 || !$0.sentGifts.isEmpty }.reversed()
    }

    /// 받기 링크는 아직 Pro 가 아닌 사람에게만. 링크 없이 코드만 받은 사람을 위한 자리다.
    private static func showsRedeem(_ store: StoreManager) -> Bool {
        (store.gifts.first?.canRedeem ?? false) && !store.isPro
    }

    /// 설정에 선물 줄을 세울지. 보낼 선물이 있을 때만 — 받기는 페이월 · 더 보기의 코드 사용 줄이 이미 맡는다.
    static func hasContent(_ store: StoreManager) -> Bool {
        !senders(store).isEmpty
    }

    var body: some View {
        LeeoGiftPickerView<RereminderSpec>(gifts: Self.senders(store),
                                           showsRedeemLink: Self.showsRedeem(store),
                                           onContactSupport: { showSupport = true })
            .sheet(isPresented: $showSupport) {
                LeeoFeedbackView<RereminderSpec>(initialType: .bug,
                                                 extraInfo: store.gifts.flatMap(\.supportLines),
                                                 initialCategory: .purchase)
            }
    }
}
