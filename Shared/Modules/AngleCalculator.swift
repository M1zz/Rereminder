//
//  AngleCalculator.swift
//  Rereminder
//
//  시간 ↔ 각도 변환 유틸리티 (순수 함수)
//  TimerScreenViewModel에서 분리
//

import Foundation

enum TimeMapper {
    static let secondsPerDegree = 10.0  // 1° = 10초
    static let maxSeconds = 7200        // 120분
    static let maxAngle = Double(maxSeconds) / secondsPerDegree  // 720도 (2바퀴)
    static let tickCount = 60
    /// 한 바퀴에 담기는 시간(초) — 1° = 10초 × 360°. "60분을 넘었나"를 묻는 곳이 전부 이 값을 본다.
    static let secondsPerLap = Int(secondsPerDegree) * 360

    /// 분 단위 상한 — 수동 입력 피커처럼 "몇 분까지 고를 수 있나"를 묻는 곳은 전부 이 값을 본다.
    ///
    /// ⚠️ 여기 말고 다른 데서 60 을 따로 적어 두면, 다이얼로 110분을 맞춘 뒤 수동 입력을 열었을 때
    ///    현재 값(110)이 목록에 없어 휠이 아무 반응도 하지 않는다. 실제로 났던 버그다.
    static var maxMinutes: Int { maxSeconds / 60 }

    /// 분·초 입력을 다이얼이 받을 수 있는 범위로 자른다.
    /// 초는 0~59, 합계는 `maxSeconds` 를 넘지 않는다(넘으면 상한 시각으로 맞춘다).
    static func clampedInput(minutes: Int, seconds: Int) -> (minutes: Int, seconds: Int) {
        let safeSeconds = max(0, min(59, seconds))
        let total = min(maxSeconds, max(0, minutes) * 60 + safeSeconds)
        return (total / 60, total % 60)
    }

    /// 알림이 걸려 있을 때 설정할 수 있는 **가장 짧은 시간**(초).
    ///
    /// 알림은 "종료 N분 전"이라 전체 시간보다 짧아야만 존재할 수 있다. 그래서 전체 시간을
    /// 알림 지점보다 짧게 줄이면 그 알림이 조용히 사라진다 — 사용자는 알림을 지운 적이 없는데.
    /// 줄이는 쪽을 여기서 막고, 지우려면 알림을 먼저 끄게 한다.
    ///
    /// 가장 이른 알림(= 가장 큰 offset)보다 한 칸(10초) 더 길어야 그 알림이 살아남는다.
    static func minimumSeconds(forAlertOffsets offsets: Set<Int>) -> Int {
        guard let earliest = offsets.filter({ $0 > 0 }).max() else { return 0 }
        return min(maxSeconds, earliest + Int(secondsPerDegree))
    }

    /// 초 → "M:SS" (분에 0을 채우지 않는 짧은 표기 — 칩·배지처럼 자리가 좁은 곳)
    /// 0을 채우는 "MM:SS" 는 `formatTime(minutes:seconds:)`.
    static func mmss(_ seconds: Int) -> String {
        let total = max(0, seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func secondsToAngle(from s: Int) -> Double {
        let clamped = max(0, min(s, maxSeconds))
        return Double(clamped) / secondsPerDegree
    }

    static func angleToSeconds(from a: Double) -> Int {
        let clamped = max(0, min(a, maxAngle))
        return Int(round(clamped)) * Int(secondsPerDegree)
    }

    /// 드래그 시 스냅 처리 (가장 가까운 정수 각도로)
    static func snappedAngle(from rawAngle: Double) -> Double {
        let totalSeconds = rawAngle * secondsPerDegree
        let snappedSeconds = (totalSeconds / secondsPerDegree).rounded() * secondsPerDegree
        return snappedSeconds / secondsPerDegree
    }

    /// 드래그 제스처에서 새 각도 계산
    static func angleDelta(from location: CGPoint, currentAngle: Double) -> Double {
        let vector = CGVector(dx: location.x, dy: location.y)
        let radians = atan2(vector.dy, vector.dx)
        var newAngle = radians * 180 / .pi
        if newAngle < 0 { newAngle = 360 + newAngle }

        var d = newAngle - fmod(currentAngle, 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }

        var next = currentAngle + d
        if next > maxAngle { next = maxAngle }
        if next < 0 { next = 0 }

        return snappedAngle(from: next)
    }

    // MARK: - 드래그 각도 추적
    //
    // `angleDelta` 는 "지금 표시 중인 각도"를 기준으로 최단 방향을 찾는다.
    // 그런데 그 각도는 범위 밖으로 못 나가게 잘린 값이라, 손가락이 범위를 크게 벗어나면
    // 최단 방향이 뒤집혀 핸들이 반대편으로 순간이동한다.
    // (예: 종을 총 시간 너머로 계속 끌면 0 으로 튐 / 흰 핸들을 0 아래로 끌면 30분으로 튐)
    //
    // 아래 두 함수는 **자르지 않은 손가락 각도만** 이어 붙인다.
    // 잘린 값이 되먹이지 않으므로 튈 일이 없고, 자르는 건 화면에 그릴 때 한 번만 하면 된다.

    /// 원 중심 기준 좌표 → 링 각도 (12시 = 0°, 시계 방향, 0~360)
    static func ringAngle(at point: CGPoint, center: CGPoint) -> Double {
        let radians = atan2(point.y - center.y, point.x - center.x)
        let angle = radians * 180 / .pi + 90
        let wrapped = angle.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// 0~360 각도를 직전 각도에 이어 붙인다 (359° → 1° 를 -358° 가 아니라 +2° 로 읽는다).
    /// 반환값은 자르지도 스냅하지도 않은 연속 각도라 두 바퀴째까지 그대로 이어진다.
    static func unwrappedAngle(_ angle: Double, continuing previous: Double) -> Double {
        let remainder = previous.truncatingRemainder(dividingBy: 360)
        let previousInCircle = remainder < 0 ? remainder + 360 : remainder

        var delta = angle - previousInCircle
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }

        return previous + delta
    }

    /// 초 → "MM:SS" 포맷
    static func formatTime(minutes: Int, seconds: Int) -> String {
        String(format: "%02d:%02d", minutes, seconds)
    }

    /// TimeInterval → "MM:SS" (오버타임 시 +MM:SS)
    static func formatRemaining(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        if total < 0 {
            let absTotal = abs(total)
            return String(format: "+%02d:%02d", absTotal / 60, absTotal % 60)
        } else {
            return String(format: "%02d:%02d", total / 60, total % 60)
        }
    }
}
