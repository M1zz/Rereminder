//
//  DSSpacing.swift
//  Rereminder
//
//  디자인 시스템 - 여백(spacing) 스케일
//  파일·화면마다 흩어진 매직넘버를 하나의 스케일로 통일한다.
//

import CoreGraphics

enum DSSpacing {
    /// 2pt — 아주 촘촘한 요소 간격
    static let xxs: CGFloat = 2
    /// 4pt
    static let xs: CGFloat = 4
    /// 8pt
    static let sm: CGFloat = 8
    /// 12pt
    static let md: CGFloat = 12
    /// 16pt — 기본 콘텐츠 좌우 여백
    static let lg: CGFloat = 16
    /// 20pt — 화면 가장자리 여백
    static let xl: CGFloat = 20
    /// 24pt
    static let xxl: CGFloat = 24
    /// 32pt — 섹션 간 큰 간격
    static let xxxl: CGFloat = 32
}
