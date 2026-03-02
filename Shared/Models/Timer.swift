//
//  Timer.swift
//  Rereminder
//
//  Created by POS on 8/24/25.
//

import Foundation
import SwiftData

@Model
final class Timer {
    @Attribute(.unique) var id: UUID
    var name: String
    var mainSeconds: Int  // main timer time
    var prealertOffsetsSec: [Int]  // prealert offset time from mainSeconds
    var prealertMessages: [Int: String] = [:]  // 각 Pre-alerts의 커스텀 메시지 (오프셋 sec: 메시지)
    var finishMessage: String?  // 종료 알림 커스텀 메시지 (nil이면 기본 메시지)
    var label: String = ""  // Label (예: "Presentation", "Mentoring", "Meeting")
    var colorHex: String = "#007AFF"  // Label Color (기본: 파란색)
    var isFavorite: Bool = false  // 즐겨찾기 여부
    var isPresentation: Bool = false  // 발표 모드 여부
    var sectionsData: Data? = nil  // JSON 인코딩된 [PresentationSection]
    var createdAt: Date
    var lastUsedAt: Date?  // 마지막 사용 시간
    @Relationship(deleteRule: .cascade, inverse: \TimerRecord.template)
    var runs: [TimerRecord] = []

    init(
        id: UUID = UUID(),
        name: String,
        mainSeconds: Int,
        prealertOffsetsSec: [Int],
        prealertMessages: [Int: String] = [:],
        finishMessage: String? = nil,
        label: String = "",
        colorHex: String = "#007AFF",
        isFavorite: Bool = false,
        isPresentation: Bool = false,
        sectionsData: Data? = nil,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.mainSeconds = max(1, mainSeconds)
        self.prealertOffsetsSec = prealertOffsetsSec
        self.prealertMessages = prealertMessages
        self.finishMessage = finishMessage
        self.label = label
        self.colorHex = colorHex
        self.isFavorite = isFavorite
        self.isPresentation = isPresentation
        self.sectionsData = sectionsData
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        _ = validateInPlace()
    }

    /// 발표 섹션 배열 (JSON encode/decode)
    var sections: [PresentationSection] {
        get {
            guard let data = sectionsData else { return [] }
            return (try? JSONDecoder().decode([PresentationSection].self, from: data)) ?? []
        }
        set {
            sectionsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// 전체 섹션 합산 시간
    var totalSectionDuration: Int {
        sections.reduce(0) { $0 + $1.durationSeconds }
    }

    @discardableResult
    // error case identifier: time is not enough to be prealert
    func validateInPlace() -> Self {
        let filtered =
            prealertOffsetsSec
            .filter { $0 > 0 && $0 < mainSeconds }
        let uniqueSorted = Array(Set(filtered)).sorted()
        self.prealertOffsetsSec = uniqueSorted
        return self
    }
}

extension Timer {
    // prealert time components
    static let presetOffsetsSec: [Int] = [30, 45, 60, 180, 300, 600, 900, 1800]

    // 프리셋 Label Color
    static let presetColors: [String: String] = [
        "Presentation": "#FF3B30",      // 빨강
        "Mentoring": "#34C759",    // sec록
        "Meeting": "#007AFF",      // 파랑
        "Break": "#FF9500",      // 주황
        "Focus": "#5856D6",      // 보라
        "Exercise": "#FF2D55",      // 핑크
        "Study": "#5AC8FA",      // 하늘색
        "Reading": "#FFCC00",      // 노랑
    ]

    /// Pre-alert Message 가져오기 (커스텀 메시지가 없으면 기본 메시지 반환)
    func getPrealertMessage(for offsetSec: Int) -> String {
        if let customMessage = prealertMessages[offsetSec], !customMessage.isEmpty {
            return customMessage
        }
        // 기본 메시지
        if offsetSec < 60 {
            return "\(offsetSec) sec remaining"
        }
        let minutes = offsetSec / 60
        return "\(minutes) min remaining"
    }

    /// End Alert Message 가져오기 (커스텀 메시지가 없으면 기본 메시지 반환)
    func getFinishMessage() -> String {
        if let customMessage = finishMessage, !customMessage.isEmpty {
            return customMessage
        }
        return "Timer finished"
    }

    /// 사용 횟수
    var usageCount: Int {
        runs.count
    }

    /// Done 횟수
    var completedCount: Int {
        runs.filter { $0.finished }.count
    }
}
