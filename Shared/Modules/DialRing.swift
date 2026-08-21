//
//  DialRing.swift
//  Rereminder
//
//  다이얼을 몇 줄로, 얼마만큼 그릴지 정하는 규칙 (순수 함수).
//
//  다이얼은 한 바퀴가 60분이고 최대 두 바퀴(120분)다. 60분을 넘는 만큼은 **안쪽 줄**로 내려간다.
//  화면 쪽에서는 호·종 노브·드래그 핸들·마커가 전부 이 계산을 따라야 한 줄만 어긋나는 일이 없다.
//

import Foundation
import CoreGraphics

enum DialRing {

    /// 초 → 바퀴 수 (1.0 = 한 바퀴 = 60분)
    static func laps(ofSeconds seconds: Double) -> CGFloat {
        CGFloat(max(0, seconds)) / CGFloat(TimeMapper.secondsPerLap)
    }

    /// 링을 **절대 각도**(1° = 10초)로 그릴지 여부.
    ///
    /// 진행 중에는 보통 비율로 그린다 — 10분 타이머도 링이 가득 찼다가 줄어드는 편이 읽기 쉽다.
    /// 다만 60분을 넘는 타이머까지 비율로 누르면 90분이 한 바퀴로 압축돼, 방금 대기 화면에서 보던
    /// **두 줄이 사라진다.** 그래서 긴 타이머는 진행 중에도 절대 각도를 유지한다.
    static func usesAbsoluteCoordinates(isRunning: Bool, configuredSeconds: Int) -> Bool {
        !isRunning || configuredSeconds > TimeMapper.secondsPerLap
    }

    /// 그릴 길이를 두 줄로 나눈다 — 한 바퀴까지는 바깥 줄, 넘어간 만큼이 안쪽 줄.
    /// - Parameter laps: 그릴 총 길이(바퀴 수).
    static func rows(laps: CGFloat) -> (outer: CGFloat, inner: CGFloat) {
        let total = max(0, laps)
        return (outer: min(1, total), inner: min(1, max(0, total - 1)))
    }
}
