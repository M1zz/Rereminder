//
//  TrialCounter.swift
//  Rereminder
//
//  Pro 기능별 무료 체험 카운터
//  5+5 분할 페이월 모델:
//  - 0~4회: 자유롭게 사용 (1차 카운터)
//  - 5회 도달: 1차 페이월 — "5번 더 체험" 또는 결제
//  - 5번 더 수락 시 5~9회: 자유롭게 사용 (2차 카운터)
//  - 10회 도달: 2차 페이월 — 결제 only
//

import Foundation

enum TrialCounter {

    static let firstStageLimit = 5
    static let secondStageLimit = 10

    /// 테스트 시 격리된 UserDefaults 주입을 위해 var 로 둠. 프로덕션에서는 변경하지 않음.
    static var defaults: UserDefaults = .standard

    // MARK: - Key

    private static func countKey(_ feature: ProGate.Feature) -> String {
        "trial.count.\(feature.rawValue)"
    }

    private static func extensionKey(_ feature: ProGate.Feature) -> String {
        "trial.extension.\(feature.rawValue)"
    }

    // MARK: - Count

    static func count(for feature: ProGate.Feature) -> Int {
        defaults.integer(forKey: countKey(feature))
    }

    static func increment(_ feature: ProGate.Feature) {
        let current = count(for: feature)
        defaults.set(current + 1, forKey: countKey(feature))
    }

    // MARK: - Extension (사용자가 1차 페이월에서 "5번 더" 수락했는지)

    static func extensionAccepted(for feature: ProGate.Feature) -> Bool {
        defaults.bool(forKey: extensionKey(feature))
    }

    static func acceptExtension(for feature: ProGate.Feature) {
        defaults.set(true, forKey: extensionKey(feature))
    }

    // MARK: - Reset (디버그/테스트용)

    static func reset(_ feature: ProGate.Feature) {
        defaults.removeObject(forKey: countKey(feature))
        defaults.removeObject(forKey: extensionKey(feature))
    }

    static func resetAll() {
        for feature in ProGate.Feature.allCases {
            reset(feature)
        }
    }
}
