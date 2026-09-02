//
//  TimerConfigService.swift
//  Rereminder
//
//  타이머 템플릿 CRUD & 설정 관리
//  TimerScreenViewModel에서 분리
//

import Foundation
import SwiftData

@MainActor
final class TimerConfigService {

    private var context: ModelContext?

    /// 저장해 둘 수 있는 템플릿의 최대 개수. **결제 여부로 갈리지 않는다.**
    ///
    /// ⚠️ 무료를 0 으로 두지 말 것. 무료의 뜻은 "저장을 하지 않는다"(`saveIfNeeded` 첫 줄)이지
    ///    "저장한 뒤 지운다"가 아닌데, 한도를 0 으로 두면 아래 정리 루프가 **시드 템플릿까지
    ///    통째로** 지웠다 — 무료 사용자는 타이머를 한 번 시작하는 것만으로(시작이
    ///    `saveIfNeeded` 를 부른다) 칩이 전부 사라졌다. "템플릿이 저장되지 않는다"는 제보의 정체.
    private let maxTemplates = 100

    func attachContext(_ ctx: ModelContext) {
        self.context = ctx
    }

    // MARK: - Seed Data

    /// 첫 실행 시 심는 기본 템플릿 한 줄 — 이름 없는 큰 튜플로 두면 어느 자리가 무엇인지 읽히지 않는다
    private struct SeedTemplate {
        let name: String
        let mainSec: Int
        let offsets: [Int]
        let label: String
        let colorHex: String
    }

    /// 첫 실행 시 시나리오별 기본 프리셋 템플릿 삽입
    func seedIfNeeded() {
        guard let ctx = context else { return }
        let key = "hasSeededTemplates"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        // 이미 템플릿이 있으면 시드 불필요 (기존 사용자)
        if !fetchRecents().isEmpty {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        let seeds: [SeedTemplate] = [
            SeedTemplate(name: "Presentation 30 min", mainSec: 1800, offsets: [600, 300, 60],
                         label: "Presentation", colorHex: "#FF3B30"),
            SeedTemplate(name: "Mentoring 40 min", mainSec: 2400, offsets: [600, 300, 60],
                         label: "Mentoring", colorHex: "#34C759"),
            SeedTemplate(name: "Study 25 min", mainSec: 1500, offsets: [300, 60],
                         label: "Study", colorHex: "#5AC8FA"),
            SeedTemplate(name: "Exercise 30 min", mainSec: 1800, offsets: [300, 60],
                         label: "Exercise", colorHex: "#FF2D55"),
            SeedTemplate(name: "Meeting 60 min", mainSec: 3600, offsets: [600, 300],
                         label: "Meeting", colorHex: "#007AFF"),
        ]

        for s in seeds {
            let t = Timer(
                name: s.name,
                mainSeconds: s.mainSec,
                prealertOffsetsSec: s.offsets,
                label: s.label,
                colorHex: s.colorHex,
                isFavorite: true
            )
            ctx.insert(t)
        }

        do {
            try ctx.save()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            print("❌ 시드 템플릿 저장 실패: \(error)")
        }
    }

    // MARK: - Template CRUD

    /// 최근 템플릿 조회 (생성일 역순)
    func fetchRecents() -> [Timer] {
        guard let ctx = context else { return [] }
        let desc = FetchDescriptor<Timer>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let recents = (try? ctx.fetch(desc)) ?? []
        // 익명 사용 스냅샷이 실어 보낼 "현재 템플릿 수" 미러 — 개수만, 이름·내용은 나가지 않는다.
        UsageMetrics.setTemplateCount(recents.count)
        return recents
    }

    /// 같은 설정의 템플릿이 없을 때만 저장하고, 최대 개수를 넘으면 오래된 것을 지운다.
    ///
    /// ⚠️ **무료 사용자에게는 아무것도 하지 않는다 — 저장도, 삭제도.**
    ///    저장이 Pro 인 것(`ProGate.canSaveTemplate`)과 갖고 있던 템플릿이 사라지는 것은
    ///    전혀 다른 일이다. 칩은 잠긴 채로 남아 있어야 한다(`TemplateQuickBar` 머리말).
    ///
    /// 중복은 **전체 템플릿**과 견준다. 맨 앞 하나만 보면 A·B 를 번갈아 쓸 때마다 같은 설정이
    /// 다시 쌓여 칩이 복사본으로 채워진다(시작할 때마다 이 함수가 불린다).
    ///
    /// - Returns: 이 설정이 템플릿으로 남아 있으면 true (새로 저장했거나 이미 있었거나).
    @discardableResult
    func saveIfNeeded(
        mainSec: Int,
        offsets: [Int],
        prealertMessages: [Int: String],
        finishMessage: String?
    ) -> Bool {
        guard ProGate.canSaveTemplate() else { return false }
        guard let ctx = context else { return false }

        let normalizedFinish = (finishMessage?.isEmpty ?? true) ? nil : finishMessage

        // ⚠️ 견주기 전에 **저장될 모양으로 맞춘다**. `Timer.validateInPlace` 가 범위를 벗어난
        //    값을 걸러내고 오름차순으로 정렬해 저장하므로, 받은 순서 그대로 비교하면
        //    [300, 60] 과 저장된 [60, 300] 이 다른 것이 되어 같은 설정이 매번 새로 쌓인다.
        let normalizedOffsets = Array(Set(offsets.filter { $0 > 0 && $0 < mainSec })).sorted()

        // 중복 체크 — 이미 같은 설정이 있으면 저장한 것과 같다
        let existing = fetchRecents().contains { template in
            template.mainSeconds == mainSec
                && template.prealertOffsetsSec == normalizedOffsets
                && template.prealertMessages == prealertMessages
                && template.finishMessage == normalizedFinish
        }
        if existing { return true }

        let entry = Timer(
            name: makeTemplateName(mainSec: mainSec, offsets: normalizedOffsets),
            mainSeconds: mainSec,
            prealertOffsetsSec: normalizedOffsets,
            prealertMessages: prealertMessages,
            finishMessage: normalizedFinish
        )
        ctx.insert(entry)
        do {
            try ctx.save()
            AnalyticsManager.log(.presetSaved(name: entry.name, durationSeconds: mainSec))
        } catch {
            print("❌ 타이머 템플릿 저장 실패: \(error)")
            ctx.delete(entry)
            return false
        }

        // 최대 개수 초과 시 오래된 것부터 삭제
        let recents = fetchRecents()
        if recents.count > maxTemplates {
            for old in recents.dropFirst(maxTemplates) {
                ctx.delete(old)
            }
            do {
                try ctx.save()
            } catch {
                print("❌ 오래된 템플릿 삭제 실패: \(error)")
            }
        }
        return true
    }

    // MARK: - Template Name 생성

    func makeTemplateName(mainSec: Int, offsets: [Int]) -> String {
        let m = max(0, mainSec) / 60
        let s = max(0, mainSec) % 60
        let base = s > 0 ? "Main \(m) min \(s) sec" : "Main \(m) min"
        if offsets.isEmpty { return base }
        let pre = offsets.map { "\($0/60)" }.joined(separator: "·")
        return "\(base) / Pre-alert \(pre) min"
    }

    /// 시간 기반 자동 이름 생성 (Live Activity 등에서 사용)
    func makeAutoName(mainSec: Int) -> String {
        if mainSec >= 3600 {
            let hours = mainSec / 3600
            let minutes = (mainSec % 3600) / 60
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        } else if mainSec >= 60 {
            return "\(mainSec / 60)min"
        } else {
            return "Timer"
        }
    }
}
