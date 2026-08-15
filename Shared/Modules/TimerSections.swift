//
//  TimerSections.swift
//  Rereminder
//
//  알림 지점을 경계로 타이머를 구간으로 나눈다 — 발표 모드의 "구간"은 전부 이 계산에서 나온다.
//
//  같은 계산이 화면(TimerMainView 의 링·구간 리스트)과 뷰모델(발표 시작 시 만드는
//  PresentationSection)에 따로 있었다. 두 곳이 조금이라도 어긋나면 링에 보이는 구간과
//  실제로 울리는 구간이 달라지므로 한 곳으로 모은다.
//
//  ⚠️ 순수 함수다. 시간·알림만 받고 화면도 저장소도 모른다(그래서 테스트가 쉽다).
//

import Foundation

enum TimerSections {

    /// 구간 하나 — 시각은 **시작 후 경과 초**다(링의 "남은 시간" 좌표가 아니다).
    struct Segment: Equatable, Identifiable {
        /// 경과 순서(0부터). 구간 색·이름이 이 번호를 따른다.
        let index: Int
        let startSec: Int
        let endSec: Int

        var id: Int { index }
        var durationSec: Int { endSec - startSec }
    }

    /// 알림을 경계로 구간을 만든다.
    /// - Parameters:
    ///   - mainSeconds: 타이머 전체 길이. 0 이하면 구간이 없다.
    ///   - alertOffsets: **종료까지 남은 시간** 기준 알림 지점(예: 5분 전 = 300).
    ///     0 이하이거나 전체 길이 이상인 값은 경계가 될 수 없어 무시한다.
    /// - Returns: 시작 → 종료 순서의 구간 목록. 알림이 없으면 전체가 한 구간이다.
    static func derive(mainSeconds: Int, alertOffsets: Set<Int>) -> [Segment] {
        guard mainSeconds > 0 else { return [] }
        let boundaries = alertOffsets
            .filter { $0 > 0 && $0 < mainSeconds }
            .map { mainSeconds - $0 }     // 남은 시간 → 경과 시간
            .sorted()
        let points = [0] + boundaries + [mainSeconds]
        return (0..<(points.count - 1)).map { i in
            Segment(index: i, startSec: points[i], endSec: points[i + 1])
        }
    }
}
