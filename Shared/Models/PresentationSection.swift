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

    /// 총 시간을 "5분", "1시간 30분" 형태로 표시
    var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m"
            }
            return "\(hours)h"
        }
        if seconds > 0 && minutes == 0 {
            return "\(seconds)s"
        }
        if seconds > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(minutes)m"
    }
}
