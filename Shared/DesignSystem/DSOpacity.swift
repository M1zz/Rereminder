//
//  DSOpacity.swift
//  Rereminder
//
//  디자인 시스템 - 반복적으로 쓰이는 투명도 값 명명
//

import Foundation

enum DSOpacity {
    /// 0.1 — 아주 옅은 배경 강조
    static let faint: Double = 0.1
    /// 0.12 — 비선택 상태 배경
    static let subtle: Double = 0.12
    /// 0.3 — 깜빡임 최저 밝기
    static let dim: Double = 0.3
    /// 0.4 — 비활성(disabled)
    static let disabled: Double = 0.4
    /// 0.5 — 트랙/가이드 라인
    static let track: Double = 0.5
    /// 0.9 — 강한 오버레이 배경
    static let strong: Double = 0.9
}
