//
//  TimerActivityAttributes.swift
//  Toki
//
//  ActivityKit 기반 타이머 Live Activity
//

import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var isPaused: Bool
        var timestamp: Date
    }

    var timerName: String
    var totalDuration: TimeInterval
    var startTime: Date
}
#endif
