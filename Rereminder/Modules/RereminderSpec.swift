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

    /// 함께 쓰는 앱(`LeeoFamilyCatalog`)에서 이 앱의 자리. 설정 ▸ Help 의 `LeeoFamilySettingsRow` 가
    /// 이 값으로 자기 자신을 목록에서 뺀다.
    static let familyID: String? = "rereminder"

    /// Rereminder.entitlements에 iCloud.com.Ysoup.FeedbackHub 컨테이너가 있어야 한다.
    /// 공용 피드백 허브(FeedbackHub)로 수집 — appIdentifier로 앱을 구분한다.
    static let feedback = LeeoFeedbackConfig(
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub",
        appIdentifier: "com.xa.toki"
    )

    /// 인앱 결제(페이월) — 비소비성 상품 셋, 트림(무료·플러스·프로)으로 나뉜다(`ProTier`, `StoreManager.ProductID`).
    /// ⚠️ **`entitlementIDs` 는 Pro 전체를 주는 상품만이다** — 여기에 기억(remember)을 넣으면
    ///    LeeoStore 의 `hasPro` 가 기억 구매자를 Pro 전체로 본다. 기억은 `StoreManager` 가 따로 센다.
    ///    배열 순서가 대표 상품 순서다 — `purchasePrimary` 가 첫 상품(pro)을 산다.
    /// cacheSuiteName: 앱 그룹(group.leeo.toki)에 권한을 캐시해 위젯/확장·오프라인에서도
    /// 마지막으로 확인된 Pro 상태로 즉시 잠금 해제한다.
    /// ⚠️ 상품 ID 는 App Store Connect 계약이다 — 변경 금지.
    /// 앱 내부에서는 언래핑이 필요 없는 이 비옵셔널 원본을 쓸 것 (StoreManager 등).
    static let paywallConfig = LeeoPaywallConfig(
        productIDs: ["com.xa.toki.pro", "com.xa.toki.remember", "com.xa.toki.pro.upgrade"],
        entitlementIDs: ["com.xa.toki.pro", "com.xa.toki.pro.upgrade"],
        termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
        privacyURL: URL(string: "https://m1zz.github.io/Rereminder/privacy.html"),
        cacheSuiteName: "group.leeo.toki",
        gate: ProGate.gatePolicy,
        gift: giftConfig,
        tipJar: tipJarConfig
    )

    /// Pro 선물하기. 보내는 사람은 소모성 선물 상품을 사고, 받는 사람은 `com.xa.toki.pro` 를 산 것과 같아진다
    /// (LeeoStore 가 받은 선물을 `purchasedProductIDs` 에 합치므로 `StoreManager` 의 래치가 그대로 Pro 로 기록한다).
    /// 선물 기록은 피드백과 같은 허브 컨테이너의 공개 DB 에 둔다 — `Rereminder.entitlements` 에 이미 있다.
    /// ⚠️ 선물 상품은 `productIDs` · `entitlementIDs` 에 넣지 않는다. 넣으면 선물을 산 사람이 Pro 가 된다.
    static let giftConfig = LeeoGiftConfig(
        productID: StoreManager.giftProductID,
        grantsProductID: StoreManager.ProductID.pro.rawValue,
        containerIdentifier: "iCloud.com.Ysoup.FeedbackHub"
    )

    /// 팁(응원). 이미 다 가진 사람이 더 내고 싶을 때. 아무것도 열지 않는 소모성 상품이다.
    /// ⚠️ 이것도 `productIDs` · `entitlementIDs` 에 넣지 않는다(사전 점검 `tip.sellsPro`).
    static let tipJarConfig = LeeoTipJarConfig(productIDs: StoreManager.tipProductIDs)

    /// LeeoAppSpec witness — 타입을 옵셔널로 명시해야 프로토콜 기본값(nil)에 가려지지 않는다.
    static let paywall: LeeoPaywallConfig? = paywallConfig

    /// 개인정보·지원 페이지 (LeeoKit 3.x 부터 필수). App Store Connect 에 넣은 주소와 같다.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/Rereminder/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/Rereminder/support.html")!,
        marketingURL: URL(string: "https://m1zz.github.io/Rereminder/")
    )

    /// 수익모델 선언 (LeeoKit 3.x 부터 필수) — 무료로 쓰다가 1회 구매로 플러스(기억) 또는 Pro 해제.
    /// 무료 한도는 `ProGate.gatePolicy` 하나에 있다 — 페이월 판정(`ProGate.evaluate`)과 한도 미리 알림
    /// (`ProGate.nearLimitRemaining`)이 모두 그것을 읽는다. 선물·팁도 `paywallConfig` 와 같은 값을 싣는다
    /// (둘이 어긋나면 `LeeoStore` 와 계약이 서로 다른 상품을 본다).
    static let monetization = LeeoMonetization.freemium(
        LeeoPurchaseConfig(productIDs: paywallConfig.productIDs,
                           entitlementIDs: paywallConfig.entitlementIDs,
                           gate: paywallConfig.gate,
                           cacheSuiteName: "group.leeo.toki",
                           gift: paywallConfig.gift,
                           tipJar: paywallConfig.tipJar)
    )
}
