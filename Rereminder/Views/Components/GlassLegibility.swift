//
//  GlassLegibility.swift
//  Rereminder
//
//  visionOS 의 창은 반투명 유리다. 아이폰에서 읽히던 것 둘이 그 위에서는 읽히지 않는다(2.3.9 심사 거절, Guideline 4):
//  ① 구간 색(파랑·초록·보라…) 글자 — 유리 뒤가 밝으면 대비가 무너진다. 보라 "1분"은 거의 보이지 않았다.
//  ② 불투명한 회색 카드(`systemGray6`) — 유리 위에 검은 판으로 뜨고 그 안의 회색 글자가 흐리다.
//
//  그래서 **글자에 쓰는 색**과 **카드 바탕**만 여기서 갈아 끼운다. 링·종·점처럼 채운 도형은 구간 색 그대로다.
//  아이폰·아이패드·맥에서는 아무것도 바뀌지 않는다.
//

import SwiftUI

extension Color {
    /// 유리 위에 **글자·작은 심볼**로 쓸 때의 색. visionOS 에서는 흰색을 섞어 밝기를 올린다
    /// (어느 구간인지는 색조로 남고, 읽히는 것은 밝기가 맡는다). 다른 기기에서는 그대로다.
    var onGlass: Color {
        #if os(visionOS)
        mix(with: .white, by: 0.6)
        #else
        self
        #endif
    }

    /// 카드 바탕(구간 카드·대본 패널). visionOS 에서는 유리를 한 겹 어둡게 눌러 흰 글자가 선다.
    static var dsCard: Color {
        #if os(visionOS)
        Color.black.opacity(0.3)
        #else
        Color(.systemGray6)
        #endif
    }

    /// 한 단계 옅은 바탕(선택지·표 머리).
    static var dsCardSecondary: Color {
        #if os(visionOS)
        Color.black.opacity(0.22)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
