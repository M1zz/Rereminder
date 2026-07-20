//
//  RereminderSpec.swift
//  Rereminder
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//  피드백 시스템 구현은 전부 LeeoKit에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ feedback의 컨테이너/레코드 타입/구독 ID는 CloudKit Dashboard·기존 사용자
//  기기와의 계약이다 — 변경 금지 (RereminderSpecTests가 잠근다).
//

import Foundation
import LeeoKit

enum RereminderSpec: LeeoAppSpec {
    static let appName = "두번알림"
    static let developerEmail = "leeo@kakao.com"

    /// Rereminder.entitlements의 iCloud 컨테이너와 동일해야 한다.
    /// appIdentifier는 nil — 단일 앱 스키마 (기존 배포 스키마와 호환).
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.xa.toki"
    )
}
