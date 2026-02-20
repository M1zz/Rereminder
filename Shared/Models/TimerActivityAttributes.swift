//
//  TimerActivityAttributes.swift
//  Rereminder
//
//  ActivityKit 기반 Timer Live Activity
//

import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var isPaused: Bool
        var timestamp: Date
        var endDate: Date?  // Timer Finished 시각 (자동 카운트다운용)
    }

    var timerName: String
    var totalDuration: TimeInterval
    var startTime: Date
}
#endif
