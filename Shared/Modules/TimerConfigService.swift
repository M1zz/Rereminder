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

    /// Pro는 무제한, 무료는 ProGate.freeTemplateLimit
    private var templateLimit: Int {
        StoreManager.isProUser ? 100 : ProGate.freeTemplateLimit
    }

    func attachContext(_ ctx: ModelContext) {
        self.context = ctx
    }

    // MARK: - Seed Data

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

        let seeds: [(name: String, mainSec: Int, offsets: [Int], label: String, colorHex: String)] = [
            ("Presentation 30 min", 1800, [600, 300, 60], "Presentation", "#FF3B30"),
            ("Mentoring 40 min",    2400, [600, 300, 60], "Mentoring",    "#34C759"),
            ("Study 25 min",        1500, [300, 60],      "Study",        "#5AC8FA"),
            ("Exercise 30 min",     1800, [300, 60],      "Exercise",     "#FF2D55"),
            ("Meeting 60 min",      3600, [600, 300],     "Meeting",      "#007AFF"),
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
        return (try? ctx.fetch(desc)) ?? []
    }

    /// 중복이 아닌 경우에만 템플릿 저장, limit 초과 시 오래된 것 삭제
    func saveIfNeeded(
        mainSec: Int,
        offsets: [Int],
        prealertMessages: [Int: String],
        finishMessage: String?
    ) {
        guard let ctx = context else { return }

        let normalizedFinish = (finishMessage?.isEmpty ?? true) ? nil : finishMessage

        // 중복 체크
        let currentTop = fetchRecents().first
        if let top = currentTop,
           top.mainSeconds == mainSec,
           top.prealertOffsetsSec == offsets,
           top.prealertMessages == prealertMessages,
           top.finishMessage == normalizedFinish {
            return
        }

        let entry = Timer(
            name: makeTemplateName(mainSec: mainSec, offsets: offsets),
            mainSeconds: mainSec,
            prealertOffsetsSec: offsets,
            prealertMessages: prealertMessages,
            finishMessage: normalizedFinish
        )
        ctx.insert(entry)
        do {
            try ctx.save()
        } catch {
            print("❌ 타이머 템플릿 저장 실패: \(error)")
        }

        // limit 초과 시 삭제
        let recents = fetchRecents()
        if recents.count > templateLimit {
            for old in recents.dropFirst(templateLimit) {
                ctx.delete(old)
            }
            do {
                try ctx.save()
            } catch {
                print("❌ 오래된 템플릿 삭제 실패: \(error)")
            }
        }
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
