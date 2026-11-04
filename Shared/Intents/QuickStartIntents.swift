//
//  QuickStartIntents.swift
//  Rereminder
//
//  제어센터 버튼·홈 화면 위젯 버튼이 저장한 설정을 바로 시작한다(`QuickStartShelf`).
//
//  ⚠️ **앱 타겟과 위젯 확장 양쪽에서 컴파일된다.** 포그라운드 모드 인텐트는 시스템이 **앱 프로세스**
//     에서 실행하므로 앱 타겟에 타입이 없으면 눌러도 아무 일도 일어나지 않는다(오류도 로그도 없다).
//     확장에도 있어야 컨트롤·위젯이 타입을 참조할 수 있다. 확장 멤버십은 pbxproj 의
//     `Exceptions for "Shared" folder in "RereminderAlarmExtension" target` 에 있다.
//  ⚠️ `openAppWhenRun` 이 아니라 `supportedModes` 다 — iOS 26 SDK 에서 앞의 것은 무시된다.
//     (클립키보드 `docs/engineering/CONTROL_CENTER_APP_LAUNCH.md`)
//  ⚠️ 이 타입의 이름·매개변수를 바꾸면 `QuickStartShelf.controlKind` 도 올릴 것 — 시스템이 이미
//     추가된 컨트롤을 옛 인텐트에 묶어 둔 채로 죽인다.
//
//  왜 앱을 여나: 시작은 권한 경고·Live Activity·알림 예약·기록이 한 길(`apply(template:)`)에 묶여
//  있다. 화면 없이 시작하는 길을 따로 만들면 두 길이 언젠가 갈라진다. 이 앱은 도는 동안 화면을
//  보는 앱이기도 하다.
//

import AppIntents
import Foundation

struct StartSavedSetupIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a saved setup"
    static let description = IntentDescription("Starts a saved setup right away.")
    static var supportedModes: IntentModes { .foreground }
    /// 단축어 앱에 id 문자열 칸이 그대로 보이므로 내놓지 않는다 — 버튼 전용이다.
    static let isDiscoverable = false

    /// `Timer.id` 문자열. 비어 있으면 앱만 연다(저장한 설정이 아직 없는 사람).
    @Parameter(title: "Saved setup", description: "The saved setup to start.")
    var templateID: String

    init() { self.templateID = "" }
    init(templateID: String) { self.templateID = templateID }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard !templateID.isEmpty else { return .result() }
        // 콜드 런치 대비 기록 + 이미 떠 있는 화면 대비 알림, 둘 다 건다(받는 쪽은 기록을 꺼내므로 한 번만 돈다).
        QuickStartShelf.request(templateID: templateID)
        NotificationCenter.default.post(name: .quickStartRequested, object: nil)
        return .result()
    }
}
