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
