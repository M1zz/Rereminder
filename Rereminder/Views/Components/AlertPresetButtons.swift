//
//  AlertPresetButtons.swift
//  Rereminder
//
//  알림 프리셋 저장과 알림 문구, `+` 가 켤 다음 시간(`AlertPresets`).
//  프리셋(기본 1·3·5분)은 설정에서 사용자가 변경 가능
//

import Foundation

/// 미리 알림 프리셋 저장 (UserDefaults, "60,180,300" 형태)
enum AlertPresets {
    static let storageKey = "alertPresetOffsets"
    static let defaultRaw = "60,180,300"

    static func decode(_ raw: String) -> [Int] {
        let list = raw.split(separator: ",").compactMap { Int($0) }.filter { $0 > 0 }
        return list.isEmpty ? [60, 180, 300] : Array(Set(list)).sorted()
    }

    static func encode(_ list: [Int]) -> String {
        Array(Set(list.filter { $0 > 0 })).sorted().map(String.init).joined(separator: ",")
    }

    /// 문장 안에서 칠할 시간 부분. "5분 전"의 "5분", "17:40 전"의 "17:40".
    static func timePart(_ sec: Int) -> String {
        if sec < 60 { return String(localized: "\(sec) sec") }
        if sec % 60 == 0 { return String(localized: "\(sec / 60) min") }
        return TimeMapper.mmss(sec)
    }

    /// 종의 색 — 그 종이 끝내는 구간의 색. 먼저 울리는 종이 첫 구간(링과 같은 번호)이다.
    /// 링 조각·종·문장의 시간이 같은 색이라 어느 종이 어느 시간인지 읽힌다.
    static func bellSectionIndex(of seconds: Int, among offsets: Set<Int>) -> Int {
        offsets.sorted(by: >).firstIndex(of: seconds) ?? 0
    }

    static func label(_ sec: Int) -> String {
        if sec < 60 { return String(localized: "\(sec) sec before") }
        if sec % 60 == 0 { return String(localized: "\(sec / 60) min before") }
        return String(localized: "\(TimeMapper.mmss(sec)) before")
    }

    /// 제안 시점의 재료 — 사람이 말하는 시간만 쓴다
    private static let friendlySeconds = [5, 10, 15, 20, 30, 45, 60, 120, 180, 300, 600, 900, 1200, 1800, 2700, 3600, 5400]

    /// `+` 를 누를 때 켤 다음 알림. 설정에서 바꾼 프리셋이 먼저, 그다음 이 길이에서 쓸모 있는 순서다.
    /// 예: 30분 → 5분 전 → 1분 전 → 10분 전 → 3분 전. 다 켜졌으면 시작과 첫 알림의 중간(개수 한도는 없다).
    static func nextAlert(totalSeconds: Int, presetsRaw: String, selected: Set<Int>) -> Int? {
        guard totalSeconds > 0 else { return nil }
        let custom = presetsRaw == defaultRaw ? [] : decode(presetsRaw).filter { $0 < totalSeconds }
        let ranked = [6.0, 30, 3, 10, 2, 1.5].compactMap { friendly(near: Double(totalSeconds) / $0, below: totalSeconds) }
        if let next = (custom + ranked).first(where: { !selected.contains($0) }) { return next }

        let first = selected.filter { $0 < totalSeconds }.max()
        let raw = first.map { (totalSeconds + $0) / 2 } ?? totalSeconds / 2
        // 5초 단위로 반올림, 최소 5초
        let midpoint = max(5, Int((Double(raw) / 5.0).rounded()) * 5)
        return midpoint < totalSeconds && !selected.contains(midpoint) ? midpoint : nil
    }

    private static func friendly(near target: Double, below total: Int) -> Int? {
        friendlySeconds
            .filter { $0 < total }
            .min { abs(log(Double($0) / target)) < abs(log(Double($1) / target)) }
    }
}
