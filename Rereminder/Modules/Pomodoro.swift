//
//  Pomodoro.swift
//  Rereminder
//
//  **포모도로** — 집중 25분 + 휴식 5분을 네 번. 제보(2026-11-25): "While coding" 한 줄.
//
//  새 장치가 아니다. 구간 목록(`IntervalList`) 두 줄 + 반복(`RoundSchedule`) 4회를 한 번에 채우는 이름일 뿐이다.
//  링은 한 회(30분)를 그리고, 집중이 끝나는 자리(끝나기 5분 전)에 종이 하나 선다.
//  ⚠️ 따로 저장하지 않는다 — 다이얼에 올린 뒤는 여느 설정과 같다(🔖 로 저장, 종 옮기기).
//

import Foundation

enum Pomodoro {
    static let focusSeconds = 25 * 60
    static let breakSeconds = 5 * 60
    static let rounds = 4

    /// 구간 목록에 적히는 모양 — 집중, 휴식
    static let lengths = [focusSeconds, breakSeconds]

    /// 메뉴 막대가 이 항목을 고를 때 쓰는 이름표. 저장한 설정의 id(UUID)와 겹치지 않는다.
    static let menuID = "pomodoro"

    /// 고르는 자리에 붙는 짧은 모양. 숫자뿐이라 번역하지 않는다.
    static var shapeText: String {
        "\(TimeMapper.clockText(focusSeconds)) + \(TimeMapper.clockText(breakSeconds)) × \(rounds)"
    }
}
