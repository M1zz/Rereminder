//
//  TimerRecord.swift
//  Rereminder
//
//  Created by POS on 8/24/25.
//

import Foundation
import SwiftData

@Model
final class TimerRecord {
    // CloudKit 동기화 규칙(→ Timer.swift): 기본값을 두고 `.unique` 는 쓰지 않는다.
    var id: UUID = UUID()
    var date: Date = Date.now
    var finished: Bool = false
    var elapsedSeconds: Int = 0

    // timer templete Save할 수 있게 값 snapshot
    var snapshotMainSeconds: Int = 0
    var snapshotPrealertOffsetsSec: [Int] = []
    var isPresentation: Bool = false

    var template: Timer?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        finished: Bool,
        elapsedSeconds: Int,
        snapshotMainSeconds: Int,
        snapshotPrealertOffsetsSec: [Int],
        isPresentation: Bool = false,
        template: Timer?
    ) {
        self.id = id
        self.date = date
        self.finished = finished
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.snapshotMainSeconds = snapshotMainSeconds
        self.snapshotPrealertOffsetsSec = snapshotPrealertOffsetsSec.sorted()
        self.isPresentation = isPresentation
        self.template = template
    }
}
