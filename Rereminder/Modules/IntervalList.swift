//
//  IntervalList.swift
//  Rereminder
//
//  **구간을 목록으로 적는다** — "5분, 20분, 5분"을 적으면 총 시간과 알림이 저절로 선다.
//  제보(2026-11-16, 포르투갈어): "목록으로 구간을 만들 수 있으면 좋겠다. 지금은 원에서 직접 한다."
//  원 위에서 종을 각도로 맞추는 것보다, 구간 길이를 이미 알고 있는 사람에게는 숫자로 적는 편이 빠르다.
//
//  구간과 알림은 같은 것의 두 이름이다: 구간의 경계 = 알림(`TimerSections`). 여기서는 그 변환만 한다.
//  ⚠️ 구간을 따로 저장하지 않는다. 목록은 다이얼에 올리는 입력일 뿐, 저장되는 것은 총 시간과 알림이다 —
//     따로 두면 다이얼에서 종을 옮긴 뒤 목록과 다이얼이 갈라진다.
//

import Foundation

enum IntervalList {
    /// 구간 길이(초)들 → 총 시간과 알림(끝나기 몇 초 전). 0초 구간은 뺀다.
    /// 합이 0 이거나 다이얼 상한을 넘으면 nil.
    static func setup(from lengths: [Int]) -> (total: Int, offsets: Set<Int>)? {
        let kept = lengths.filter { $0 > 0 }
        let total = kept.reduce(0, +)
        guard total > 0, total <= TimeMapper.maxSeconds else { return nil }
        var offsets = Set<Int>()
        var elapsed = 0
        for length in kept.dropLast() {
            elapsed += length
            offsets.insert(total - elapsed)
        }
        return (total, offsets)
    }

    /// 지금 다이얼 → 구간 길이들. 시트를 열 때 지금 설정으로 채운다.
    static func lengths(total: Int, offsets: Set<Int>) -> [Int] {
        guard total > 0 else { return [] }
        let boundaries = offsets.filter { $0 > 0 && $0 < total }.sorted(by: >)
        var lengths: [Int] = []
        var previousRemaining = total
        for remaining in boundaries {
            lengths.append(previousRemaining - remaining)
            previousRemaining = remaining
        }
        lengths.append(previousRemaining)
        return lengths
    }
}
