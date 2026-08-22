//
//  RepeatDetector.swift
//  Rereminder
//
//  **같은 설정을 여러 날 반복해서 거는가** — 그리고 그걸 앱이 먼저 알아채고 제안하는가.
//
//  왜: 이 앱은 *상황이 반복되는 사람*에게만 팔린다(매주 수업, 매일 운동, 매번 같은 발표 형식).
//  그런데 그 반복을 앱에 남기려면 지금은 사용자가 **스스로 "저장"을 결심**해야 한다.
//  결심은 잘 일어나지 않는다 — 반복은 이미 증거로 남아 있으므로, 그 결심을 앱이 대신한다.
//
//  판정은 **서로 다른 날짜 수**로 한다. 같은 날 다섯 번 건 것은 한 번의 상황이지 반복이 아니다
//  (포모도로처럼 하루에 여러 번 도는 사용을 "반복"으로 세면 첫날부터 제안이 뜬다).
//
//  ⚠️ 잔소리가 되지 않는 것이 이 기능의 성패다. 그래서 세 겹으로 막는다:
//   ① 한 설정에 대해 **한 번만** 제안한다(거절해도, 저장해도 다시 묻지 않는다)
//   ② 전체 제안 횟수에 상한을 둔다
//   ③ 이미 템플릿으로 있는 설정은 아예 후보가 아니다(판단은 호출부가 넘겨 준다)
//

import Foundation

enum RepeatDetector {

    /// 시간과 알림 지점만으로 설정을 식별한다 — 문구·이름이 달라도 "같은 상황"이면 같은 설정이다.
    struct Config: Equatable, Hashable, Codable {
        let mainSec: Int
        let offsets: [Int]

        init(mainSec: Int, offsets: [Int]) {
            let total = max(0, mainSec)
            self.mainSec = total
            // 정렬해서 담는다 — 순서가 다르다고 다른 설정이 되면 반복이 영영 안 잡힌다.
            // 전체 시간 밖의 알림은 울리지도 않으므로 지문에서 뺀다.
            self.offsets = offsets.filter { $0 > 0 && $0 < total }.sorted()
        }

        /// 저장 키로 쓰는 문자열. 예: `600:60,300`
        var fingerprint: String { "\(mainSec):\(offsets.map(String.init).joined(separator: ","))" }
    }

    // MARK: - 정책

    /// 이만큼 **서로 다른 날**에 걸렸으면 반복으로 본다.
    static let minDistinctDays = 2
    /// 이보다 오래된 날짜는 잊는다 — 지난달 습관으로 오늘 제안하면 엉뚱하다.
    static let memoryDays = 45
    /// 앱이 먼저 말을 거는 총 횟수 상한.
    static let maxProposals = 3

    /// 테스트 격리를 위해 주입 가능하게 둔다(`TrialCounter` 와 같은 방식).
    static var defaults: UserDefaults = .standard

    private static let historyKey = "repeat.history"
    private static let proposedKey = "repeat.proposed"
    private static let proposalCountKey = "repeat.proposalCount"

    /// **로컬 달력 기준**이어야 한다 — UTC 로 세면 한국의 오전 9시가 날짜 경계가 되어
    /// "같은 날 두 번"이 "이틀 반복"으로 둔갑한다(`LocalDay` 주석 참고).
    private static func dayStamp(_ date: Date) -> Int { LocalDay.stamp(date) }

    // MARK: - 기록

    /// 타이머를 시작할 때마다 부른다 — 설정 지문 + 그날 날짜를 남긴다.
    static func record(_ config: Config, now: Date = Date()) {
        guard config.mainSec > 0 else { return }
        var history = loadHistory()
        var days = Set(history[config.fingerprint] ?? [])
        days.insert(dayStamp(now))
        history[config.fingerprint] = Array(days).sorted()
        saveHistory(prune(history, now: now))
    }

    /// 오래된 날짜와, 그래서 텅 빈 설정을 걷어낸다.
    private static func prune(_ history: [String: [Int]], now: Date) -> [String: [Int]] {
        let cutoff = dayStamp(now) - memoryDays
        var pruned: [String: [Int]] = [:]
        for (key, days) in history {
            let fresh = days.filter { $0 >= cutoff }
            if !fresh.isEmpty { pruned[key] = fresh }
        }
        return pruned
    }

    // MARK: - 판정

    /// 이 설정이 서로 다른 날 몇 번 걸렸나.
    static func distinctDays(of config: Config, now: Date = Date()) -> Int {
        let cutoff = dayStamp(now) - memoryDays
        return (loadHistory()[config.fingerprint] ?? []).filter { $0 >= cutoff }.count
    }

    /// 지금 이 설정에 대해 **먼저 말을 걸어도 되는가.**
    ///
    /// - Parameter isAlreadySaved: 이미 템플릿으로 갖고 있는 설정인지(호출부가 안다).
    static func shouldPropose(_ config: Config,
                              isAlreadySaved: Bool,
                              now: Date = Date()) -> Bool {
        guard !isAlreadySaved else { return false }
        guard !hasProposed(config) else { return false }
        guard proposalCount < maxProposals else { return false }
        return distinctDays(of: config, now: now) >= minDistinctDays
    }

    // MARK: - 제안 기록

    static var proposalCount: Int { defaults.integer(forKey: proposalCountKey) }

    static func hasProposed(_ config: Config) -> Bool {
        proposedFingerprints.contains(config.fingerprint)
    }

    /// 제안했다 — **거절해도 저장해도 똑같이 기록한다.** 다시 묻지 않기 위해서다.
    static func markProposed(_ config: Config) {
        var seen = proposedFingerprints
        guard !seen.contains(config.fingerprint) else { return }
        seen.insert(config.fingerprint)
        defaults.set(Array(seen), forKey: proposedKey)
        defaults.set(proposalCount + 1, forKey: proposalCountKey)
    }

    private static var proposedFingerprints: Set<String> {
        Set(defaults.stringArray(forKey: proposedKey) ?? [])
    }

    // MARK: - 저장소

    private static func loadHistory() -> [String: [Int]] {
        guard let raw = defaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([String: [Int]].self, from: raw) else { return [:] }
        return decoded
    }

    private static func saveHistory(_ history: [String: [Int]]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    #if DEBUG
    static func resetAll() {
        defaults.removeObject(forKey: historyKey)
        defaults.removeObject(forKey: proposedKey)
        defaults.removeObject(forKey: proposalCountKey)
    }
    #endif
}
