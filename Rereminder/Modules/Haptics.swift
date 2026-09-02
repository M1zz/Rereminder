//
//  Haptics.swift
//  Rereminder
//
//  다이얼을 돌릴 때 손끝에 오는 감각.
//
//  왜 필요한가: 이 앱의 조작은 **원 위에서 각도로** 이뤄진다. 손가락이 링을 덮고 있어서 방금
//  몇 초를 지났는지 눈으로 확인하기 어렵고, 값은 10초 단위로 스냅되는데 그 순간이 화면에만
//  나타난다. 물리 다이얼이라면 딸깍 하고 걸리는 자리다 — 그 딸깍이 없으니 사용자는 자기가
//  값을 바꾸고 있는지조차 손으로 알 수 없다("Haptics are needed when adjusting timer").
//
//  ⚠️ **끌 때마다 울리지 말고 값이 바뀔 때만 울린다.** 각도는 손가락을 따라 연속으로 변하므로
//     각도에 반응시키면 초당 수십 번 울려 손목이 저리고 배터리를 먹는다. 기준은 언제나
//     **스냅된 값**(`TimeMapper.angleToSeconds`)이다 — 그래서 한 칸 지날 때 한 번 온다.
//
//  ⚠️ 끄고 켤 수 있어야 한다(`Haptics.isEnabled`). 진동을 싫어하는 사람과 배터리를 아끼는
//     사람이 있고, 무엇보다 **강의 중에 손목이 계속 떨리면 그건 방해다.**
//

import SwiftUI

enum Haptics {

    /// 설정 키. ⚠️ 설정 화면(`FeatureIntroView`·`NoticeSettingView`)과 같은 이름을 써야 한다.
    static let enabledKey = "hapticsEnabled"

    /// 기본값은 **켜짐**이다 — iOS 에서 다이얼을 돌리면 딸깍하는 것이 기본 기대치이고,
    /// 지금까지 없던 것이 결함으로 읽혔다.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }
}

extension View {

    /// 다이얼 값이 **한 칸 바뀔 때마다** 딸깍. 값이 없을 때(드래그 중이 아닐 때)는 울리지 않는다.
    ///
    /// - Parameter value: **스냅된** 값을 넘길 것 (각도가 아니라). 드래그 중이 아니면 `nil`.
    func dialTickFeedback(_ value: Int?) -> some View {
        sensoryFeedback(trigger: value) { old, new in
            guard Haptics.isEnabled else { return nil }
            // 드래그를 시작·끝낼 때(nil 경계)는 울리지 않는다 — 잡는 순간의 딸깍은
            // 아래 `grabFeedback` 이 따로 맡는다.
            guard old != nil, new != nil else { return nil }
            return .selection
        }
    }

    /// 잡을 때·놓을 때. 값이 바뀌지 않아도 "잡혔다"는 것은 손으로 알아야 한다.
    func dialGrabFeedback(isDragging: Bool) -> some View {
        sensoryFeedback(trigger: isDragging) { _, nowDragging in
            guard Haptics.isEnabled else { return nil }
            // 잡을 때는 가볍게, 놓을 때는 값이 스냅되므로 조금 더 또렷하게.
            return nowDragging ? .impact(weight: .light, intensity: 0.6) : .impact(weight: .medium)
        }
    }

    /// 버튼처럼 한 번 눌러 값이 바뀌는 자리(프리셋·초기화).
    func tapFeedback<T: Equatable>(_ value: T) -> some View {
        sensoryFeedback(trigger: value) { _, _ in
            Haptics.isEnabled ? .impact(weight: .light) : nil
        }
    }
}
