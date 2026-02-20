//
//  TokiAlarmBundle.swift
//  TokiAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import WidgetKit
import SwiftUI

@main
struct TokiAlarmBundle: WidgetBundle {
    var body: some Widget {
        TokiAlarm()
        TokiAlarmControl()
        TokiAlarmLiveActivity()
    }
}
