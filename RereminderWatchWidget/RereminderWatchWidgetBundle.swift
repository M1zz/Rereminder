//
//  RereminderWatchWidgetBundle.swift
//  RereminderWatchWidget
//
//  워치 스마트 스택용 위젯 묶음.
//
//  ⚠️ 이 확장은 **워치 앱 안에** 임베드된다(`RereminderWatch.app/PlugIns/`).
//     아이폰 쪽 위젯(`RereminderAlarm`)과는 별개다 — 워치는 워치 앱의 확장만 스마트 스택에
//     올릴 수 있어서, 아이폰 위젯을 아무리 고쳐도 손목에는 나타나지 않는다.
//

import SwiftUI
import WidgetKit

@main
struct RereminderWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        RereminderWatchTimerWidget()
    }
}
