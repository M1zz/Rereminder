//
//  DSFont.swift
//  Rereminder
//
//  디자인 시스템 - 폰트 토큰
//  1) 텍스트 스타일 토큰: 빌트인 Dynamic Type 스타일에 매핑 → 시스템 글자 크기에 자동 대응
//  2) 디스플레이 토큰: 큰 숫자(카운트다운 등)는 @ScaledMetric 으로 스케일하되 상한 캡으로
//     레이아웃 오버플로를 방지한다.
//

import SwiftUI

// MARK: - 텍스트 스타일 토큰 (자동 스케일)

enum DSFont {
    /// 화면 대표 제목
    static let titleLarge = Font.largeTitle.weight(.bold)
    /// 섹션 제목
    static let title = Font.title2.weight(.bold)
    /// 소제목 / 강조 헤더
    static let sectionHeader = Font.headline
    /// 본문
    static let body = Font.body
    /// 보조 본문
    static let callout = Font.callout
    /// 캡션
    static let caption = Font.caption
    /// 작은 캡션
    static let caption2 = Font.caption2

    /// 타이머 시간 표시용 (둥근 디자인 + 고정폭 숫자). 텍스트 스타일 기준으로 스케일.
    static func timer(_ style: Font.TextStyle = .largeTitle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded).weight(weight).monospacedDigit()
    }
}

// MARK: - 디스플레이 폰트 (스케일 + 상한 캡)

private struct DSScaledFont: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design
    private let maxSize: CGFloat?

    init(
        base: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        relativeTo: Font.TextStyle,
        maxSize: CGFloat?
    ) {
        _scaledSize = ScaledMetric(wrappedValue: base, relativeTo: relativeTo)
        self.weight = weight
        self.design = design
        self.maxSize = maxSize
    }

    private var resolvedSize: CGFloat {
        guard let maxSize else { return scaledSize }
        return min(scaledSize, maxSize)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: resolvedSize, weight: weight, design: design))
    }
}

extension View {
    /// 큰 디스플레이 숫자/아이콘용 스케일 폰트.
    /// `base`(기본 크기)를 Dynamic Type 비율로 키우되 `maxSize`로 상한을 둔다.
    /// `.minimumScaleFactor` 와 함께 쓰면 좁은 영역에서도 안전하다.
    func dsScaledFont(
        _ base: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo: Font.TextStyle = .largeTitle,
        maxSize: CGFloat? = nil
    ) -> some View {
        modifier(DSScaledFont(
            base: base,
            weight: weight,
            design: design,
            relativeTo: relativeTo,
            maxSize: maxSize
        ))
    }
}
