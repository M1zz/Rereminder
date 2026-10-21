//
//  RereminderRoadmap.swift
//  Rereminder
//
//  **앞으로 만들 것**의 원본. 설정 ▸ 앞으로 만들 기능(`LeeoRoadmapView`)이 이 목록을 그대로 보여 준다.
//
//  ⚠️ 개발하다 "이건 다음에" 가 생기면 **여기에 한 줄을 더한다.** 코드의 TODO 주석으로만 남기지 않는다.
//     - 새 항목: `.planned`. 손대기 시작하면 `.building`. 내보내면 `.shipped("3.1.0")`.
//     - id 는 한 번 정하면 바꾸지 않는다(문구는 바꿔도 된다).
//     - 문구는 사용자 말로 쓴다(내부 이름 · 기술 용어 금지). 키는 영어, 번역은 `Localizable.xcstrings` 의 모든 언어에 넣는다.
//     - 사용자에게 보일 만한 것만 적는다. 리팩터링 · 시험 · 빌드 설정은 `.sprintcommander/tasks.json` 의 몫이다.
//

import SwiftUI
import LeeoKit

extension RereminderSpec {
    static var roadmap: [LeeoRoadmapItem] {[
        // MARK: 다음에 만들어요
        .init(id: "a11y.voiceover", status: .planned,
              title: String(localized: "Better VoiceOver support", comment: "Roadmap item: VoiceOver"),
              detail: String(localized: "VoiceOver reads every timer and button, in the right order.", comment: "Roadmap item detail: VoiceOver")),
        .init(id: "a11y.largetext", status: .planned,
              title: String(localized: "Ready for larger text", comment: "Roadmap item: larger text"),
              detail: String(localized: "Screens rearrange neatly when you make text bigger, with nothing cut off.", comment: "Roadmap item detail: larger text")),
        .init(id: "a11y.contrast", status: .planned,
              title: String(localized: "Easier-to-see colors", comment: "Roadmap item: color and contrast"),
              detail: String(localized: "Timers stay readable with Increase Contrast on or when colors are hard to tell apart.", comment: "Roadmap item detail: color and contrast")),
        .init(id: "a11y.keyboard", status: .planned,
              title: String(localized: "Keyboard controls", comment: "Roadmap item: keyboard control"),
              detail: String(localized: "Start, pause, and stop timers with just the keyboard on iPad and Mac.", comment: "Roadmap item detail: keyboard control")),
        .init(id: "gift", status: .building,
              title: String(localized: "Gift Pro", comment: "Roadmap item: gift Pro"),
              detail: String(localized: "You pay, and the person you choose gets to use Pro.", comment: "Roadmap item detail: gift Pro")),
        .init(id: "backup", status: .planned,
              title: String(localized: "Backup and export", comment: "Roadmap item: backup and export"),
              detail: String(localized: "Save your timers and history to a file and bring them back anytime.", comment: "Roadmap item detail: backup and export")),
        .init(id: "lock.faceid", status: .planned,
              title: String(localized: "Face ID lock", comment: "Roadmap item: Face ID lock"),
              detail: String(localized: "Lock the app with Face ID or Touch ID to keep your scripts and history private.", comment: "Roadmap item detail: Face ID lock")),
        .init(id: "data.delete", status: .planned,
              title: String(localized: "Delete all my data", comment: "Roadmap item: delete all data"),
              detail: String(localized: "Erase all your timers and history from inside the app whenever you want.", comment: "Roadmap item detail: delete all data")),
        // MARK: 만들었어요
        .init(id: "whatsnew", status: .shipped("2.3.4"),
              title: String(localized: "What's new after updates", comment: "Roadmap item: what's new"),
              detail: String(localized: "The first time you open the app after an update, see what's new.", comment: "Roadmap item detail: what's new")),
    ]}
}

// MARK: - 화면

/// 설정 ▸ 앞으로 만들 기능. "이런 기능이 있으면 좋겠어요" 는 피드백 창을 연다.
struct RoadmapScreen: View {
    @State private var showFeedback = false

    var body: some View {
        LeeoRoadmapView<RereminderSpec>(onSuggest: { showFeedback = true })
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
    }
}
