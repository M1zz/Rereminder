# 운영 체크리스트 — CloudKit Dashboard 수동 작업

코드는 배선이 끝났고, 아래는 개발자가 CloudKit Dashboard(iCloud.com.Ysoup.FeedbackHub 컨테이너)에서
1회 수행해야 하는 작업이다. 완료 전까지 해당 기능은 "조회 실패 = 기본값"으로 동작한다.

## 1. 원격 킬스위치 (RemoteFlags) — LeeoKit 2.7.0

- [ ] 레코드 타입 `RemoteFlags` 생성
- [ ] 레코드 recordName: `flags_com.xa.toki`
- [ ] 필드 3개를 **Int64**(1=켬, 0=끔)로 생성:
  - `usageReportingEnabled` — 익명 사용 통계 전송
  - `diagnosticsEnabled` — MetricKit 크래시/행 수집
  - `cloudSyncEnabled` — iCloud KVS 타이머 동기화
- [ ] Schema → **Deploy Schema Changes to Production**
- 주의: 필드가 없거나 조회에 실패하면 **켬**으로 동작한다(가용성 우선). 갱신은 6시간 쓰로틀이라 즉시 전파되지 않는다.
- 플래그 enum: `Rereminder/Modules/RereminderFlags.swift` — rawValue = CloudKit 필드명 계약, 변경 금지.

## 2. 크래시 진단 (CrashReport) — LeeoDiagnostics

- [ ] 레코드 타입 `CrashReport` 생성 — 필드: `appId`, `kind`, `detail`, `appVersion`, `osVersion`, `deviceType`, `stack`
- [ ] Production 배포
- [ ] App Store Connect → App Privacy에 **CrashData(사용자 미연결·비추적)** 신고 확인
  - `Rereminder/PrivacyInfo.xcprivacy`에 이미 선언되어 있음 — 이제 LeeoDiagnostics가 실제로 수집하므로 선언과 실체가 일치한다.
- 참고: 페이로드는 iOS가 하루 한 번꼴로 묶어 주며 시뮬레이터에서는 거의 오지 않는다.

## 3. 사용 통계 (UsageSnapshot / UsageEvent) — 🚨 배포 **전에** 해야 하는 작업

자세한 배경·집계 설계는 `docs/USAGE_STATS_HUB.md`.

- [ ] `UsageSnapshot` / `UsageEvent` 레코드 타입이 Production에 배포되어 있는지 확인
- [ ] **Development에서 새 빌드를 한 번 실행 + 타이머 1회** → `UsageEvent`에 `occurredAt`(Date),
      `installID`(String) 필드가 자동 생성되는지 Dashboard에서 확인
      (LeeoKit 2.9.0에서 추가된 필드. Production 스키마에 없으면 **이벤트 저장이 통째로 실패**한다)
- [ ] 인덱스: `UsageSnapshot.recordName` Queryable / `UsageEvent.recordName` Queryable +
      `createdTimestamp` Sortable
- [ ] `admin` 역할에 `UsageSnapshot`·`UsageEvent` **read** 권한 (없으면 앱 안 통계 화면이 빈다)
- [ ] Schema → **Deploy Schema Changes to Production** → 그 다음에 앱 심사 제출
- 이벤트 시리즈: `app_open`(신규 — 활성 사용자·리텐션의 근거), `timer_start`, `timer_complete`,
  `timer_cancelled`, `presentation_start`, `paywall_shown:*`, `paywall_converted:*`,
  `paywall_dismissed:*`, `premium_feature_used:*`, `premium_trial_exhausted:*`,
  `onboarding_shown/completed/skipped`, `preset_saved`, `preset_used`, `purchase_*`, `review_*`
  (스키마 변경 불필요 — `event` 필드에 문자열로 들어감)

## 4. 외부 분석 SDK — 없음

TelemetryDeck 은 2026-08 에 제거했다(App ID 미설정으로 실제 전송이 없었고, 사용 통계는
CloudKit 허브가 담당). 분석 관련 대시보드 작업은 3번(사용 통계)만 보면 된다.
