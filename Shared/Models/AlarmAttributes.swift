//
//  AlarmAttributes.swift
//  Toki
//
//  AlarmKit data models for Live Activity
//

import Foundation

#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

// MARK: - Alarm Attributes

struct AlarmAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var mode: AlarmMode
        var alarmID: UUID
    }

    var presentation: AlarmPresentation
    var tintColor: String  // Hex color string
}

// MARK: - Alarm Mode

enum AlarmMode: Codable, Hashable {
    case countdown(CountdownState)
    case paused(PausedState)
    case alert

    struct CountdownState: Codable, Hashable {
        var fireDate: Date
        var totalDuration: TimeInterval
    }

    struct PausedState: Codable, Hashable {
        var totalCountdownDuration: TimeInterval
        var previouslyElapsedDuration: TimeInterval
    }
}

// MARK: - Alarm Presentation

struct AlarmPresentation: Codable, Hashable {
    var countdown: CountdownPresentation?
    var paused: PausedPresentation?
    var alert: AlertPresentation
}

struct CountdownPresentation: Codable, Hashable {
    var title: String
    var pauseButton: AlarmButton
}

struct PausedPresentation: Codable, Hashable {
    var title: String
    var resumeButton: AlarmButton
}

struct AlertPresentation: Codable, Hashable {
    var title: String
    var stopButton: AlarmButton
}

struct AlarmButton: Codable, Hashable {
    var text: String
    var systemImageName: String
}

#endif
