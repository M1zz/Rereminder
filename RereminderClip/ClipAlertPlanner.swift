//
//  ClipAlertPlanner.swift
//  RereminderClip
//
//  "총 시간만 정하면 알림 3번을 알아서 잡아준다" — App Clip의 핵심 로직.
//
//  본 앱에서는 사용자가 다이얼을 돌려 알림 지점을 직접 찍지만,
//  클립은 한 번의 탭으로 가치를 보여줘야 하므로 지점을 자동 배분한다.
//

import Foundation

enum ClipAlertPlanner {

    /// 자동 배분할 알림 개수
    static let alertCount = 3

    /// 사람이 말로 하는 단위들. 자동 계산 결과를 여기로 스냅해
    /// "1분 32초 전" 대신 "1분 30초 전"처럼 읽히게 만든다.
    private static let friendlyOffsets: [Int] = [
        10, 15, 20, 30, 45,
        60, 90, 120, 180, 300, 420,
        600, 900, 1200, 1800, 2700, 3600
    ]

    /// 총 시간 대비 알림 지점 비율.
    /// 1800초(30분) → 600·300·60 = "10분·5분·1분 전"이 되도록 잡은 값이다.
    private static let fractions: [Double] = [1.0 / 3.0, 1.0 / 6.0, 1.0 / 30.0]

    /// 총 시간에서 "끝나기 N초 전" 알림 지점 3개를 만든다.
    ///
    /// - Parameter totalSeconds: 타이머 전체 길이(초)
    /// - Returns: 내림차순 offset 배열. 총 시간이 짧아 3개를 만들 수 없으면 더 적게 반환한다.
    static func offsets(totalSeconds: Int) -> [Int] {
        guard totalSeconds > 0 else { return [] }

        var result: [Int] = []
        for fraction in fractions {
            let raw = Double(totalSeconds) * fraction
            guard let snapped = snap(raw, below: totalSeconds, excluding: result) else { continue }
            result.append(snapped)
        }
        return result.sorted(by: >)
    }

    /// 스냅 결과가 목표에서 이만큼 넘게 벗어나면 그 알림은 만들지 않는다.
    /// (1분 타이머에서 "2초 전"을 "15초 전"으로 끌어올리는 식의 왜곡 방지)
    private static let maxSnapRatio: Double = 2.0

    /// 알림 지점 사이 최소 간격(초).
    ///
    /// 링은 메인 앱과 같은 절대 각도(1° = 10초)라 150초 = 15°다.
    /// 종 노브가 그보다 가까우면 서로 겹쳐 집어서 옮길 수가 없다.
    /// 간격을 확보하지 못하면 알림을 3개보다 적게 만든다 — 겹친 3개보다 낫다.
    private static let minSeparationSeconds = 150

    /// 계산값을 가장 가까운 친숙한 단위로 스냅한다.
    /// 총 시간 이상이거나 이미 쓴 지점과 너무 가까우면 후보에서 뺀다.
    private static func snap(_ raw: Double, below total: Int, excluding used: [Int]) -> Int? {
        let candidates = friendlyOffsets.filter { candidate in
            candidate < total
                && used.allSatisfy { abs($0 - candidate) >= minSeparationSeconds }
        }
        guard !candidates.isEmpty else { return nil }

        let nearest = candidates.min { lhs, rhs in
            abs(Double(lhs) - raw) < abs(Double(rhs) - raw)
        }
        guard let nearest else { return nil }

        let ratio = max(Double(nearest) / raw, raw / Double(nearest))
        return ratio <= maxSnapRatio ? nearest : nil
    }

    /// "10분", "1분 30초", "20초" 같은 표시용 문자열
    static func label(forOffset seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        switch (minutes, secs) {
        case (0, _):
            return String(localized: "\(secs) sec")
        case (_, 0):
            return String(localized: "\(minutes) min")
        default:
            return String(localized: "\(minutes) min \(secs) sec")
        }
    }
}
