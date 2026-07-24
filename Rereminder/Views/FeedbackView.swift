//
//  FeedbackView.swift
//  Rereminder
//
//  피드백 화면은 LeeoKit이 통째로 제공한다 — 여기는 얇은 래퍼만 남긴다.
//  실제 구현: LeeoKit/Sources/LeeoKit/Feedback/
//

import SwiftUI
import LeeoKit

struct FeedbackView: View {
    var body: some View {
        LeeoFeedbackView<RereminderSpec>()
    }
}

struct FeedbackInboxView: View {
    var body: some View {
        LeeoFeedbackInboxView<RereminderSpec>()
    }
}

/// 개발자용 익명 사용 통계 뷰어 — 앱 활동(설치 스냅샷·이벤트)을 iCloud에서 모아 보여준다.
struct UsageStatsView: View {
    var body: some View {
        LeeoUsageStatsView<RereminderSpec>()
    }
}
