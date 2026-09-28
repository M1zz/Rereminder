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
