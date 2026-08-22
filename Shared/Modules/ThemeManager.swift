//
//  ThemeManager.swift
//  Rereminder
//
//  앱 전체 키 컬러(액센트) 테마 관리
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    // MARK: - Theme Presets

    struct Theme: Identifiable, Equatable {
        let id: String
        let name: String
        let color: Color
        let hex: String

        static let presets: [Theme] = [
            Theme(id: "blue", name: "Ocean", color: Color(hex: "007AFF"), hex: "007AFF"),
            Theme(id: "indigo", name: "Indigo", color: Color(hex: "5856D6"), hex: "5856D6"),
            Theme(id: "purple", name: "Violet", color: Color(hex: "AF52DE"), hex: "AF52DE"),
            Theme(id: "pink", name: "Rose", color: Color(hex: "FF2D55"), hex: "FF2D55"),
            Theme(id: "red", name: "Coral", color: Color(hex: "FF3B30"), hex: "FF3B30"),
            Theme(id: "orange", name: "Sunset", color: Color(hex: "FF9500"), hex: "FF9500"),
            Theme(id: "yellow", name: "Gold", color: Color(hex: "FFCC00"), hex: "FFCC00"),
            Theme(id: "green", name: "Mint", color: Color(hex: "34C759"), hex: "34C759"),
            Theme(id: "teal", name: "Teal", color: Color(hex: "5AC8FA"), hex: "5AC8FA"),
            Theme(id: "white", name: "Mono", color: Color(hex: "E5E5EA"), hex: "E5E5EA"),
        ]

    }

    // MARK: - State

    @Published var currentTheme: Theme {
        didSet {
            UserDefaults.standard.set(currentTheme.id, forKey: "selectedThemeID")
            // 위젯·Live Activity 가 같은 색을 쓰도록 앱 그룹에도 한 벌 적어 둔다 —
            // 확장은 `UserDefaults.standard` 를 읽지 못한다(자기 컨테이너를 본다).
            SharedAccent.write(hex: currentTheme.hex)
        }
    }

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    var accentColor: Color { currentTheme.color }
    var colorScheme: ColorScheme? { appearanceMode.colorScheme }

    // MARK: - Init

    private init() {
        let savedID = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "blue"
        currentTheme = Theme.presets.first { $0.id == savedID } ?? Theme.presets[0]
        let savedMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "dark"
        appearanceMode = AppearanceMode(rawValue: savedMode) ?? .dark
        // ⚠️ init 에서는 didSet 이 돌지 않는다 — 여기서 한 번 써 주지 않으면 테마를 바꾸기 전까지
        //    확장은 기본색만 보게 된다(업데이트 직후 라이브 액티비티가 혼자 파란색으로 남는다).
        SharedAccent.write(hex: currentTheme.hex)
    }

    // MARK: - Theme Selection

    func select(_ theme: Theme) {
        currentTheme = theme
        #if canImport(UIKit)
        Self.applyTintColor(hex: theme.hex)
        #endif
    }

    /// 앱 시작 시 UIKit tintColor를 즉시 설정하여 SwiftUI .tint() 적용 전 깜빡임 방지
    static func applyInitialTint() {
        #if canImport(UIKit)
        let savedID = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "blue"
        let hex = Theme.presets.first { $0.id == savedID }?.hex ?? "007AFF"
        applyTintColor(hex: hex)
        #endif
    }

    #if canImport(UIKit)
    private static func applyTintColor(hex: String) {
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        UIView.appearance().tintColor = UIColor(red: r, green: g, blue: b, alpha: 1)
    }
    #endif

}
