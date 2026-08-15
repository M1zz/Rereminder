//
//  RereminderSpec.swift
//  Rereminder
//
//  LeeoKit 계약(LeeoAppSpec) 준수 — 이 앱의 공통 기능 설정값 단일 소스.
//  피드백 시스템 구현은 전부 LeeoKit에 있고, 앱은 이 설정만 제공한다.
//
//  ⚠️ recordType/구독 ID는 CloudKit Dashboard·기존 사용자 기기와의 계약이다 — 변경 금지.
//  컨테이너는 공용 피드백 허브(FeedbackHub)로 전환됨 — appIdentifier로 앱을 구분한다.
//  (전환 전 자기 컨테이너 iCloud.com.xa.toki에 쌓인 기존 피드백은 허브 인박스에 나타나지 않는다.)
//

import Foundation
import LeeoKit

enum RereminderSpec: LeeoAppSpec {
    static let appName = "두번알림"
    static let developerEmail = "leeo@kakao.com"

    /// Rereminder.entitlements에 iCloud.com.Ysoup.FeedbackHub 컨테이너가 있어야 한다.
    /// 공용 피드백 허브(FeedbackHub)로 수집 — appIdentifier로 앱을 구분한다.
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.xa.toki"
    )

    /// 인앱 결제(페이월) — 단일 비소비성 상품(com.xa.toki.pro).
    /// cacheSuiteName: 앱 그룹(group.leeo.toki)에 권한을 캐시해 위젯/확장·오프라인에서도
    /// 마지막으로 확인된 Pro 상태로 즉시 잠금 해제한다.
    /// ⚠️ 상품 ID 는 App Store Connect 계약이다 — 변경 금지.
    /// 앱 내부에서는 언래핑이 필요 없는 이 비옵셔널 원본을 쓸 것 (StoreManager 등).
    static let paywallConfig = LeeoPaywallConfig(
        productIDs: ["com.xa.toki.pro"],
        termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
        privacyURL: URL(string: "https://m1zz.github.io/Rereminder/privacy.html"),
        cacheSuiteName: "group.leeo.toki"
    )

    /// LeeoAppSpec witness — 타입을 옵셔널로 명시해야 프로토콜 기본값(nil)에 가려지지 않는다.
    static let paywall: LeeoPaywallConfig? = paywallConfig
}
