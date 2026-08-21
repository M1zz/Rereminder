//
//  SectionPalette.swift
//  Rereminder
//
//  구간(알림으로 나뉜 구간) 색 규칙 — **한 구간은 어디서나 같은 색**이어야 한다.
//  링의 호, 구간 리스트의 점·테두리, 진행 중 가운데 표시가 모두 이 색을 본다.
//  색이 갈라지면 "이 카드가 저 호"라는 연결이 끊긴다.
//

import SwiftUI

enum SectionPalette {
    /// 주황(DSColor.marker)은 알림 마커 전용이라 팔레트에서 뺀다 — 종과 구간이 같은 색이면 헷갈린다.
    private static let colors: [Color] = [.blue, .green, .purple, .teal, .pink, .indigo]

    /// 구간 인덱스(경과 순서, 0부터) → 색. 구간이 팔레트보다 많으면 처음부터 다시 쓴다.
    static func color(_ index: Int) -> Color {
        colors[abs(index) % colors.count]
    }
}
