//
//  LiveActivityIntents.swift
//  Rereminder
//
//  다이나믹 아일랜드·잠금화면의 일시정지·재개·정지 버튼.
//
//  ⚠️ **이 파일은 앱 타겟과 위젯 확장 타겟 양쪽에서 컴파일되어야 한다.**
//
//  왜 — `LiveActivityIntent` 는 위젯 확장이 아니라 **앱 프로세스**에서 실행된다(Apple 문서:
//  "the system runs the app intent in the app's process. Make sure to add your custom app intent
//  to your app target"). 그래서 인텐트 타입이 확장 타겟에만 있으면 시스템이 앱에서 그 인텐트를
//  찾지 못해 **버튼을 눌러도 아무 일도 일어나지 않는다.** 2.2.0 까지 재생·정지가 죽어 있던 이유다.
//  (확장 타겟에도 있어야 하는 건 위젯의 `Button(intent:)` 가 타입을 참조하기 때문. 양쪽에 있으면
//   Apple 은 앱 쪽 것을 실행한다.)
//
//  검증법 — 빌드한 뒤 `Rereminder.app/Metadata.appintents/extract.actionsdata` 안에
//  `PauseIntent`·`ResumeIntent`·`StopIntent` 가 들어 있는지 확인한다. 확장(appex)에만 있으면 깨진 것이다.
//
//  버튼이 하는 일은 두 겹이다:
//   ① 앱이 살아 있으면 그 자리에서 진짜로 멈춘다(알림 스케줄 취소까지 — `LiveActivityCommand.dispatch`)
//   ② 앱이 아직 화면을 만들지 않았다면 명령을 앱 그룹에 남겨 두고, 표시만 먼저 바꾼다
//      (다음에 앱이 앞으로 나올 때 `applyPendingLiveActivityCommand` 가 적용한다)
//

import AppIntents

#if os(iOS) && !targetEnvironment(macCatalyst)

struct PauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause"
    static var description = IntentDescription("Pause the timer")

    // 쓰이지 않지만 호출부(위젯의 Button)가 넘기는 값 — 기본값이 있어야 시스템이 값을 되묻지 않는다
    @Parameter(title: "alarmID", default: "")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    @MainActor
    func perform() async throws -> some IntentResult {
        // 앱이 그 자리에서 처리하지 못했을 때만 표시를 앞질러 바꾼다 —
        // 처리했다면 진짜 상태로 이미 갱신됐고, 여기서 덮으면 오히려 값이 어긋난다.
        if !LiveActivityCommand.pause.dispatch() {
            LiveActivityController.markPaused()
        }
        return .result()
    }
}

struct ResumeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"
    static var description = IntentDescription("Resume the timer")

    // 쓰이지 않지만 호출부(위젯의 Button)가 넘기는 값 — 기본값이 있어야 시스템이 값을 되묻지 않는다
    @Parameter(title: "alarmID", default: "")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    @MainActor
    func perform() async throws -> some IntentResult {
        if !LiveActivityCommand.resume.dispatch() {
            LiveActivityController.markResumed()
        }
        return .result()
    }
}

struct StopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var description = IntentDescription("Stop the timer")

    // 쓰이지 않지만 호출부(위젯의 Button)가 넘기는 값 — 기본값이 있어야 시스템이 값을 되묻지 않는다
    @Parameter(title: "alarmID", default: "")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }

    @MainActor
    func perform() async throws -> some IntentResult {
        // 정지는 눌렀으면 사라져야 한다 — 앱이 못 받았어도 활동은 여기서 끝낸다.
        if !LiveActivityCommand.stop.dispatch() {
            LiveActivityController.endAll()
        }
        return .result()
    }
}

#endif
