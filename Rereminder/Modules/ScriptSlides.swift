//
//  ScriptSlides.swift
//  Rereminder
//
//  구간 대본을 **장표**로 나눈다. 빈 줄 하나가 장표 경계다 — 따로 배울 문법이 없다.
//  한 구간에 장표가 여러 장이면 대본 한 덩어리로는 "지금 몇 번째 장표를 말하고 있나"를 잃는다.
//
//  시간은 글 분량에 비례해 나눈다. 장표마다 시간을 적게 하면 정확하지만 입력이 많아진다(2026-11-16, 먼저 이렇게 써 보고 듣는다).
//  손으로 넘긴 장표는 `ManualSlide` 가 붙잡는다.
//

import Foundation

enum ScriptSlides {
    /// 빈 줄(공백만 있는 줄 포함)로 나눈다. 앞뒤 공백과 빈 장표는 버린다.
    static func split(_ script: String) -> [String] {
        var slides: [String] = []
        var current: [String] = []
        for line in script.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty { slides.append(current.joined(separator: "\n")) }
                current = []
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { slides.append(current.joined(separator: "\n")) }
        return slides.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// 구간을 `progress`(0 → 1) 만큼 썼을 때 몇 번째 장표인지와, 그 장표 안에서 얼마나 왔는지(0 → 1).
    /// 장표 몫은 글자 수 비례다. 아주 짧은 장표("질문 받겠습니다")도 읽을 틈은 있게 몫을 조금 깔아 준다.
    static func position(in slides: [String], progress: Double) -> (index: Int, within: Double) {
        guard slides.count > 1 else { return (0, min(1, max(0, progress))) }
        let floor = 20.0
        let weights = slides.map { max(floor, Double($0.count)) }
        let total = weights.reduce(0, +)
        let target = min(1, max(0, progress)) * total
        var start = 0.0
        for (index, weight) in weights.enumerated() {
            if target < start + weight || index == weights.count - 1 {
                return (index, min(1, max(0, (target - start) / weight)))
            }
            start += weight
        }
        return (slides.count - 1, 1)
    }
}

/// 손으로 넘긴 장표. 시간이 따라잡거나 지나가면 다시 시간을 따른다.
struct ManualSlide: Equatable {
    let index: Int
    /// 넘길 때 시간이 가리키던 장표
    let autoAtOverride: Int

    /// 지금 보여 줄 장표. 손으로 앞질렀으면 시간이 거기 닿을 때까지, 되돌렸으면 시간이 다음 장표로 넘어갈 때까지 붙잡는다.
    func resolved(auto: Int) -> Int? {
        guard auto != autoAtOverride, auto >= index else { return index }
        return nil
    }
}
