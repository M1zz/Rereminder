//
//  TimerRecord.swift
//  Toki
//
//  Created by POS on 8/24/25.
//

import Foundation
import SwiftData

@Model
final class TimerRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var finished: Bool
    var elapsedSeconds: Int

    // timer templete Save할 수 있게 값 snapshot
    var snapshotMainSeconds: Int
    var snapshotPrealertOffsetsSec: [Int]

    var template: Timer?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        finished: Bool,
        elapsedSeconds: Int,
        snapshotMainSeconds: Int,
        snapshotPrealertOffsetsSec: [Int],
        template: Timer?
    ) {
        self.id = id
        self.date = date
        self.finished = finished
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.snapshotMainSeconds = snapshotMainSeconds
        self.snapshotPrealertOffsetsSec = snapshotPrealertOffsetsSec.sorted()
        self.template = template
    }
}
