//
//  WatchScreenshotScene.swift
//  Rereminder Watch App
//
//  워치 앱스토어 스크린샷용 장면 — **DEBUG 빌드에서만** 존재한다.
//  iPhone 의 `ScreenshotScene` 과 같은 생각이다: 언어 10개를 손으로 맞춰 찍으면 다시 찍을 수 없다.
//
//      xcrun simctl launch <워치> com.xa.toki.watchkitapp -screenshotScene prealerts -AppleLanguages "(de)"
//
//  장면이 걸리면 알림 권한을 요청하지 않는다 — 권한 창도, 끝났을 때의 배너도 화면을 가린다.
//  찍는 스크립트: `scripts/capture_watch_screenshots.sh`
//

#if DEBUG
import Foundation

enum WatchScreenshotScene: String {
    /// 시간 설정 다이얼 (30분)
    case duration
    /// 예비 알림 1·3·10분을 고른 화면
    case prealerts
    /// 30분 타이머가 도는 중 — 구간 4개
    case running
    /// 끝나고 확인을 기다리는 화면
    case finished

    static var current: WatchScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(WatchScreenshotScene.init(rawValue:))
    }

    static var isActive: Bool { current != nil }

    /// 예비 알림 화면에 미리 골라 둘 분.
    static let prealertMinutes: Set<Int> = [1, 3, 10]

    /// 장면이 요구하는 첫 화면. `nil` 이면 시간 설정 화면 그대로.
    var initialPath: [NavigationTarget] {
        switch self {
        case .duration:
            return []
        case .prealerts:
            return [.setNotiView]
        case .running:
            return [.timerViewMultiple(mainDuration: 1800,
                                       prealertOffsets: Self.prealertMinutes.map { $0 * 60 })]
        case .finished:
            // 4초짜리 — 가운데(2초 전)에 알림 점이 하나 찍힌 채로 끝난다.
            return [.timerViewMultiple(mainDuration: 4, prealertOffsets: [2])]
        }
    }
}
#endif
