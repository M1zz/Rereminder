//
//  BlankStart.swift
//  Rereminder
//
//  **백지 첫 실행.** 새로 설치한 사람은 다이얼 하나로 시작하고, 나머지는 쓴 만큼 나타난다.
//
//  왜: 처음 연 사람이 알아야 할 것은 "끝나기 전에 미리 알려 준다" 하나뿐이다. 그때 프리셋 칩·템플릿·
//  모드 전환·기기 칩이 한꺼번에 보이면 그 하나가 묻힌다(클립키보드 `BlankStartView` 와 같은 생각).
//
//  단계(`Stage`): 다이얼 → 첫 완주 알림 더하기 → 둘째 완주 저장 → 셋째 완주 세션 모드 → 다섯째 완주 전부(기기 칩·기기 질문·팁)
//
//  ⚠️ **기존 사용자는 처음부터 전부 보인다.** 기능은 하나도 줄지 않고 화면 모양만 달라진다.
//     첫 완주 뒤에 "너무 복잡하지 않나요?"를 한 번 묻고, 원한 사람만 단순하게 본다(`Preference.simple`).
//     단순하게 봐도 써 본 세션 모드는 남고, 설정 ▸ 모든 기능 보기로 언제든 돌아온다.
//  ⚠️ 저절로는 드러난 것을 다시 감추지 않는다. 감추는 것은 사람이 고른 때뿐이다.
//  ⚠️ `isNewInstall` 은 한 번 정하면 바뀌지 않는다. 기능 수업도 새로 설치한 사람에게만 저절로 뜬다.
//

import Foundation

enum BlankStart {
    static let completionsKey = "blankStart.completions"
    static let preferenceKey = "blankStart.preference"
    private static let newInstallKey = "blankStart.isNewInstall"
    private static let complexityAskedKey = "blankStart.complexityAsked"
    private static let dialFillPlayedKey = "blankStart.dialFillPlayed"

    /// 화면에 얼마나 드러나 있는가. 뒤 단계는 앞 단계를 모두 포함한다.
    enum Stage: Int, Comparable {
        case dial, alerts, saving, session, everything

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }

        /// 완주 횟수로 정한다. **순수 함수.**
        static func forCompletions(_ completions: Int) -> Stage {
            switch completions {
            case ..<1: return .dial
            case 1: return .alerts
            case 2: return .saving
            case 3, 4: return .session
            default: return .everything
            }
        }
    }

    /// 사람이 고른 화면. 고르지 않았으면 `automatic` 이다.
    enum Preference: String {
        case automatic, simple, all
    }

    /// 화면이 보여 줄 단계. **순수 함수.**
    static func stage(isNewInstall: Bool, completions: Int, preference: Preference, hasUsedSession: Bool) -> Stage {
        switch preference {
        case .all: return .everything
        case .simple: return hasUsedSession ? .session : .saving
        case .automatic: return isNewInstall ? Stage.forCompletions(completions) : .everything
        }
    }

    /// 뷰는 `completionsKey`·`preferenceKey` 를 `@AppStorage` 로 들고 이걸 부른다. 값이 바뀌면 다시 그려야 한다.
    static func currentStage(completions: Int, preferenceRaw: String) -> Stage {
        stage(isNewInstall: isNewInstall,
              completions: completions,
              preference: Preference(rawValue: preferenceRaw) ?? .automatic,
              hasUsedSession: UsageMetrics.value(.presentationRuns) > 0)
    }

    /// 새로 설치한 사람인가. **순수 함수.**
    static func isNewInstall(hasSeenOnboarding: Bool, timerStarts: Double) -> Bool {
        !hasSeenOnboarding && timerStarts == 0
    }

    /// 이 설치가 백지로 시작했는가. 처음 읽을 때 정하고 적어 둔다.
    /// ⚠️ 실행당 한 번만 판정한다. 화면을 그리는 중에 읽는 값이라, 여기서 다시 저장하면 `@AppStorage` 가 다시 그리기를 불러 멈춘다.
    static let isNewInstall: Bool = {
        let defaults = UserDefaults.standard
        if let saved = defaults.object(forKey: newInstallKey) as? Bool { return saved }
        let decided = isNewInstall(hasSeenOnboarding: defaults.bool(forKey: "hasSeenOnboarding"),
                                   timerStarts: UsageMetrics.value(.timerStarts))
        defaults.set(decided, forKey: newInstallKey)
        return decided
    }()

    /// 끝까지 한 번 마쳤다.
    static func recordCompletion() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: completionsKey) + 1, forKey: completionsKey)
    }

    static var completions: Int { UserDefaults.standard.integer(forKey: completionsKey) }

    // MARK: - 다음에 배울 것

    /// 지금 배울 수업. 양보해서 놓친 수업은 다음 완주에 온다. 세션 모드는 들어갈 때 배운다. **순수 함수.**
    static func dueLesson(completions: Int, learned: Set<FeatureLesson>) -> FeatureLesson? {
        let schedule: [(FeatureLesson, Int)] = [(.moreAlerts, 1), (.templates, 2), (.overtime, 4)]
        return schedule.first { completions >= $0.1 && !learned.contains($0.0) }?.0
    }

    // MARK: - 너무 복잡하지 않나요?

    /// 기존 사용자에게 한 번만 묻는다. 새로 설치한 사람의 화면은 이미 단순하다. **순수 함수.**
    static func shouldAskComplexity(isNewInstall: Bool, preference: Preference, alreadyAsked: Bool) -> Bool {
        !isNewInstall && preference == .automatic && !alreadyAsked
    }

    static var shouldAskComplexity: Bool {
        let defaults = UserDefaults.standard
        return shouldAskComplexity(isNewInstall: isNewInstall,
                                   preference: Preference(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .automatic,
                                   alreadyAsked: defaults.bool(forKey: complexityAskedKey))
    }

    static func markComplexityAsked() {
        UserDefaults.standard.set(true, forKey: complexityAskedKey)
    }

    // MARK: - 다이얼 차오르기

    /// 빈 원이 차오르는 그림을 보일 때인가. 첫 시작 전에는 열 때마다, 이미 쓰던 사람에게는 한 번. **순수 함수.**
    static func shouldPlayDialFill(timerStarts: Double, alreadyPlayed: Bool) -> Bool {
        timerStarts == 0 || !alreadyPlayed
    }

    static var shouldPlayDialFill: Bool {
        shouldPlayDialFill(timerStarts: UsageMetrics.value(.timerStarts),
                           alreadyPlayed: UserDefaults.standard.bool(forKey: dialFillPlayedKey))
    }

    static func markDialFillPlayed() {
        UserDefaults.standard.set(true, forKey: dialFillPlayedKey)
    }
}

/// 그림 수업 하나. 본 것은 장부에 남아 저절로 다시 뜨지 않는다.
enum FeatureLesson: String, CaseIterable, Identifiable {
    case moreAlerts, templates, session, overtime

    var id: String { rawValue }

    private var learnedKey: String { "lesson.learned." + rawValue }

    var isLearned: Bool { UserDefaults.standard.bool(forKey: learnedKey) }

    func markLearned() { UserDefaults.standard.set(true, forKey: learnedKey) }

    var title: String {
        switch self {
        case .moreAlerts: return String(localized: "More than one alert")
        case .templates: return String(localized: "Saved setups")
        case .session: return String(localized: "Session Mode")
        case .overtime: return String(localized: "Overtime Tracking")
        }
    }

    var symbol: String {
        switch self {
        case .moreAlerts: return "bell.badge.fill"
        case .templates: return "bookmark.fill"
        case .session: return "text.rectangle.page"
        case .overtime: return "timer.circle.fill"
        }
    }
}
