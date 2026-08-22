//
//  SharedAccent.swift
//  Rereminder
//
//  **앱이 고른 강조색을 위젯·Live Activity 도 쓰게 하는 통로.**
//
//  ⚠️ 테마는 `UserDefaults.standard` 에 저장되는데, 확장은 자기 컨테이너를 보므로 그 값을
//     **읽을 수 없다.** 그래서 앱이 테마를 바꿀 때마다 앱 그룹에 hex 를 한 벌 적어 두고,
//     확장은 여기서만 읽는다. 이게 없으면 잠금화면 라이브 액티비티만 혼자 다른 색으로 논다.
//
//  ⚠️ 앱과 위젯 확장 양쪽에서 컴파일된다 — 무거운 의존을 끌어들이지 말 것
//     (`ThemeManager` 는 확장 타겟에 없다. 그래서 이 파일이 따로 있는 것이다).
//

import SwiftUI

enum SharedAccent {

    private static let suiteName = "group.leeo.toki"
    private static let hexKey = "theme.accentHex"

    /// 기본 테마(Ocean)의 hex — 아직 아무것도 적히지 않았을 때(첫 실행·업데이트 직후) 쓴다.
    static let fallbackHex = "007AFF"

    private static var store: UserDefaults? { UserDefaults(suiteName: suiteName) }

    /// 앱이 테마를 바꿀 때마다 부른다.
    static func write(hex: String) {
        store?.set(hex, forKey: hexKey)
    }

    static var hex: String {
        store?.string(forKey: hexKey) ?? fallbackHex
    }

    /// 확장에서 쓰는 강조색.
    static var color: Color { Color(hex: hex) }
}

// MARK: - Color hex init
//
// `ThemeManager` 안에 있던 것을 여기로 옮겼다 — 확장에도 필요한데 ThemeManager 는 확장 타겟에 없다.

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 122, 255)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
