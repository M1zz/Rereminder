//
//  FeatureTips.swift
//  Rereminder
//
//  "이런 것도 있어요"를 **적절한 때에만** 알려주는 TipKit 팁 모음.
//
//  원칙 — 팁은 광고가 아니라 도움이어야 한다:
//   • 앱을 실제로 써 본 뒤에 뜬다(타이머를 몇 번 돌린 다음). 첫 화면에서 쏟아내지 않는다.
//   • 이미 그 기능을 쓰고 있으면 뜨지 않는다(`hasUsed*` 파라미터로 스스로 사라진다).
//   • 한 화면에 하나씩. TipKit 이 표시 빈도를 관리한다(RereminderApp 의 Tips.configure).
//
//  기기별 활용 안내(워치·맥·위젯)는 이 팁들이 아니라 온보딩 마지막 장과
//  설정 > Help > "모든 기기에서 사용하기" 가 담당한다.
//

import SwiftUI
import TipKit

// MARK: - 발표 모드

/// 타이머를 몇 번 써 본 사람에게 "구간을 나눠 쓰는 법"을 알려준다.
/// 발표 모드는 이 앱에서 가장 값이 큰 기능인데, 하단 세그먼트를 눌러 보지 않으면 존재를 모른다.
@available(iOS 17.0, *)
struct PresentationModeTip: Tip {
    /// 타이머를 끝까지 마친 순간 (완주해 본 사람에게만 다음 단계를 권한다)
    static let timerCompleted = Event(id: "featureTip.timerCompleted")

    /// 발표 모드를 한 번이라도 쓰면 다시 뜨지 않는다
    @Parameter static var hasUsedPresentationMode: Bool = false

    var title: Text { Text("tip_presentation_title") }
    var message: Text? { Text("tip_presentation_message") }
    var image: Image? { Image(systemName: "person.and.background.dotted") }

    var rules: [Rule] {
        #Rule(Self.$hasUsedPresentationMode) { $0 == false }
        #Rule(Self.timerCompleted) { $0.donations.count >= 2 }
    }
}

// MARK: - 템플릿 저장

/// 같은 설정을 자꾸 다시 맞추는 사람에게 저장을 권한다.
/// 저장을 한 번이라도 해 봤으면 뜨지 않는다.
@available(iOS 17.0, *)
struct SaveTemplateTip: Tip {
    /// 타이머를 시작한 순간 (설정을 손으로 맞춘 흔적)
    static let timerStarted = Event(id: "featureTip.timerStarted")

    @Parameter static var hasSavedTemplate: Bool = false

    var title: Text { Text("tip_template_title") }
    var message: Text? { Text("tip_template_message") }
    var image: Image? { Image(systemName: "square.and.arrow.down.fill") }

    var rules: [Rule] {
        #Rule(Self.$hasSavedTemplate) { $0 == false }
        #Rule(Self.timerStarted) { $0.donations.count >= 3 }
    }
}

// MARK: - 도너 (앱 어디서든 한 줄로 부를 수 있게)

enum FeatureTips {
    /// 타이머를 끝까지 마쳤다.
    static func donateTimerCompleted() {
        guard #available(iOS 17.0, *) else { return }
        Task { await PresentationModeTip.timerCompleted.donate() }
    }

    /// 타이머를 시작했다.
    static func donateTimerStarted() {
        guard #available(iOS 17.0, *) else { return }
        Task { await SaveTemplateTip.timerStarted.donate() }
    }

    /// 발표 모드를 실제로 썼다 — 관련 팁을 더는 띄우지 않는다.
    static func markPresentationModeUsed() {
        guard #available(iOS 17.0, *) else { return }
        PresentationModeTip.hasUsedPresentationMode = true
    }

    /// 템플릿을 저장했다.
    static func markTemplateSaved() {
        guard #available(iOS 17.0, *) else { return }
        SaveTemplateTip.hasSavedTemplate = true
    }
}
