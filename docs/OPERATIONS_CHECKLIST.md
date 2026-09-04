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

## 5. 워치 스마트 스택 위젯 — 🚨 첫 배포 **전에** 서명 준비

`RereminderWatchWidgetExtension` 타겟이 새로 생겼고, 워치 앱과 위젯이 **앱 그룹으로** 타이머
상태를 주고받는다(`Shared/Modules/WatchTimerState.swift`). 설계 배경은 CLAUDE.md 의
"워치 스마트 스택" 절.

- [ ] Developer Portal 에 App ID `com.xa.toki.watchkitapp.widget` 생성
- [ ] **App Groups** capability 를 두 App ID 에 켜고 `group.leeo.toki` 를 배정
  - `com.xa.toki.watchkitapp` (워치 앱 — 지금까지 엔타이틀먼트가 없었다)
  - `com.xa.toki.watchkitapp.widget` (새 위젯 확장)
- [ ] 프로비저닝 프로파일 재생성 (Xcode 자동 서명이나 `xcodebuild -allowProvisioningUpdates`
      를 쓰면 자동으로 처리된다 — 수동 서명이라면 직접 내려받을 것)
- [ ] 업로드 후 TestFlight 빌드를 실기기 워치에 설치해 스마트 스택 편집 목록에 뜨는지 확인

⚠️ **앱 그룹이 한쪽에만 걸리면 조용히 실패한다** — 빌드도 되고 앱도 멀쩡히 돌지만 위젯이 늘
"활성 타이머 없음"만 보여준다(`WatchTimerStore` 가 앱 전용 저장소로 물러서기 때문). 그래서
위 두 줄은 **둘 다** 확인해야 한다.

⚠️ 위젯 확장의 `MARKETING_VERSION` 은 `Config/Version.xcconfig` 를 따라가므로 따로 맞출 것이
없다. 다만 **번들 ID 는 워치 앱 ID 로 시작해야** 한다(`com.xa.toki.watchkitapp.` + `widget`) —
어긋나면 업로드가 거부된다.

## 6. 확인할 때까지 알림 — 선택 사항(있으면 더 좋음)

되풀이 종료 알림(`Shared/Modules/EscalatingAlert.swift`)은 `interruptionLevel = .timeSensitive`
로 보낸다. 이 수준으로 **실제 전달**되려면 App ID 에 capability 가 필요하다.

- [ ] (선택) Developer Portal 에서 `com.xa.toki` · `com.xa.toki.watchkitapp` 에
      **Time Sensitive Notifications** capability 를 켜고,
      두 엔타이틀먼트 파일에 `com.apple.developer.usernotifications.time-sensitive` = true 추가

⚠️ **켜지 않아도 앱은 정상 동작한다** — 엔타이틀먼트가 없으면 시스템이 조용히 `.active` 수준으로
내려서 보낼 뿐 예약이 실패하지는 않는다. 다만 **집중 모드(방해 금지)를 뚫지 못한다.**
"놓치면 안 되는 타이머"가 이 기능의 전부이므로 켜는 쪽을 권한다.

⚠️ 엔타이틀먼트를 코드에 먼저 넣지 말 것 — capability 가 꺼진 App ID 로는 서명이 실패해
빌드가 통째로 막힌다. **포털에서 켠 뒤에** 엔타이틀먼트 파일을 고칠 것.

참고: 알림 예약은 앱당 **64개**가 상한이고 예비 알림과 같은 주머니를 쓴다. 되풀이 개수는
`EscalationSchedule.maxAlerts`(24)로 막아 두었다 — 상한을 올릴 때 이 숫자도 함께 볼 것.

## 7. 끝나면 알람으로 울리기 (AlarmKit) — 2.2.4 신규

설정 > 알림 > **끝나면 알람으로 울리기**(`Shared/Modules/RereminderAlarmManager.swift`).
설계 배경은 CLAUDE.md 의 AlarmKit 절.

- [ ] 포털 작업 **없음** — AlarmKit 은 capability 가 아니라 권한 프롬프트로 동작한다.
      문구는 `Rereminder/InfoPlist.xcstrings` 의 `NSAlarmKitUsageDescription`(ko/en/ja 번역 완료)
- [ ] App Store Connect → App Privacy 변경 **없음**(알람은 수집이 아니다)
- [ ] TestFlight 실기기 확인: 토글을 켤 때 권한 창이 뜨는지 → 거부하면 토글이 되돌아가는지
      → 켠 채로 타이머를 끝내면 **무음 스위치·집중 모드에서도** 전체 화면 알람이 뜨는지
- [ ] 타이머를 **정지**한 뒤 종료 예정 시각에 알람이 뜨지 않는지
      (`removePendingNotificationRequests` 로는 안 지워진다 — `stop`+`cancel` 둘 다 필요)

⚠️ 기본값은 **꺼짐**이다. 회의 중에 기본으로 울리면 기능이 아니라 사고다.
⚠️ Mac Catalyst·App Clip 에는 AlarmKit 이 없다(no-op 스텁 → UN 알림 경로 유지).
