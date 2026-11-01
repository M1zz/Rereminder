//
//  DSColor.swift
//  Rereminder
//
//  디자인 시스템 - 시맨틱 컬러 토큰
//  Xcode 자동 생성 에셋 심볼(Color.plain 등)에 직접 의존하지 않고
//  이 토큰을 통해 색을 참조한다. (자동 심볼은 iOS 타겟에만 존재하므로
//  문자열 조회로 워치/위젯 타겟에서도 동작하게 한다.)
//

import SwiftUI

enum DSColor {

    // MARK: - 브랜드 / 기본

    /// 앱 키 컬러 (테마에서 주입된 tint)
    static let accent = Color.accentColor

    // MARK: - 에셋 카탈로그 시맨틱 컬러
    // (각 타겟의 .xcassets 에 동일한 이름으로 존재해야 한다)

    /// 중립 회색 (트랙, 비활성 요소)
    static let plain = Color("PlainColor")
    /// 긍정/시작 (붉은 핑크 계열 — 앱 액센트 톤)
    static let positive = Color("positiveColor")
    /// 부정/취소 (진한 빨강)
    static let negative = Color("NegativeColor")
    /// 약한 경고 (옅은 주황)
    static let negativeSoft = Color("BitNegativeColor")

    // MARK: - 타이머 상태 색
    // 색약 사용자를 위해 항상 형태/아이콘 단서와 함께 사용한다.
    // (StatusIndicator, PresentationDisplayView 참고)

    static let stateIdle = Color.yellow
    static let stateRunning = Color.green
    static let statePaused = Color.orange
    static let stateFinished = Color.blue
    static let stateOvertime = Color.red

    // MARK: - 시계 사전 알림 마커

    /// 사전 알림 마커 색 (선명한 주황)
    static let marker = Color(red: 1.0, green: 0.6, blue: 0.0)
}

// MARK: - 다이얼 손잡이의 입체감

extension View {
    /// 흰 핸들·종 노브처럼 **손으로 잡는 원**에만 쓴다. 링과 숫자는 평평해야 구간 색과 시간이 읽힌다.
    /// 빛은 늘 위에서 온다 — 링을 따라 회전하는 뷰는 역회전한 안쪽에서 적용할 것.
    func raisedKnob(isHeld: Bool = false) -> some View {
        overlay {
            Circle().fill(LinearGradient(colors: [.white.opacity(0.3), .clear, .black.opacity(0.14)],
                                         startPoint: .top, endPoint: .bottom))
        }
        .shadow(color: .black.opacity(isHeld ? 0.4 : 0.3),
                radius: isHeld ? 6 : 3,
                y: isHeld ? 3 : 1.5)
        .animation(.easeOut(duration: 0.15), value: isHeld)
    }
}
