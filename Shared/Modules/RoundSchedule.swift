//
//  RoundSchedule.swift
//  Rereminder
//
//  **반복**: 링은 한 바퀴(한 회)만 정하고, 그걸 몇 번 돌릴지(`rounds`)만 적는다.
//  운동 1:00 + 휴식 0:30 을 27번 — 종이 54개 늘어선 링이 아니라, 1:30 링 하나와 "× 27" 이다(제보 2026-11-16).
//
//  시간은 처음부터 잰 **전체 경과**(e) 하나로 센다. 지금 몇 회째인지, 이 회에 얼마 남았는지는 거기서 나온다.
//  화면·링은 회 안의 남은 시간만 보므로 한 번 걸 때와 똑같이 그린다.
//
//  ⚠️ **알림 예약은 앱당 64개가 상한이다.** 27회면 회마다 예비 알림 + 회 끝 알림이 54개라 다 깔면
//     넘치고, iOS 는 넘치는 것을 조용히 버린다. 그래서 가까운 것부터 `budget` 개만 깔고,
//     앱이 앞에 있는 동안·다시 열릴 때 지나간 만큼 다시 채운다(`TimerEngine.topUpRoundNotifications`).
//     앱이 멈춰 있는 동안에는 채울 수 없다 — 그때는 처음 깔아 둔 만큼만 울린다.
//

import Foundation

enum RoundSchedule {
    /// 한 회 안에서 울리는 것 하나.
    struct Event: Equatable {
        enum Kind: Equatable {
            /// 예비 알림 — 그 회가 끝나기 `offset` 초 전
            case prealert(offset: Int)
            /// 마지막이 아닌 회의 끝 — 다음 회가 바로 시작한다
            case roundEnd
        }
        /// 몇 번째 회인가(0부터)
        let round: Int
        let kind: Kind
        /// 처음부터 잰 경과 시각(초)
        let at: TimeInterval

        /// 알림 식별자 꼬리. 같은 일을 다시 예약하면 같은 이름이라 덮어쓴다(겹쳐 울리지 않는다).
        var identifierSuffix: String {
            switch kind {
            case .prealert(let offset): return "r\(round).prealert.\(offset)"
            case .roundEnd: return "r\(round).end"
            }
        }
    }

    /// 다른 일에 남겨 둘 예약 몫(다음 자리 예약 알림 등)
    static let reserve = 4
    /// iOS 가 앱 하나에 들고 있는 예약 알림 수
    static let systemLimit = 64

    /// 회 알림에 쓸 수 있는 예약 수 — 종료 알림 하나와 되풀이 알림 몫을 뺀다.
    static func budget(escalationCount: Int) -> Int {
        max(1, systemLimit - reserve - 1 - escalationCount)
    }

    static func total(roundSeconds: TimeInterval, rounds: Int) -> TimeInterval {
        roundSeconds * TimeInterval(max(1, rounds))
    }

    /// 경과 e 에서 몇 번째 회인가(0부터). 끝난 뒤에도 마지막 회다.
    static func roundIndex(elapsed e: TimeInterval, roundSeconds: TimeInterval, rounds: Int) -> Int {
        // 경과가 무한대·NaN(시계가 크게 튀었거나 깨진 복원 값)이면 `Int(...)` 가 앱을 죽인다 — 첫 회로 본다.
        guard roundSeconds > 0, e.isFinite else { return 0 }
        let index = (e / roundSeconds).rounded(.down)
        // 아주 큰 경과도 `Int` 로 바꾸기 전에 회 수 안으로 자른다(바꾸는 순간 넘치면 죽는다).
        return Int(min(Double(max(1, rounds) - 1), max(0, index)))
    }

    /// 경과 e 에서 이 회에 남은 시간. 마지막 회가 끝나면 음수(오버타임)로 이어진다.
    static func roundRemaining(elapsed e: TimeInterval, roundSeconds: TimeInterval, rounds: Int) -> TimeInterval {
        let n = max(1, rounds)
        let index = roundIndex(elapsed: e, roundSeconds: roundSeconds, rounds: n)
        return TimeInterval(index + 1) * roundSeconds - e
    }

    /// 경과 e **뒤에** 울릴 것들을 가까운 순서로. `limit` 개까지.
    /// 마지막 회의 끝은 종료 알림 몫이라 여기 없다.
    static func upcoming(roundSeconds: TimeInterval, rounds: Int, offsets: [TimeInterval],
                         after e: TimeInterval, limit: Int) -> [Event] {
        let n = max(1, rounds)
        guard roundSeconds > 0, limit > 0 else { return [] }
        var events: [Event] = []
        let first = roundIndex(elapsed: e, roundSeconds: roundSeconds, rounds: n)
        for round in first..<n {
            let start = TimeInterval(round) * roundSeconds
            var inRound: [Event] = offsets
                .filter { $0 > 0 && $0 < roundSeconds }
                .map { Event(round: round, kind: .prealert(offset: Int($0)), at: start + roundSeconds - $0) }
            if round < n - 1 {
                inRound.append(Event(round: round, kind: .roundEnd, at: start + roundSeconds))
            }
            for event in inRound.sorted(by: { $0.at < $1.at }) where event.at > e {
                events.append(event)
                if events.count == limit { return events }
            }
        }
        return events
    }

    /// 전부 깔면 몇 개인가 — 예약 몫을 넘으면 잠금화면에서는 끝까지 울리지 못한다.
    static func eventCount(roundSeconds: TimeInterval, rounds: Int, offsets: [TimeInterval]) -> Int {
        let n = max(1, rounds)
        let perRound = offsets.filter { $0 > 0 && $0 < roundSeconds }.count
        return perRound * n + (n - 1)
    }

    /// 앱을 열지 않아도 울리는 마지막 회(1부터). 다 들어가면 nil.
    static func lastCoveredRound(roundSeconds: TimeInterval, rounds: Int, offsets: [TimeInterval],
                                 budget: Int) -> Int? {
        let all = upcoming(roundSeconds: roundSeconds, rounds: rounds, offsets: offsets,
                           after: -1, limit: Int.max)
        guard all.count > budget else { return nil }
        // 예약이 닿는 마지막 알림이 끝내는 회까지만 온전히 울린다
        return all[budget - 1].kind == .roundEnd ? all[budget - 1].round + 1 : all[budget - 1].round
    }
}
