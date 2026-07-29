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
