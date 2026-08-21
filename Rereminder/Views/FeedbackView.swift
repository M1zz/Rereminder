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

// 개발자용 익명 사용 통계 뷰어는 이 앱 전용 지표(완주율·활성화 퍼널 등)를 보여주려고
// LeeoKit의 기본 화면 대신 직접 만든다 — `Rereminder/Views/UsageStatsView.swift`.
