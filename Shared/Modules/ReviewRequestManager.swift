//
//  ReviewRequestManager.swift
//  Rereminder
//
//  수동 리뷰 진입점 + 완료 횟수 집계.
//  자동 리뷰 유도는 만족도 게이트(LeeoReviewGate / .leeoSatisfactionCheck)가 단독 담당하고,
//  여기는 설정 화면의 수동 요청 버튼과 지표용 완료 카운트만 남긴다.
//

import Foundation
import StoreKit

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    private let completionCountKey = "timerCompletionCount"

    private init() {}

    // MARK: - Timer Done 기록

    /// Timer Done 시 호출 — 완료 횟수만 집계한다(지표·디버그용).
    /// 자동 리뷰 유도는 만족도 게이트(LeeoReviewGate / .leeoSatisfactionCheck)가 단독으로 담당한다.
    /// 여기서 시스템 리뷰창을 바로 띄우면 게이트와 이중 노출되므로 호출하지 않는다.
    func recordTimerCompletion() {
        let currentCount = UserDefaults.standard.integer(forKey: completionCountKey)
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: completionCountKey)
    }

    // MARK: - 리뷰 요청 실행 (설정 화면 수동 버튼 전용)

    /// 시스템 네이티브 리뷰 팝업 표시
    func requestReview() {
        #if canImport(UIKit)
        // 현재 씬에서 리뷰 요청
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            AppStore.requestReview(in: windowScene)
            AnalyticsManager.log(.reviewRequested)
        }
        #endif
    }

    /// 사용자가 Custom 리뷰 작성하려 할 때 (앱스토어로 이동)
    func openAppStoreReviewPage() {
        #if canImport(UIKit)
        // App Store 리뷰 페이지로 Custom 이동
        if let appStoreURL = URL(string: "https://apps.apple.com/app/id6752551268?action=write-review") {
            UIApplication.shared.open(appStoreURL)
            AnalyticsManager.log(.reviewCompleted)
        }
        #endif
    }

    // MARK: - 디버그용

    /// Reset Completion Count (테스트용)
    func resetCompletionCount() {
        UserDefaults.standard.set(0, forKey: completionCountKey)
    }

    /// 현재 Done 횟수 조회
    func getCurrentCompletionCount() -> Int {
        return UserDefaults.standard.integer(forKey: completionCountKey)
    }
}
