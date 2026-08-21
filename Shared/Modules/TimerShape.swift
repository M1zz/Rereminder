//
//  TimerShape.swift
//  Rereminder
//
//  **타이머가 도는 동안 어떤 모양으로 보일지** — 설정 > 타이머 모양에서 고른다.
//
//  왜 고르게 하나: 같은 타이머라도 사람마다 알고 싶은 게 다르다. 전체가 얼마 남았나(원),
//  지금 구간이 얼마 남았나(이중 링), 이 구간이 전체에서 얼마나 큰 덩어리인가(막대),
//  긴 타이머를 좁은 화면에(접은 줄). 어느 하나가 늘 옳지 않아서 고르게 둔다.
//
//  규칙 둘
//   1. **한 번에 하나만 보여준다.** 원 + 막대를 같이 세우면 같은 시간을 두 번 그리는 셈이고,
//      눈은 어느 쪽을 봐야 할지 매번 고르게 된다.
//   2. **대기 중(시간·알림을 정할 때)에는 언제나 다이얼(원)이다.** 흰 핸들과 종 노브를 끌어
//      시간을 정하는 조작이 원에 묶여 있어서, 모양 선택은 **실행 중 표시**에만 적용한다.
//

import Foundation

enum TimerShape: String, CaseIterable, Identifiable {
    /// 원형 링 하나 — 전체가 얼마 남았나.
    case ring
    /// 원형 링 + 안쪽에 지금 구간 링 (기본값, 2.1.2 이전의 동작).
    case dualRing
    /// 완전 선형 구간 막대 — 구간끼리의 크기 비교가 가장 잘 되는 형태.
    case bar
    /// ㄹ자로 접은 줄 — 선의 장점을 지키면서 가로 폭을 접는다. 긴 타이머용.
    case snake

    var id: String { rawValue }

    /// `@AppStorage` 키. ⚠️ 리터럴만 받는 곳이 있어 문자열을 그대로 쓰는 자리가 있다 —
    /// 바꾸면 `TimerMainView`·`TimerShapeSettingView` 의 리터럴도 같이 고칠 것.
    static let storageKey = "timer.shape"
    static let fallback = TimerShape.dualRing

    static func resolve(_ rawValue: String) -> TimerShape {
        TimerShape(rawValue: rawValue) ?? fallback
    }

    var displayName: String {
        switch self {
        case .ring:     return String(localized: "Ring")
        case .dualRing: return String(localized: "Double Ring")
        case .bar:      return String(localized: "Section Bar")
        case .snake:    return String(localized: "Folded Line")
        }
    }

    /// 이 모양이 무엇을 잘 답하는지 — 이름만으로는 고를 수 없다.
    var detail: String {
        switch self {
        case .ring:     return String(localized: "Shows how much of the whole timer is left.")
        case .dualRing: return String(localized: "Outer ring is the whole timer, inner ring is the section you are in.")
        case .bar:      return String(localized: "Compares section sizes as lengths on one line.")
        case .snake:    return String(localized: "Folds that line into rows, so a long timer fits a narrow screen.")
        }
    }

    /// 다이얼(원)을 쓰는 모양인가 — 실행 중에 원을 그릴지 다른 형태를 그릴지 가른다.
    var usesDial: Bool { self == .ring || self == .dualRing }

    /// 원 안쪽에 "이 구간" 링을 한 겹 더 그리는가.
    var showsSectionRing: Bool { self == .dualRing }
}
