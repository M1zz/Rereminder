//
//  RereminderTimerData.swift
//  Rereminder
//
//  Timer metadata for AlarmKit
//

import Foundation

#if canImport(AlarmKit) && !targetEnvironment(macCatalyst)
import AlarmKit

struct RereminderTimerData: AlarmMetadata {
    let createdAt: Date
    let timerName: String?

    init(timerName: String? = nil) {
        self.createdAt = Date.now
        self.timerName = timerName
    }
}
#endif
