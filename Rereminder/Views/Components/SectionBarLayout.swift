//
//  SectionBarLayout.swift
//  Rereminder
//
//  구간 막대의 **자리 계산** — 각 구간이 가로로 어디서 시작해 얼마나 넓은가, 재생헤드는 어디인가.
//
//  링은 각도로 시간을 말한다. 각도는 크기를 읽는 채널 중 약한 편이라(위치 > 길이 > 각도),
//  "인트로 5분 / 데모 25분" 같은 **구간끼리의 비교**가 원에서는 잘 안 읽힌다.
//  막대는 그 비교를 길이로 바꿔 준다 — 이 파일이 그 길이를 정한다.
//
//  ⚠️ 순수 함수다. 시간·폭만 받고 화면도 색도 모른다(그래서 테스트가 쉽다).
//  ⚠️ 구간을 나누는 계산은 여기서 하지 않는다 — `TimerSections.derive` 하나만 쓴다.
//

import CoreGraphics

enum SectionBarLayout {

    /// 막대 위의 구간 한 칸.
    struct Slot: Equatable, Identifiable {
        /// `TimerSections.Segment.index` 와 같은 값(경과 순서).
        let index: Int
        /// 막대 왼쪽 끝에서의 거리.
        let x: CGFloat
        let width: CGFloat

        var id: Int { index }
        var maxX: CGFloat { x + width }
    }

    /// 구간을 가로 폭에 배분한다.
    ///
    /// 기본은 시간에 비례한 폭이지만, **`minWidth` 보다 좁아지는 칸은 `minWidth` 로 올린다.**
    /// 60분 타이머의 30초짜리 구간은 비례대로면 3pt 도 안 돼 화면에서 사라지는데,
    /// 사라진 구간은 "없는 구간"으로 읽힌다. 대신 그만큼 다른 칸이 줄어드니
    /// **좁은 칸이 섞이면 길이가 시간에 정확히 비례하지는 않는다** — 알고 쓰는 거짓말이다.
    ///
    /// - Parameters:
    ///   - totalWidth: 막대 전체 폭(칸 사이 여백 포함).
    ///   - gap: 칸 사이 여백.
    ///   - minWidth: 칸 하나의 최소 폭.
    /// - Returns: 경과 순서대로의 칸 목록. 폭이 모자라면 균등 분할한다.
    static func slots(segments: [TimerSections.Segment],
                      totalWidth: CGFloat,
                      gap: CGFloat = 3,
                      minWidth: CGFloat = 6) -> [Slot] {
        let count = segments.count
        guard count > 0 else { return [] }

        let track = totalWidth - gap * CGFloat(count - 1)
        guard track > 0 else { return [] }

        let widths = distribute(durations: segments.map { max(0, $0.durationSec) },
                                track: track,
                                minWidth: minWidth)

        var x: CGFloat = 0
        return segments.enumerated().map { position, segment in
            let slot = Slot(index: segment.index, x: x, width: widths[position])
            x += widths[position] + gap
            return slot
        }
    }

    /// 재생헤드(지금 이 순간)의 x 좌표.
    ///
    /// ⚠️ **비례 계산이 아니라 실제로 그려진 칸 폭(`slots`)을 따라간다.** 최소 폭으로 넓혀 준 칸이
    ///    있으면 비례 좌표와 어긋나는데, 그러면 알림이 울리는 순간 재생헤드가 경계에 있지 않다.
    ///    "울렸는데 아직 안 넘었네"로 보이는 순간 이 막대는 못 믿을 물건이 된다.
    static func playheadX(slots: [Slot],
                          segments: [TimerSections.Segment],
                          elapsedSec: Int) -> CGFloat {
        guard let last = slots.last, let lastSegment = segments.last else { return 0 }
        guard elapsedSec > 0 else { return 0 }
        guard elapsedSec < lastSegment.endSec else { return last.maxX }

        for (position, segment) in segments.enumerated() where elapsedSec < segment.endSec {
            let slot = slots[position]
            guard segment.durationSec > 0 else { return slot.x }
            let progress = CGFloat(elapsedSec - segment.startSec) / CGFloat(segment.durationSec)
            return slot.x + slot.width * min(1, max(0, progress))
        }
        return last.maxX
    }

    // MARK: - 폭 배분

    /// 시간에 비례해 나누되 `minWidth` 밑으로 내려가는 칸은 고정하고 나머지끼리 다시 나눈다.
    /// 한 번 고정하면 남는 몫이 줄어 **다른 칸이 새로 최소 폭 밑으로 떨어질 수 있어** 안정될 때까지 반복한다.
    private static func distribute(durations: [Int],
                                   track: CGFloat,
                                   minWidth: CGFloat) -> [CGFloat] {
        let count = durations.count
        let equal = Array(repeating: track / CGFloat(count), count: count)

        // 최소 폭조차 못 주는 좁은 화면이거나 시간 정보가 없으면 균등 분할이 가장 정직하다.
        guard minWidth * CGFloat(count) <= track, durations.reduce(0, +) > 0 else { return equal }

        var pinned = Set<Int>()
        while true {
            let budget = track - minWidth * CGFloat(pinned.count)
            let freeTotal = durations.enumerated()
                .filter { !pinned.contains($0.offset) }
                .reduce(0) { $0 + $1.element }
            guard freeTotal > 0 else { break }

            let newlyPinned = durations.enumerated().filter { position, duration in
                !pinned.contains(position)
                    && budget * CGFloat(duration) / CGFloat(freeTotal) < minWidth
            }.map(\.offset)

            if newlyPinned.isEmpty { break }
            pinned.formUnion(newlyPinned)
            if pinned.count == count { return equal }
        }

        let budget = track - minWidth * CGFloat(pinned.count)
        let freeTotal = durations.enumerated()
            .filter { !pinned.contains($0.offset) }
            .reduce(0) { $0 + $1.element }
        guard freeTotal > 0 else { return equal }

        return durations.enumerated().map { position, duration in
            pinned.contains(position)
                ? minWidth
                : budget * CGFloat(duration) / CGFloat(freeTotal)
        }
    }
}
