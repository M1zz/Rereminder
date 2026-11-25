//
//  PresentationSection.swift
//  Rereminder
//
//  Created by Claude on 2/28/26.
//

import Foundation

struct PresentationSection: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var durationSeconds: Int
    var alertAtEnd: Bool = true

    /// 이 구간에 말할 것 — 대본·메모.
    /// 발표 중 화면에 이 글이 뜬다(`PresentationDisplayView`). 비어 있으면 아무것도 뜨지 않는다.
    /// ⚠️ 기본값이 있어야 **스크립트가 없던 시절에 저장한 템플릿**도 그대로 열린다.
    var script: String = ""

    /// 총 시간을 "5분", "1시간 30분" 형태로 표시
    var formattedDuration: String {
        TimeMapper.durationText(durationSeconds, narrow: true)
    }
}

// ⚠️ 저장된 JSON 은 직접 푼다. 자동으로 만든 `Decodable` 은 기본값이 있어도 키가 없으면 실패하는데,
//    `script`(2026-08 에 생김)가 없던 시절에 저장한 템플릿은 그 키가 없어 통째로 못 읽혔다 —
//    구간 이름·대본이 빈 채로 열리고(`Timer.sections` 가 []), 다시 저장하면 그대로 사라졌다.
//    새로 생긴 칸은 없으면 기본값으로 읽는다. 인코딩은 자동으로 만든 것을 그대로 쓴다.
extension PresentationSection {
    private enum CodingKeys: String, CodingKey {
        case id, name, durationSeconds, alertAtEnd, script
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try c.decode(String.self, forKey: .name),
            durationSeconds: try c.decode(Int.self, forKey: .durationSeconds),
            alertAtEnd: try c.decodeIfPresent(Bool.self, forKey: .alertAtEnd) ?? true,
            script: try c.decodeIfPresent(String.self, forKey: .script) ?? ""
        )
    }
}
