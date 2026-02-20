//
//  ReviewRequestManager.swift
//  Rereminder
//
//  리뷰 요청 관리자
//  Apple 가이드라인 준수: 적절한 시점에 자동으로 리뷰 요청
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
    private let lastReviewRequestDateKey = "lastReviewRequestDate"
    private let hasRequestedReviewKey = "hasRequestedReview"

    // Settings값
    private let completionThreshold = 5  // 5회 Done 후 리뷰 요청
    private let minimumDaysBetweenRequests = 90  // 90일에 한 번만 요청

    private init() {}

    // MARK: - Timer Done 기록

    /// Timer Done 시 호출
    func recordTimerCompletion() {
        let currentCount = UserDefaults.standard.integer(forKey: completionCountKey)
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: completionCountKey)

        print("✅ Timer Done 기록: \(newCount)회")

        // 조건을 만족하면 리뷰 요청
        if shouldRequestReview(completionCount: newCount) {
            requestReview()
        }
    }

    // MARK: - 리뷰 요청 조건 OK

    private func shouldRequestReview(completionCount: Int) -> Bool {
        // 1. Done 횟수가 threshold 이상인지 OK
        guard completionCount >= completionThreshold else {
            return false
        }

        // 2. 마지막 요청 날짜 OK
        if let lastRequestDate = UserDefaults.standard.object(forKey: lastReviewRequestDateKey) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequestDate, to: Date()).day ?? 0

            // 90일이 지나지 않았으면 요청하지 않음
            if daysSinceLastRequest < minimumDaysBetweenRequests {
                print("⏳ 마지막 리뷰 요청 후 \(daysSinceLastRequest)일 경과 (최소 \(minimumDaysBetweenRequests)일 필요)")
                return false
            }
        }

        return true
    }

    // MARK: - 리뷰 요청 실행

    /// 시스템 네이티브 리뷰 팝업 표시
    func requestReview() {
        #if canImport(UIKit)
        // 현재 씬에서 리뷰 요청
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)

            // 마지막 요청 날짜 기록
            UserDefaults.standard.set(Date(), forKey: lastReviewRequestDateKey)
            UserDefaults.standard.set(true, forKey: hasRequestedReviewKey)

            print("⭐ 리뷰 요청 팝업 표시")
        }
        #endif
    }

    /// 사용자가 Custom 리뷰 작성하려 할 때 (앱스토어로 이동)
    func openAppStoreReviewPage() {
        #if canImport(UIKit)
        // App Store 리뷰 페이지로 Custom 이동
        if let appStoreURL = URL(string: "https://apps.apple.com/app/id6503638387?action=write-review") {
            UIApplication.shared.open(appStoreURL)
            print("📱 App Store 리뷰 페이지 열기")
        }
        #endif
    }

    // MARK: - 디버그용

    /// Reset Completion Count (테스트용)
    func resetCompletionCount() {
        UserDefaults.standard.set(0, forKey: completionCountKey)
        print("🔄 Reset Completion Count")
    }

    /// 현재 Done 횟수 조회
    func getCurrentCompletionCount() -> Int {
        return UserDefaults.standard.integer(forKey: completionCountKey)
    }
}
