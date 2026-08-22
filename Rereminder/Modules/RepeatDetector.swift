//
//  RepeatDetector.swift
//  Rereminder
//
//  **같은 설정을 반복해서 거는가** — 그리고 그걸 앱이 먼저 알아채고 제안하는가.
//
//  왜: 이 앱은 *상황이 반복되는 사람*에게만 팔린다(매주 수업, 매일 운동, 매번 같은 발표 형식).
//  그런데 그 반복을 앱에 남기려면 지금은 사용자가 **스스로 결심**해야 한다. 결심은 잘 일어나지
//  않는다 — 반복은 이미 기록으로 남아 있으므로, 그 결심을 앱이 대신한다.
//
//  두 가지를 각각 본다:
//   ① **저장 제안**(`shouldPropose`) — 서로 다른 날 2일 이상 걸린 설정 → "템플릿으로 저장할까요?"
//   ② **시간대 제안**(`timeOfDaySuggestion`) — 같은 요일·비슷한 시각에 되풀이된 설정 →
//      그 시간에 앱을 열면 "지난주 이맘때 쓰시던 설정이에요, 이걸로 올려 드릴까요?"
//
//  ①은 "이 설정을 기억해 둘까"이고 ②는 "지금이 그 시간이다"이다. 답이 다르므로 따로 센다.
//
//  판정은 **서로 다른 날짜 수**로 한다. 같은 날 다섯 번 건 것은 한 번의 상황이지 반복이 아니다
//  (포모도로처럼 하루에 여러 번 도는 사용을 "반복"으로 세면 첫날부터 제안이 뜬다).
//
//  ⚠️ 잔소리가 되지 않는 것이 이 기능의 성패다. 세 겹으로 막는다:
//   ⓐ 한 설정에 대해 **한 번만** 제안한다(거절해도, 수락해도 다시 묻지 않는다)
//   ⓑ 제안 종류마다 전체 횟수 상한을 둔다
//   ⓒ 이미 템플릿으로 있는 설정은 저장 제안의 후보가 아니다(판단은 호출부가 넘겨 준다)
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

        /// 지문에서 되살린다 — 시간대 제안은 저장된 지문에서 설정을 복원해야 한다.
        init?(fingerprint: String) {
            let parts = fingerprint.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, let mainSec = Int(parts[0]) else { return nil }
            let offsets = parts[1].split(separator: ",").compactMap { Int($0) }
            self.init(mainSec: mainSec, offsets: offsets)
        }
    }

    /// 실행 한 번의 기록 — 날짜(로컬 하루)와 그때의 요일·시각.
    struct Run: Codable, Hashable {
        let day: Int
        let weekday: Int
        let hour: Int
    }

    // MARK: - 정책

    /// 이만큼 **서로 다른 날**에 걸렸으면 반복으로 본다.
    static let minDistinctDays = 2
    /// 이보다 오래된 날짜는 잊는다 — 지난달 습관으로 오늘 제안하면 엉뚱하다.
    static let memoryDays = 45
    /// 저장 제안의 총 횟수 상한.
    static let maxProposals = 3
    /// 시간대 제안의 총 횟수 상한. 저장 제안보다 덜 준다 — 틀렸을 때 더 성가시다.
    static let maxTimeSuggestions = 2
    /// "이맘때"의 폭(시간). 3시에 하던 일을 2시에 열어도 같은 상황으로 본다.
    static let hourTolerance = 1
    /// 기록을 이만큼만 들고 있는다 — 오래된 것부터 버린다.
    static let maxRuns = 200

    /// 테스트 격리를 위해 주입 가능하게 둔다(`TrialCounter` 와 같은 방식).
    static var defaults: UserDefaults = .standard
    /// 요일·시각 판정에 쓰는 달력. 테스트에서 고정 시간대를 넣는다.
    static var calendar: Calendar = .current

    private static let historyKey = "repeat.history.v2"
    private static let proposedKey = "repeat.proposed"
    private static let proposalCountKey = "repeat.proposalCount"
    private static let timeSuggestedKey = "repeat.timeSuggested"
    private static let timeSuggestionCountKey = "repeat.timeSuggestionCount"

    private static func dayStamp(_ date: Date) -> Int { LocalDay.stamp(date, calendar: calendar) }

    // MARK: - 기록

    /// 타이머를 시작할 때마다 부른다 — 설정 지문 + 그날 날짜 + 요일·시각을 남긴다.
    static func record(_ config: Config, now: Date = Date()) {
        guard config.mainSec > 0 else { return }
        let run = Run(day: dayStamp(now),
                      weekday: calendar.component(.weekday, from: now),
                      hour: calendar.component(.hour, from: now))

        var history = loadHistory()
        var runs = history[config.fingerprint] ?? []
        // 같은 날·같은 시각은 한 번만 — 같은 상황을 여러 번 세면 반복이 부풀려진다.
        if !runs.contains(run) { runs.append(run) }
        history[config.fingerprint] = runs
        saveHistory(prune(history, now: now))
    }

    /// 오래된 기록과, 그래서 텅 빈 설정을 걷어낸다.
    private static func prune(_ history: [String: [Run]], now: Date) -> [String: [Run]] {
        let cutoff = dayStamp(now) - memoryDays
        var pruned: [String: [Run]] = [:]
        for (key, runs) in history {
            let fresh = runs.filter { $0.day >= cutoff }
            if !fresh.isEmpty { pruned[key] = fresh }
        }
        // 그래도 너무 많으면 오래된 것부터 버린다(저장 용량과 파싱 비용 상한).
        let total = pruned.values.reduce(0) { $0 + $1.count }
        guard total > maxRuns else { return pruned }
        return pruned.mapValues { Array($0.sorted { $0.day > $1.day }.prefix(maxRuns / max(1, pruned.count))) }
    }

    // MARK: - ① 저장 제안

    /// 이 설정이 서로 다른 날 몇 번 걸렸나.
    static func distinctDays(of config: Config, now: Date = Date()) -> Int {
        let cutoff = dayStamp(now) - memoryDays
        let runs = (loadHistory()[config.fingerprint] ?? []).filter { $0.day >= cutoff }
        return Set(runs.map(\.day)).count
    }

    /// 지금 이 설정에 대해 **저장을 권해도 되는가.**
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

    static var proposalCount: Int { defaults.integer(forKey: proposalCountKey) }

    static func hasProposed(_ config: Config) -> Bool {
        Set(defaults.stringArray(forKey: proposedKey) ?? []).contains(config.fingerprint)
    }

    /// 제안했다 — **거절해도 저장해도 똑같이 기록한다.** 다시 묻지 않기 위해서다.
    static func markProposed(_ config: Config) {
        var seen = Set(defaults.stringArray(forKey: proposedKey) ?? [])
        guard !seen.contains(config.fingerprint) else { return }
        seen.insert(config.fingerprint)
        defaults.set(Array(seen), forKey: proposedKey)
        defaults.set(proposalCount + 1, forKey: proposalCountKey)
    }

    // MARK: - ② 시간대 제안

    /// **지금이 그 시간인가** — 같은 요일·비슷한 시각에 되풀이한 설정이 있으면 돌려준다.
    ///
    /// 저장 제안(①)이 "이 설정을 기억해 둘까"라면 이건 "지금 이걸 하려던 참 아닌가"다.
    /// 그래서 판정에 **지금 시각**이 들어간다 — 화요일 오후 3시에 하던 일은 화요일 오후 3시에만 권한다.
    static func timeOfDaySuggestion(now: Date = Date()) -> Config? {
        guard timeSuggestionCount < maxTimeSuggestions else { return nil }

        let cutoff = dayStamp(now) - memoryDays
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)
        let suggested = Set(defaults.stringArray(forKey: timeSuggestedKey) ?? [])

        var best: (config: Config, days: Int)?
        for (fingerprint, runs) in loadHistory() {
            guard !suggested.contains(fingerprint) else { continue }
            guard let config = Config(fingerprint: fingerprint) else { continue }

            let matching = runs.filter {
                $0.day >= cutoff && $0.weekday == weekday && abs($0.hour - hour) <= hourTolerance
            }
            let days = Set(matching.map(\.day)).count
            guard days >= minDistinctDays else { continue }

            // 더 자주 되풀이된 쪽을 고른다. 같으면 지문 순서로 고정해 결과가 흔들리지 않게.
            if best == nil || days > best!.days
                || (days == best!.days && fingerprint < best!.config.fingerprint) {
                best = (config, days)
            }
        }
        return best?.config
    }

    static var timeSuggestionCount: Int { defaults.integer(forKey: timeSuggestionCountKey) }

    /// 시간대 제안을 했다 — 수락하든 거절하든 그 설정은 다시 권하지 않는다.
    static func markTimeSuggested(_ config: Config) {
        var seen = Set(defaults.stringArray(forKey: timeSuggestedKey) ?? [])
        guard !seen.contains(config.fingerprint) else { return }
        seen.insert(config.fingerprint)
        defaults.set(Array(seen), forKey: timeSuggestedKey)
        defaults.set(timeSuggestionCount + 1, forKey: timeSuggestionCountKey)
    }

    // MARK: - 저장소

    private static func loadHistory() -> [String: [Run]] {
        guard let raw = defaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([String: [Run]].self, from: raw) else { return [:] }
        return decoded
    }

    private static func saveHistory(_ history: [String: [Run]]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: historyKey)
    }

    #if DEBUG
    static func resetAll() {
        for key in [historyKey, proposedKey, proposalCountKey, timeSuggestedKey, timeSuggestionCountKey] {
            defaults.removeObject(forKey: key)
        }
    }
    #endif
}
