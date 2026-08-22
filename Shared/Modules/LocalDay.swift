//
//  LocalDay.swift
//  Rereminder
//
//  "며칠째인가"를 **사용자의 달력 기준**으로 센다.
//
//  ⚠️ `Int(date.timeIntervalSince1970 / 86_400)` 으로 세면 **UTC 자정**이 경계가 된다.
//     한국(UTC+9)에서는 그게 오전 9시라, 아침 8시와 10시에 한 번씩 쓴 것이 **이틀**로 세어진다.
//     "같은 날 여러 번"과 "다른 날 반복"을 가르는 판정이 그렇게 어긋나면 기능이 통째로 틀어진다.
//     (실제로 `RepeatDetectorTests` 가 이걸 잡았다.)
//
//  일광절약시간처럼 하루가 23·25시간인 날이 있어 나눗셈이 정수로 떨어지지 않는다 — 그래서 반올림한다.
//

import Foundation

enum LocalDay {

    /// 이 날짜가 속한 **로컬 하루**를 가리키는 정수. 같은 날이면 같은 값, 다음 날이면 +1.
    static func stamp(_ date: Date, calendar: Calendar = .current) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        return Int((startOfDay.timeIntervalSince1970 / 86_400).rounded())
    }
}
