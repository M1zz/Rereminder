//
//  ThemeManager.swift
//  Toki
//
//  앱 전체 키 컬러(액센트) 테마 관리
//

import SwiftUI

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
            Theme(id: "blue",    name: "Ocean",    color: Color(hex: "007AFF"), hex: "007AFF"),
            Theme(id: "indigo",  name: "Indigo",   color: Color(hex: "5856D6"), hex: "5856D6"),
            Theme(id: "purple",  name: "Violet",   color: Color(hex: "AF52DE"), hex: "AF52DE"),
            Theme(id: "pink",    name: "Rose",     color: Color(hex: "FF2D55"), hex: "FF2D55"),
            Theme(id: "red",     name: "Coral",    color: Color(hex: "FF3B30"), hex: "FF3B30"),
            Theme(id: "orange",  name: "Sunset",   color: Color(hex: "FF9500"), hex: "FF9500"),
            Theme(id: "yellow",  name: "Gold",     color: Color(hex: "FFCC00"), hex: "FFCC00"),
            Theme(id: "green",   name: "Mint",     color: Color(hex: "34C759"), hex: "34C759"),
            Theme(id: "teal",    name: "Teal",     color: Color(hex: "5AC8FA"), hex: "5AC8FA"),
            Theme(id: "white",   name: "Mono",     color: Color(hex: "E5E5EA"), hex: "E5E5EA"),
        ]

        /// 무료로 사용 가능한 테마 (첫 3개)
        static let freeIDs: Set<String> = ["blue", "indigo", "green"]
    }

    // MARK: - State

    @Published var currentTheme: Theme {
        didSet {
            UserDefaults.standard.set(currentTheme.id, forKey: "selectedThemeID")
        }
    }

    var accentColor: Color { currentTheme.color }

    // MARK: - Init

    private init() {
        let savedID = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "blue"
        currentTheme = Theme.presets.first { $0.id == savedID } ?? Theme.presets[0]
    }

    // MARK: - Theme Selection

    func select(_ theme: Theme) {
        currentTheme = theme
    }

    func isLocked(_ theme: Theme) -> Bool {
        !StoreManager.isProUser && !Theme.freeIDs.contains(theme.id)
    }
}

// MARK: - Color hex init

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
