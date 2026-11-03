//
//  QuickStartControl.swift
//  RereminderAlarm
//
//  제어센터 버튼 — 저장한 설정 하나를 눌러 바로 시작한다(`StartSavedSetupIntent`).
//  길게 눌러 어느 설정인지 고르고, 고르지 않았으면 가장 자주 쓰는 것이다(`QuickStartShelf`).
//
//  ⚠️ 2.3.5 까지 있던 `RereminderAlarmControl` 은 Xcode 템플릿 그대로였고, 인텐트가 확장에만 있고
//     `openAppWhenRun` 을 써서 iOS 26 에서는 눌러도 아무 일도 없었다. 그 kind 는 다시 쓰지 않는다.
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - 고르기

struct QuickStartEntity: AppEntity {
    let id: String
    let name: String
    let durationText: String

    init(_ item: QuickStartItem) {
        id = item.id
        name = item.name
        durationText = item.durationText
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Saved setup")
    }

    var displayRepresentation: DisplayRepresentation {
        // 사용자가 지은 이름이라 번역하지 않는다 — 리터럴로 쓰면 "%@" 가 카탈로그에 추출된다.
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name),
                              subtitle: LocalizedStringResource(stringLiteral: durationText))
    }

    static var defaultQuery = QuickStartEntityQuery()
}

struct QuickStartEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [QuickStartEntity] {
        QuickStartShelf.items.filter { identifiers.contains($0.id) }.map(QuickStartEntity.init)
    }

    func suggestedEntities() async throws -> [QuickStartEntity] {
        QuickStartShelf.items.map(QuickStartEntity.init)
    }

    func defaultResult() async -> QuickStartEntity? {
        QuickStartShelf.items.first.map(QuickStartEntity.init)
    }
}

struct QuickStartControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Choose a saved setup"

    @Parameter(title: "Saved setup")
    var setup: QuickStartEntity?
}

// MARK: - 버튼

struct QuickStartControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: QuickStartShelf.controlKind, provider: Provider()) { value in
            ControlWidgetButton(action: StartSavedSetupIntent(templateID: value.id)) {
                Label(value.title, systemImage: "timer")
                Text(value.subtitle)
            }
        }
        .displayName("Start a saved setup")
        .description("Starts a saved setup right away.")
    }

    struct Value {
        let id: String
        let title: String
        let subtitle: String
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: QuickStartControlConfiguration) -> Value {
            value(for: configuration)
        }

        func currentValue(configuration: QuickStartControlConfiguration) async throws -> Value {
            value(for: configuration)
        }

        /// 고른 것이 지워졌거나 아직 고르지 않았으면 가장 자주 쓰는 것으로 — 추가하자마자 쓸 수 있어야 한다.
        /// 저장한 설정이 하나도 없으면 앱만 연다.
        private func value(for configuration: QuickStartControlConfiguration) -> Value {
            let items = QuickStartShelf.items
            let picked = configuration.setup.flatMap { setup in items.first { $0.id == setup.id } }
            guard let item = picked ?? items.first else {
                return Value(id: "", title: String(localized: "Start a saved setup"), subtitle: "")
            }
            // 시간이 제목이다 — 앱이 지은 이름이면 `name` 은 알림 시각뿐이다(`QuickStartPublisher.tileName`).
            return Value(id: item.id, title: item.durationText, subtitle: item.name)
        }
    }
}
