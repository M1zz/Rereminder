//
//  FeedbackService.swift
//  Rereminder
//
//  앱 내 피드백/기능 요청을 CloudKit Public Database로 직접 제출한다.
//  메일 앱 없이도 동작하며, 개발자는 앱 내 인박스(마스터 모드) 또는
//  CloudKit Dashboard에서 접수 내역을 확인한다.
//
//  ⚠️ CloudKit Dashboard 설정 필요 (docs/FEEDBACK_CLOUDKIT.md 참고):
//  - Public DB에 "Feedback" 레코드 타입 (개발 환경에서 첫 저장 시 자동 생성)
//  - Security Roles: World에 create만 허용, read 권한 제거
//  - 스키마를 Production으로 배포
//

import Foundation
import CloudKit
import UIKit
import UserNotifications

final class FeedbackService {
    static let shared = FeedbackService()
    private init() {}

    private static let containerIdentifier = "iCloud.com.xa.toki"
    static let recordType = "Feedback"

    enum FeedbackError: LocalizedError {
        case iCloudUnavailable
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                return String(localized: "You're not signed in to iCloud")
            case .saveFailed:
                return String(localized: "Failed to send feedback")
            }
        }
    }

    // MARK: - 제출 (모든 사용자)

    /// 피드백을 Public DB에 제출한다. 실패 시 throw — 호출부에서 이메일 폴백 처리.
    func submit(type: String, message: String, deviceInfo: String) async throws {
        let container = CKContainer(identifier: Self.containerIdentifier)

        // Public DB 쓰기도 iCloud 로그인이 필요하다.
        let status = try await container.accountStatus()
        guard status == .available else {
            print("⚠️ [FeedbackService.submit] iCloud 계정 없음: \(status)")
            throw FeedbackError.iCloudUnavailable
        }

        let record = CKRecord(recordType: Self.recordType)
        record["type"] = type
        record["message"] = message
        record["deviceInfo"] = deviceInfo
        record["appVersion"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        record["locale"] = Locale.current.identifier
        record["platform"] = {
            #if targetEnvironment(macCatalyst)
            return "macCatalyst"
            #else
            return "iOS"
            #endif
        }()

        do {
            _ = try await container.publicCloudDatabase.save(record)
            print("✅ [FeedbackService.submit] 피드백 제출 완료 (type=\(type))")
        } catch {
            print("❌ [FeedbackService.submit] 제출 실패: \(error)")
            throw FeedbackError.saveFailed(error)
        }
    }

    // MARK: - 개발자 인박스 (마스터 모드 전용)

    /// 접수된 피드백 한 건 (조회용 read model)
    struct FeedbackRecord: Identifiable {
        let id: String
        let type: String
        let message: String
        let deviceInfo: String
        let appVersion: String
        let locale: String
        let platform: String
        let createdAt: Date?
        /// 처리 상태 — "done"이면 완료 (개발자가 인박스에서 표시)
        var status: String?

        var isDone: Bool { status == "done" }

        init(_ record: CKRecord) {
            self.id = record.recordID.recordName
            self.type = record["type"] as? String ?? "-"
            self.message = record["message"] as? String ?? ""
            self.deviceInfo = record["deviceInfo"] as? String ?? ""
            self.appVersion = record["appVersion"] as? String ?? "-"
            self.locale = record["locale"] as? String ?? ""
            self.platform = record["platform"] as? String ?? ""
            self.createdAt = record.creationDate
            self.status = record["status"] as? String
        }
    }

    /// 접수된 피드백 전체 조회 (최신순, 최대 limit개).
    /// ⚠️ 개발자 계정 전용 — CloudKit Dashboard에서 admin 역할에 read 권한과
    /// 본인 userRecordName을 등록해야 다른 사용자의 레코드를 읽을 수 있다.
    func fetchAll(limit: Int = 100) async throws -> [FeedbackRecord] {
        let container = CKContainer(identifier: Self.containerIdentifier)
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let (results, _) = try await container.publicCloudDatabase.records(
            matching: query, resultsLimit: limit)
        var records: [FeedbackRecord] = []
        var firstError: Error?
        for (_, result) in results {
            switch result {
            case .success(let record):
                records.append(FeedbackRecord(record))
            case .failure(let error):
                // 권한 오류 등이 빈 목록으로 위장하지 않도록 보존
                print("❌ [FeedbackService.fetchAll] 레코드 읽기 실패: \(error)")
                if firstError == nil { firstError = error }
            }
        }
        if records.isEmpty, let firstError { throw firstError }
        return records
    }

    /// 현재 iCloud 계정의 CloudKit userRecordName — Dashboard admin 역할 등록에 필요.
    func currentUserRecordName() async -> String? {
        let container = CKContainer(identifier: Self.containerIdentifier)
        return try? await container.userRecordID().recordName
    }

    /// 피드백 완료/미완료 표시 (서버 반영). admin 역할 Write 권한 필요.
    func setDone(recordName: String, done: Bool) async throws {
        let db = CKContainer(identifier: Self.containerIdentifier).publicCloudDatabase
        let record = try await db.record(for: CKRecord.ID(recordName: recordName))
        record["status"] = done ? "done" : nil
        _ = try await db.save(record)
    }

    /// 피드백 삭제 (서버 반영). admin 역할 Write 권한 필요.
    func delete(recordName: String) async throws {
        let db = CKContainer(identifier: Self.containerIdentifier).publicCloudDatabase
        _ = try await db.deleteRecord(withID: CKRecord.ID(recordName: recordName))
    }

    // MARK: - 새 피드백 푸시 알림 (개발자 기기 전용)

    /// 새 Feedback 레코드 생성 시 이 기기(iCloud 계정)로 오는 CKQuerySubscription ID.
    static let newFeedbackSubscriptionID = "feedback-new-v1"

    enum NotificationError: LocalizedError {
        case permissionDenied

        var errorDescription: String? {
            String(localized: "Notifications are off. Allow them in iOS Settings.")
        }
    }

    /// 새 피드백 푸시 알림 구독 여부 (서버 기준 — 재설치해도 유지).
    func isNewFeedbackNotificationEnabled() async -> Bool {
        let db = CKContainer(identifier: Self.containerIdentifier).publicCloudDatabase
        let sub = try? await db.subscription(for: Self.newFeedbackSubscriptionID)
        return sub != nil
    }

    /// 새 피드백 푸시 알림 켜기 — 알림 권한 요청 + APNs 등록 + CKQuerySubscription 저장.
    /// ⚠️ 구독이 발화하려면 이 계정이 Feedback을 읽을 수 있어야 한다 (admin 역할 read).
    func enableNewFeedbackNotifications() async throws {
        let granted = try await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
        guard granted else { throw NotificationError.permissionDenied }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }

        let subscription = CKQuerySubscription(
            recordType: Self.recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: Self.newFeedbackSubscriptionID,
            options: .firesOnRecordCreation
        )
        let info = CKSubscription.NotificationInfo()
        info.title = String(localized: "New feedback arrived 📬")
        info.alertBody = String(localized: "A user left feedback. Check the inbox.")
        info.soundName = "default"
        subscription.notificationInfo = info

        let db = CKContainer(identifier: Self.containerIdentifier).publicCloudDatabase
        _ = try await db.save(subscription)
    }

    /// 새 피드백 푸시 알림 끄기 — 구독 삭제.
    func disableNewFeedbackNotifications() async throws {
        let db = CKContainer(identifier: Self.containerIdentifier).publicCloudDatabase
        _ = try await db.deleteSubscription(withID: Self.newFeedbackSubscriptionID)
    }
}
