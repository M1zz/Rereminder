//
//  PresetStore.swift
//  Rereminder
//
//  사용자가 직접 설정하는 빠른설정 / 예비알림 프리셋을 영구 저장한다.
//

import Foundation
import Combine

/// 빠른설정(분 단위)·예비알림(초 단위) 프리셋을 사용자별로 저장·관리
final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    /// 빠른설정 기본값 (3개)
    static let defaultQuickMinutes = [5, 10, 15]
    /// 예비알림 기본값 (1분, 3분, 5분)
    static let defaultPrealertSec = [60, 180, 300]

    private let quickKey = "userQuickPresetsMin"
    private let prealertKey = "userPrealertPresetsSec"

    /// 빠른설정 프리셋 (항상 3개 유지)
    @Published var quickMinutes: [Int] {
        didSet { UserDefaults.standard.set(quickMinutes, forKey: quickKey) }
    }

    /// 예비알림 프리셋 (오름차순 정렬, 추가/삭제 가능)
    @Published var prealertSeconds: [Int] {
        didSet { UserDefaults.standard.set(prealertSeconds, forKey: prealertKey) }
    }

    private init() {
        let defaults = UserDefaults.standard
        if let q = defaults.array(forKey: quickKey) as? [Int], !q.isEmpty {
            quickMinutes = q
        } else {
            quickMinutes = Self.defaultQuickMinutes
        }
        if let p = defaults.array(forKey: prealertKey) as? [Int], !p.isEmpty {
            prealertSeconds = p
        } else {
            prealertSeconds = Self.defaultPrealertSec
        }
    }

    /// 빠른설정 특정 슬롯의 시간을 변경 (1~120분으로 클램프)
    func setQuickMinutes(_ minutes: Int, at index: Int) {
        guard quickMinutes.indices.contains(index) else { return }
        quickMinutes[index] = max(1, min(120, minutes))
    }

    /// 예비알림 프리셋 추가 (중복 무시, 5초~120분 클램프, 정렬 유지)
    func addPrealert(seconds: Int) {
        let s = max(5, min(7200, seconds))
        guard !prealertSeconds.contains(s) else { return }
        prealertSeconds = (prealertSeconds + [s]).sorted()
    }

    /// 예비알림 프리셋 삭제
    func removePrealert(seconds: Int) {
        prealertSeconds.removeAll { $0 == seconds }
    }
}
