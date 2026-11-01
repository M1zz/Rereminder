//
//  GiftAndTipSection.swift
//  Rereminder
//
//  설정의 **응원** 줄. Pro 칸 바로 아래에 선다.
//
//  - 응원(팁): 이미 다 가진 사람이 조금 더 내고 싶을 때. 아무것도 열지 않는다.
//
//  ⚠️ 상품이 App Store 에서 와야 줄이 선다(`isAvailable`). App Store Connect 에 상품을 만들기 전에
//     이 빌드가 나가도 빈 줄이나 눌러도 안 되는 줄은 보이지 않는다.
//  ⚠️ 문구는 LeeoKit 카탈로그에 있다(`LeeoTipText`) — 24개 언어가 이미 들어 있다.
//  ⚠️ 엔진(`LeeoTipJar`)은 따로 관찰해야 한다. 상품은 앱이 뜬 뒤에 오는데
//     `StoreManager` 는 그 변화를 알리지 않는다.
//

import SwiftUI
import LeeoKit

struct GiftAndTipSection: View {
    @ObservedObject private var store = StoreManager.shared

    var body: some View {
        if let tipJar = store.tipJar {
            TipRow(tipJar: tipJar)
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
