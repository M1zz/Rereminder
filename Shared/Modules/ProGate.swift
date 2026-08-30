//
//  ProGate.swift
//  Rereminder
//
//  무료/Pro 기능 제한 게이트 (5+5 trial 모델)
//
//  **파는 축은 "알림 개수"가 아니라 "세션 운영"이다.**
//
//  왜 바꿨나: 이 앱이 기본 시계 앱 대신 설치될 이유는 "끝나기 전에 여러 번 알려 준다" 하나뿐인데,
//  바로 그것을 개수로 세면 무료 사용자가 손에 쥔 것은 **기능적으로 기본 타이머**다. 결제는
//  잔존 위에서만 일어나는데, 잔존이 생길 자리를 게이트가 먼저 막고 있었다. 게다가 그 벽에
//  걸리는 사람은 **발표자·강사·퍼실리테이터**(= 실제로 돈을 낼 사람)이고, 25/5로 고정된
//  포모도로 사용자는 알림 2개로 충분해 페이월을 한 번도 보지 않았다 — 정확히 반대로 작동했다.
//
//  잠금 원칙:
//  - 무료: 타이머, **예비 알림 무제한**, Live Activity, 소리/진동, Watch, 위젯, 커스텀 메시지,
//    테마/라벨 색상. ⚠️ **워치·맥을 유료로 돌리지 말 것** — 수업 중 강사 손목에서 진동하는
//    워치 화면은 다른 강사에게 보이는 유일한 광고다. 막으면 획득 경로를 스스로 끊는다.
//  - Pro 가 파는 한 문장은 **"앱이 당신의 설정을 기억한다"**이다.
//    템플릿 저장·불러오기 + **마지막 설정 복원**이 그 문장의 알맹이고, 세션 모드(구간 이름·대본)·
//    오버타임·기록도 같은 Pro 안에 있다. 게이트는 흩어지지 않고 여기 하나로 통일된다.
//
//  ⚠️ **무료 사용자는 앱을 껐다 켜면 다이얼이 기본값으로 돌아온다**(`ProGate.canRememberSetup`).
//     백그라운드에 다녀오는 것은 초기화하지 않는다 — 그건 제한이 아니라 고장으로 읽힌다.
//
//  ⚠️ 이름은 "발표 모드"가 아니라 **"세션 모드"**다. 필라테스 강사는 "발표 모드"를 보고 자기
//     것이라고 생각하지 않는데, 실제로는 그가 이 기능의 주 사용자다("세션"은 강사·트레이너가
//     쓰는 말이고 학회 발표자에게도 통한다). 코드 식별자(`presentationMode`)는 계약이라 그대로다.
//
//  5+5 trial:
//  - presentationMode, overtimeTracking, timerHistory 에 적용
//  - unlimitedTemplates 는 슬롯 개념이라 hard gate 유지 (3개 free)
//

import Foundation

enum ProGate {

    // MARK: - Pro 기능 정의

    enum Feature: String, CaseIterable {
        /// 세션 모드 — 구간 이름·대본. ⚠️ `rawValue`("presentationMode")는 **바꾸지 말 것**:
        /// 분석 이벤트 슬라이스(`paywall_shown:presentationMode`)와 스냅샷이 이 문자열을 쓴다.
        /// 사람에게 보이는 이름만 "세션 모드"다.
        case presentationMode
        case overtimeTracking         // 오버타임 카운트
        /// **기억하기** — 템플릿 저장·불러오기 + 마지막 설정 복원.
        /// ⚠️ `rawValue`("unlimitedTemplates")는 **바꾸지 말 것**: 분석 이벤트 슬라이스와
        /// 스냅샷이 이 문자열을 쓴다. 파는 것이 "개수"에서 "기억"으로 바뀌었을 뿐이다.
        case unlimitedTemplates
        case timerHistory             // 타이머 사용 통계

        var displayName: String {
            switch self {
            case .presentationMode:       return "Session Mode"
            case .overtimeTracking:       return "Overtime Tracking"
            case .unlimitedTemplates:     return "Saved setups"
            case .timerHistory:           return "Timer History & Stats"
            }
        }

        var icon: String {
            switch self {
            case .presentationMode:       return "person.and.background.dotted"
            case .overtimeTracking:       return "timer.circle.fill"
            case .unlimitedTemplates:     return "bookmark.fill"
            case .timerHistory:           return "chart.bar.fill"
            }
        }

        /// 5+5 trial 적용 대상인지 (slot 기반 templates 는 제외)
        var supportsTrial: Bool {
            switch self {
            case .unlimitedTemplates: return false
            default: return true
            }
        }
    }

    // MARK: - Free Limits

    // ⚠️ **예비 알림에는 한도가 없다.** 예전에 있던 `freePrealertLimit` 은 삭제됐다 —
    //    되살리지 말 것. 그 한도는 이 앱을 설치할 이유 자체를 무료 사용자에게서 빼앗았고,
    //    벽에 걸리는 사람이 하필 결제 가능성이 가장 큰 사람(발표자·강사·퍼실리테이터)이었다.
    //    자세한 근거는 파일 머리말 참고.
    //
    // ⚠️ 템플릿에도 **무료 몫이 없다**(예전의 `freeTemplateLimit = 3` 은 삭제). 저장·불러오기
    //    자체가 Pro 다 — 그게 이제 이 앱이 파는 한 문장이기 때문이다. 개수로 다시 나누지 말 것.

    // MARK: - Gate Result

    enum PaywallStage: String {
        case first   // 5회 후 1차 페이월
        case second  // 10회 후 2차 페이월
    }

    enum GateResult {
        case allowed                                                    // Pro 사용자
        case allowedWithTrial(remaining: Int, stage: PaywallStage)      // 무료, 체험 가능
        case blocked(stage: PaywallStage)                               // 페이월 표시 필요

        var isAllowed: Bool {
            switch self {
            case .allowed, .allowedWithTrial: return true
            case .blocked: return false
            }
        }

        var trialRemaining: Int? {
            if case .allowedWithTrial(let r, _) = self { return r }
            return nil
        }
    }

    // MARK: - Evaluate (5+5 logic)

    static func evaluate(_ feature: Feature) -> GateResult {
        if StoreManager.isProUser { return .allowed }

        // Trial 미지원 기능은 무조건 blocked
        guard feature.supportsTrial else {
            return .blocked(stage: .first)
        }

        let used = TrialCounter.count(for: feature)
        let firstLimit = TrialCounter.firstStageLimit
        let secondLimit = TrialCounter.secondStageLimit
        let extended = TrialCounter.extensionAccepted(for: feature)

        if used < firstLimit {
            return .allowedWithTrial(remaining: firstLimit - used, stage: .first)
        }
        if used < secondLimit && extended {
            return .allowedWithTrial(remaining: secondLimit - used, stage: .second)
        }
        if used < secondLimit && !extended {
            return .blocked(stage: .first)
        }
        return .blocked(stage: .second)
    }

    /// 사용자가 기능을 실제로 사용했을 때 호출 (Pro면 no-op)
    static func recordUsage(_ feature: Feature) {
        guard !StoreManager.isProUser else { return }
        guard feature.supportsTrial else { return }
        TrialCounter.increment(feature)
        AnalyticsManager.log(.premiumFeatureUsed(
            feature: feature,
            trialCount: TrialCounter.count(for: feature)
        ))
    }

    /// 1차 페이월에서 "5번 더 체험" 수락
    static func acceptExtendedTrial(_ feature: Feature) {
        guard feature.supportsTrial else { return }
        TrialCounter.acceptExtension(for: feature)
    }

    // MARK: - Legacy Bool API (호환성 유지)

    static func isAvailable(_ feature: Feature) -> Bool {
        evaluate(feature).isAllowed
    }

    /// **앱이 설정을 기억해도 되는가** — 템플릿 저장·불러오기와 마지막 설정 복원의 단일 판정.
    ///
    /// 체험(5+5)이 없는 hard gate 다. "몇 번 더 써 보세요"가 성립하지 않는 종류의 기능이라
    /// (기억은 쌓여야 값이 나오는데 체험이 끝나면 쌓인 것이 사라진다) 처음부터 명확히 가른다.
    static var canRememberSetup: Bool { StoreManager.isProUser }

    /// 템플릿 저장 가능 여부. ⚠️ 개수는 보지 않는다 — 저장 자체가 Pro 다.
    static func canSaveTemplate(currentCount: Int = 0) -> Bool { canRememberSetup }

    /// 발표 모드 사용 가능 여부
    static var canUsePresentationMode: Bool {
        evaluate(.presentationMode).isAllowed
    }

    /// 오버타임 추적 사용 가능 여부
    static var canUseOvertime: Bool {
        evaluate(.overtimeTracking).isAllowed
    }

    /// 타이머 통계 사용 가능 여부
    static var canUseHistory: Bool {
        evaluate(.timerHistory).isAllowed
    }
}
