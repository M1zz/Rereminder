//
//  AngleCalculator.swift
//  Toki
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
