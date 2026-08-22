//
//  AppIntent.swift
//  RereminderAlarm
//
//  Created by hyunho lee on 11/20/25.
//

import WidgetKit
import AppIntents
import ActivityKit

// MARK: - Live Activity Intents
//
// ⚠️ 일시정지·재개·정지 인텐트는 여기 없다 — `Shared/Intents/LiveActivityIntents.swift` 로 옮겼다.
//    `LiveActivityIntent` 는 **앱 프로세스**에서 실행되므로 확장 타겟에만 두면 버튼이 죽는다.
//    (그 파일은 앱·확장 양쪽 멤버십을 갖는다. 옮기지 말 것.)

struct OpenAlarmAppIntent: LiveActivityIntent {
    func perform() throws -> some IntentResult {
        // 앱만 열고 타이머는 중지하지 않음
        return .result()
    }

    static var title: LocalizedStringResource = "Open App"
    static var description = IntentDescription("Open Rereminder app")
    static var openAppWhenRun = true

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }
}
