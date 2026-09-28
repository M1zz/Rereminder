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
    var sectionsData: Data?  // JSON 인코딩된 [PresentationSection]
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
            return String(localized: "\(offsetSec) sec remaining")
        }
        let minutes = offsetSec / 60
        return String(localized: "\(minutes) min remaining")
    }

    /// End Alert Message 가져오기 (커스텀 메시지가 없으면 기본 메시지 반환)
    func getFinishMessage() -> String {
        if let customMessage = finishMessage, !customMessage.isEmpty {
            return customMessage
        }
        return String(localized: "Timer finished")
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

// MARK: - 화면에 보이는 이름

/// ⚠️ 저장된 이름은 **영어 그대로 두고 보여 줄 때 번역한다.**
/// 시드 템플릿("Study 25 min")과 자동 이름("Main 25 min / Pre-alert 5·1 min")은 이미 수많은
/// 기기의 SwiftData 에 영어로 들어가 있고, `LegacyFreeNotice.seedTemplateNames` 가 그 이름으로
/// 시드를 가려낸다. 저장값을 번역해 바꾸면 그 판정이 깨지고, 언어를 바꾼 뒤에는 또 틀린 말이 된다.
extension Timer {
    /// 시드 템플릿의 라벨 — 이름·라벨 번역에 함께 쓴다
    static let seedLabels = ["Presentation", "Mentoring", "Study", "Exercise", "Meeting"]

    /// 자동 이름 생성기(영어, 저장용). `TimerConfigService.makeTemplateName` 이 이걸 쓴다
    static func generatedName(mainSec: Int, offsets: [Int]) -> String {
        let m = max(0, mainSec) / 60
        let s = max(0, mainSec) % 60
        let base = s > 0 ? "Main \(m) min \(s) sec" : "Main \(m) min"
        if offsets.isEmpty { return base }
        let pre = offsets.map { "\($0/60)" }.joined(separator: "·")
        return "\(base) / Pre-alert \(pre) min"
    }

    /// 시드 이름("Study 25 min")이면 그 분을 돌려준다. 사용자가 붙인 이름이면 nil
    private var seedNameMinutes: Int? {
        guard Self.seedLabels.contains(label),
              name.hasPrefix(label + " "), name.hasSuffix(" min") else { return nil }
        return Int(name.dropFirst(label.count + 1).dropLast(4))
    }

    /// 화면·Live Activity 에 보여 줄 이름. 앱이 만든 이름만 지금 언어로 다시 쓴다
    var displayName: String {
        if name.isEmpty { return TimeMapper.mmss(mainSeconds) }
        if let minutes = seedNameMinutes {
            return "\(displayLabel) \(TimeMapper.durationText(minutes * 60))"
        }
        if name == Self.generatedName(mainSec: mainSeconds, offsets: prealertOffsetsSec) {
            let main = TimeMapper.durationText(mainSeconds)
            guard !prealertOffsetsSec.isEmpty else { return main }
            let alerts = prealertOffsetsSec.sorted(by: >)
                .map { TimeMapper.durationText($0) }
                .joined(separator: ", ")
            return String(localized: "\(main) · alerts \(alerts) before end")
        }
        return name
    }

    /// 라벨 칩 문구. 앱이 준 라벨(프리셋)만 번역하고 사용자가 쓴 라벨은 그대로
    var displayLabel: String {
        Self.localizedLabel(label)
    }

    static func localizedLabel(_ label: String) -> String {
        switch label {
        case "Presentation": return String(localized: "Presentation")
        case "Mentoring": return String(localized: "Mentoring")
        case "Meeting": return String(localized: "Meeting")
        case "Break": return String(localized: "Break")
        case "Focus": return String(localized: "Focus")
        case "Exercise": return String(localized: "Exercise")
        case "Study": return String(localized: "Study")
        case "Reading": return String(localized: "Reading")
        default: return label
        }
    }
}
