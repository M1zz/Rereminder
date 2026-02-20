//
//  RereminderAlarmBundle.swift
//  RereminderAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import WidgetKit
import SwiftUI

@main
struct RereminderAlarmBundle: WidgetBundle {
    var body: some Widget {
        RereminderAlarm()
        RereminderAlarmControl()
        RereminderAlarmLiveActivity()
    }
}
