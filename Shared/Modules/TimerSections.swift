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

    /// 지금 이 구간이 어디쯤인가 — 지나갔나, 지나는 중인가, 아직인가.
    enum Phase: Equatable {
        case done, active, upcoming
    }

    /// 경과 시간으로 본 구간의 상태.
    /// 경계에 딱 걸리면(경과 == 구간 끝) **지나간 것**으로 본다 — 그 순간 알림이 울리기 때문이다.
    static func phase(of segment: Segment, elapsedSec: Int) -> Phase {
        if elapsedSec >= segment.endSec { return .done }
        if elapsedSec >= segment.startSec { return .active }
        return .upcoming
    }

    /// 구간별로 화면에 세울 남은 시간.
    /// 지난 구간은 0, 지나는 중인 구간은 남은 만큼, 아직 오지 않은 구간은 **통째로**다
    /// (앞 구간이 끝나야 비로소 줄어들기 시작한다 — 그게 이 리스트의 전부다).
    static func remainingSeconds(of segment: Segment, elapsedSec: Int) -> Int {
        switch phase(of: segment, elapsedSec: elapsedSec) {
        case .done:     return 0
        case .active:   return max(0, segment.endSec - elapsedSec)
        case .upcoming: return segment.durationSec
        }
    }

    /// 링 위의 한 조각이 몇 번째 구간(경과 순서)인지.
    ///
    /// 링은 **종료까지 남은 시간** 좌표라 경과 순서와 방향이 반대다. 그래서 조각의 끝
    /// (= 종료에서 먼 쪽)보다 뒤에 있는 알림을 세면 그게 곧 그 구간의 번호가 된다.
    ///
    /// ⚠️ 자리 번호(전체 조각 수 − 1 − i)로 세지 말 것. **진행 중에는 이미 지나간 경계가 호에서
    ///    빠져 나가 조각 수가 줄어들기 때문에** 남은 구간의 색이 통째로 한 칸씩 밀린다.
    ///    (10분·1분 전 알림 타이머에서 1분을 지나는 순간 초록이던 마지막 구간이 파랑으로 바뀌던 문제)
    ///
    /// - Parameters:
    ///   - segmentEnd: 조각의 끝 위치(링 좌표든 초든, markers와 같은 단위면 된다).
    ///   - markers: 알림 지점들(같은 단위).
    static func ringSectionIndex(segmentEnd: Double,
                                 markers: [Double],
                                 tolerance: Double = 0.000_1) -> Int {
        markers.filter { $0 >= segmentEnd - tolerance }.count
    }

    // MARK: - 지금 지나는 중인 구간 (이중 링의 안쪽 링이 보는 값)

    /// 지금 어느 구간을 지나고 있고, 그 구간이 얼마나 남았나.
    ///
    /// **이중 링의 안쪽 링·가운데 큰 숫자가 전부 이 하나를 본다.** 바깥 링은 "전체가 얼마 남았나",
    /// 안쪽 링은 "이 구간이 얼마 남았나" — 두 값을 각각 다른 곳에서 계산하면 링과 숫자가 갈라진다.
    struct Progress: Equatable {
        let segment: Segment
        /// 전체 구간 수. 하나뿐이면 안쪽 링은 바깥 링과 같은 말을 한다.
        let totalCount: Int
        /// 이 구간의 남은 시간(초).
        let remainingSec: Int
        /// 이 구간의 남은 비율 (1 → 0). 안쪽 링의 trim 값.
        let remainingRatio: Double

        var index: Int { segment.index }

        /// 안쪽 링을 그릴 만한가 — **구간이 둘 이상일 때만** 뜻이 있다.
        var isDivided: Bool { totalCount > 1 }
    }

    /// 경과 시간으로 지금 구간을 찾는다. 구간이 없거나 이미 다 지났으면(오버타임) nil.
    static func progress(mainSeconds: Int, alertOffsets: Set<Int>, elapsedSec: Int) -> Progress? {
        let segments = derive(mainSeconds: mainSeconds, alertOffsets: alertOffsets)
        guard !segments.isEmpty, elapsedSec < mainSeconds else { return nil }

        let elapsed = max(0, elapsedSec)
        // 경계에 딱 걸린 순간은 이미 그 구간이 끝난 것으로 본다(phase 와 같은 규칙).
        guard let segment = segments.first(where: { elapsed < $0.endSec }) else { return nil }

        let remaining = remainingSeconds(of: segment, elapsedSec: elapsed)
        let duration = max(1, segment.durationSec)
        return Progress(segment: segment,
                        totalCount: segments.count,
                        remainingSec: remaining,
                        remainingRatio: min(1, max(0, Double(remaining) / Double(duration))))
    }
}
