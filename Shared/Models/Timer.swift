//
//  Timer.swift
//  Toki
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
    var prealertMessages: [Int: String] = [:]  // 각 예비 알림의 커스텀 메시지 (오프셋 초: 메시지)
    var finishMessage: String?  // 종료 알림 커스텀 메시지 (nil이면 기본 메시지)
    var label: String = ""  // 레이블 (예: "발표", "멘토링", "회의")
    var colorHex: String = "#007AFF"  // 레이블 색상 (기본: 파란색)
    var isFavorite: Bool = false  // 즐겨찾기 여부
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
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        _ = validateInPlace()
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
    static let presetOffsetsSec: [Int] = [60, 180, 300, 600, 900, 1800]

    // 프리셋 레이블 색상
    static let presetColors: [String: String] = [
        "발표": "#FF3B30",      // 빨강
        "멘토링": "#34C759",    // 초록
        "회의": "#007AFF",      // 파랑
        "휴식": "#FF9500",      // 주황
        "집중": "#5856D6",      // 보라
        "운동": "#FF2D55",      // 핑크
        "공부": "#5AC8FA",      // 하늘색
        "독서": "#FFCC00",      // 노랑
    ]

    /// 예비 알림 메시지 가져오기 (커스텀 메시지가 없으면 기본 메시지 반환)
    func getPrealertMessage(for offsetSec: Int) -> String {
        if let customMessage = prealertMessages[offsetSec], !customMessage.isEmpty {
            return customMessage
        }
        // 기본 메시지
        let minutes = offsetSec / 60
        return "\(minutes)분 남았습니다"
    }

    /// 종료 알림 메시지 가져오기 (커스텀 메시지가 없으면 기본 메시지 반환)
    func getFinishMessage() -> String {
        if let customMessage = finishMessage, !customMessage.isEmpty {
            return customMessage
        }
        return "타이머 종료되었습니다"
    }

    /// 사용 횟수
    var usageCount: Int {
        runs.count
    }

    /// 완료 횟수
    var completedCount: Int {
        runs.filter { $0.finished }.count
    }
}
