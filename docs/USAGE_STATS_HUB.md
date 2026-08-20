# 사용 통계 — 공용 허브(FeedbackHub) 수집·조회

피드백과 **같은 CloudKit 컨테이너**(`iCloud.com.Ysoup.FeedbackHub`, public DB)에 익명 사용 통계를
쌓고, 앱 안(설정 > Help > **Usage Stats (Developer)**, 마스터 모드 전용)에서 그대로 읽어 본다.
별도 서버·외부 분석 SDK 없음.

- 전송 엔진: LeeoKit `LeeoUsageReporter` (**2.9.0 이상** — `occurredAt`·`installID`·`logEvent` 반환값)
- 앱 정책: `Rereminder/Modules/ActivityReporter.swift`
- 로컬 카운터: `Shared/Modules/UsageMetrics.swift`
- 집계(순수 함수): `Rereminder/Modules/UsageInsights.swift` — 테스트: `RereminderTests/UsageInsightsTests.swift`
- 조회 화면: `Rereminder/Views/UsageStatsView.swift` + `Views/Components/UsageTrendChartView.swift`

## 무엇을 보내나

| 레코드 | 언제 | 내용 |
|---|---|---|
| `UsageSnapshot` | 프로세스 시작 시, 설치당 1건 upsert (12시간 쓰로틀) | 익명 설치 UUID, 앱 버전·플랫폼·OS·로케일, 실행 횟수, 주요 행동 수, 설치 후 경과일, 마지막 활동 시각, `metrics` JSON |
| `UsageEvent` | 주요 행동 시, **이름당 6시간에 1건** (`app_open`만 20시간) | 이벤트 이름(+슬라이스), 앱 버전·플랫폼, 익명 설치 UUID, 발생 시각(`occurredAt`) |
| `Feedback` | 사용자가 피드백을 보낼 때 | 기존 LeeoKit 피드백 (변경 없음) — `docs/FEEDBACK_CLOUDKIT.md` |

`metrics` (설치당 대략 지표, 전부 숫자):
`timerStarts` `timerCompletions` `timerCancels` `focusMinutes` `presentationRuns`
`presetSaves` `presetUses` `watchSyncUses` `templates`
`flag.isPro` `flag.notificationsOn` `flag.templateUser` `flag.presentationUser` `flag.watchUser`

결제 판단용 (2.1.1 추가 — 아래 "결제 퍼널" 참고):
`alertsMax` `multiAlertRuns` `alertLimitHits` `paywallViews`
`trial.prealerts` `flag.prealertTrialExtended`

**보내지 않는 것**: 타이머 이름·알림 메시지·발표 구간 제목, 이메일·이름, 기기 식별자(IDFA/IDFV), 위치.
설치 식별은 앱이 만든 무작위 UUID(`leeo.usage.installID`)뿐이고 재설치하면 새 값이 된다.

## 횟수는 왜 이벤트가 아니라 스냅샷에 있나

이벤트에는 **이름당 6시간 쓰로틀**이 걸려 있다(공개 DB 쓰기 폭주 방지). 그래서 타이머를 하루에
열 번 돌려도 `timer_start` 이벤트는 1건이다 — 이벤트로는 "몇 번 했는지"를 셀 수 없다.

그래서 횟수는 기기에서 센다(`UsageMetrics`, `AnalyticsManager.log`가 단독으로 갱신) 그 요약을
스냅샷 `metrics` 한 필드에 실어 보낸다. 결과적으로 두 계열은 답하는 질문이 다르다:

- **이벤트** → "설치 몇 곳이 이 행동을 하나", "언제 활동했나"(퍼널·리텐션·추이)
- **스냅샷 metrics** → "몇 번 했나", "얼마나 오래 썼나"(완주율·관리한 시간·분포)

통계 화면의 퍼널·리텐션 설명에 "절대 건수가 아니라 비율을 보라"고 적혀 있는 이유다.

## 이 앱에서 무엇을 보고 판단하나

1. **완주율** (`timerCompletions / timerStarts`) — 시작한 타이머가 끝까지 갔는가.
   알림이 울릴 때까지 함께 있었다는 뜻이라, 이 앱이 실제로 쓸모를 낸 순간의 직접 지표다.
2. **완주 횟수 분포의 0회 칸** — 깔았지만 한 번도 끝까지 안 간 사람 수. 첫인상에서 새는 양.
3. **활성화 퍼널** (`app_open` → `timer_start` → `timer_complete`) — 어느 칸에서 떨어지나.
4. **알림 권한 허용률** — 알림이 이 앱의 전부다. 허용하지 않은 사람은 가치를 못 받는다.
5. **리텐션(D1/D7/D30)** — 한 번 써 본 사람이 돌아오는가.
6. **접수된 피드백** — 숫자가 "무엇이 잘못됐는지"까지 말해 주지는 않는다. 인박스와 함께 본다.
7. **결제 준비도** — 지금 알림 한도에 막혀 있는 사람 수. 아래 참고.

`app_open`은 **화면이 실제로 뜨는 경로**(`TimerUnifiedView`의 onAppear/scenePhase)에서만 남긴다.
프로세스 시작(`reportProcessStart`)에서 남기면 위젯·알림 처리로 깨어난 것까지 접속으로 잡혀
활성 사용자와 리텐션이 부풀어 오른다.

## 결제 퍼널 — 왜 "알림 개수"인가

이 앱의 결제는 **알림을 몇 개까지 켤 수 있나**로 갈린다(무료 1개 → 5+5 체험 → 결제, `ProGate`).
그래서 "결제에 가까운 사람"은 곧 **알림 한도에 다가간 사람**이고, 통계도 그 거리를 잰다.

⚠️ 이 계산은 **이벤트가 아니라 스냅샷**으로 한다. 이벤트에는 이름당 6시간 쓰로틀이 걸려 있고
과거형이라 "**지금** 몇 명이 결제 직전인가"를 셀 수 없다. 스냅샷은 설치당 1건 upsert라 현재 상태다.
(화면에는 둘 다 있다 — "결제 퍼널(지금 상태)" = 스냅샷, "결제 이벤트(기간 누적)" = 이벤트.
숫자가 다른 게 정상이다.)

계산은 전부 `UsageInsights`의 순수 함수 (`profiles` / `paymentFunnel` / `purchaseReadiness` /
`hotLeads` / `alertDemandDistribution` / `segmentCounts`) — 테스트는 `UsageInsightsTests`.

### 사용자 구분 (`PaymentStage`) — 결제에 가까운 쪽부터

| 구분 | 판정 | 뜻 |
|---|---|---|
| `pro` | `flag.isPro` | 결제함 |
| `blocked` | 남은 체험 0 또는 `alertLimitHits > 0` | **지금 결제해야 알림을 더 켜는 사람** |
| `nearLimit` | 남은 체험 1~2 | 곧 막힌다 |
| `trialing` | 유료 영역을 건드림(체험 사용·알림 2개 이상) | 아직 여유 있음 |
| `demand` | 무료 범위인데 완주 3회 이상 | 곧 필요해질 사람 |
| `freeFit` | 완주 1회 이상 | 알림 1개로 충분 — 지금 구조로는 결제 안 함 |
| `dormant` | 완주 0회 | 결제 이전에 첫 성공이 먼저 |

남은 체험 = (체험 연장 수락 시 10, 아니면 5) − `trial.prealerts`. **한도 상수는 앱에서 계산해
보내지 않는다** — 원자료만 보내고 해석은 `UsageInsights`가 한다(상수가 바뀌면 과거 스냅샷의
뜻까지 바뀌면 안 되므로).

### 퍼널 여섯 칸

설치 → 가치 경험(완주 1회+) → 알림 2개 이상 → 한도 도달·임박 → 페이월 노출 → 결제.
**결제자는 앞 단계를 모두 지난 것으로 센다**(결제 후에는 체험 카운터가 오르지 않아 그냥 세면
퍼널이 뒤집힌다).

### 근접도 점수 (`readiness`, 0~100)

명단 **정렬용 순서값이지 결제 확률이 아니다.** 막혀 있을수록·막힌 경험이 많을수록·실제로 쓸수록
올라가고, 한 달 넘게 안 들어온 사람은 내린다(떠난 사람에게 파는 건 계산이 아니다).
명단은 통계 화면 → "사용자 구분" / "결제 후보 명단 보기" (`UserSegmentListView`),
익명 설치 ID 앞 8자리만 보여준다.

### 알림 개수 수요 분포

`alertsMax`(한 타이머에 걸어 본 알림 최대 개수)로 설치를 나눈다. **무료 한도 1개 바로 위 칸이
크면 지금의 가격 경계가 매출을 만든다는 뜻이고, 1개 칸만 크면 한도를 조여도 결제는 늘지 않는다.**
"기록 없음" 칸은 2.1.1 이전 버전이라 아직 이 값을 안 보낸 설치다 — 새 스냅샷이 올라오면 줄어든다.

## 기간별 차트 (일·주·월·연)

"기간별 추이"는 **UsageEvent의 `occurredAt`** 으로 만든 시계열이다
(`ActivityReporter.trend(unit:events:installDates:)`, 빈 구간까지 채워 차트가 끊기지 않게 함).

- 표시값 3가지: **활동한 사용자**(구간 내 서로 다른 installID) / **사용 건수**(이벤트 수) /
  **신규 사용자**(스냅샷 `installDate` 기준)
- 한 화면에 일 14 / 주 12 / 월 12 / 연 5개, 좌우로 넘기면 그 단위만큼 과거로 이동한다.
- 막대를 탭하면 그 구간의 정확한 날짜와 값이 글자로 나온다(막대 높이로는 3인지 4인지 못 읽는다).
- 이벤트 조회는 커서로 최대 3,000건까지 이어 받는다. 그보다 오래된 구간은 차트에 안 나온다.

⚠️ `creationDate`가 아니라 `occurredAt`을 본다. `creationDate`는 서버가 "쓴 시각"을 찍는다.
`occurredAt`이 없는 구버전(LeeoKit 2.7 이하) 레코드는 `creationDate`로 떨어진다(하위 호환).

## 스키마와 새 지표

`metrics`는 **JSON 문자열 한 필드**다. 그래서 위 결제 지표처럼 키를 늘려도 CloudKit 스키마 배포는
필요 없다(레코드 필드가 늘지 않는다). 반대로 키 **이름을 바꾸면** 과거 스냅샷과 합산되지 않아
지표가 조용히 반토막 난다 — `UsageMetrics.Key`는 서버·과거 스냅샷과의 계약이다.

## 🚨 `occurredAt` / `installID` 필드, 앱을 내보내기 **전에**

Production 스키마는 잠겨 있다. 레코드 타입에 없는 필드를 담아 저장하면 **그 저장이 실패한다.**
두 필드는 모든 `UsageEvent`에 들어가므로, 스키마 배포 전에 앱이 먼저 나가면 이벤트 전송이
통째로 실패한다(스냅샷은 무사).

반드시 이 순서로:

1. 새 빌드를 **Development 환경**에서 실행하고 타이머를 한 번 돌린다
   → `UsageEvent`에 `occurredAt`(Date) / `installID`(String) 필드가 자동 생성된다.
2. CloudKit Dashboard에서 필드가 생겼는지 눈으로 확인한다.
3. **Schema → Deploy Schema Changes to Production.**
4. 그 다음에 앱을 심사에 올린다.

## CloudKit Dashboard 준비 (1회)

https://icloud.developer.apple.com → `iCloud.com.Ysoup.FeedbackHub`

1. **스키마 생성**: Development에서 앱을 한 번 실행(스냅샷)하고 주요 행동을 한 번 하면
   `UsageSnapshot` / `UsageEvent` 레코드 타입이 자동 생성된다.
2. **인덱스**:
   - `UsageSnapshot`: `recordName` **Queryable**
   - `UsageEvent`: `recordName` **Queryable** + `createdTimestamp` **Sortable**
   - `appId`는 인덱스 없이 클라이언트에서 필터한다(인덱스 배포를 늘리지 않기 위함).
3. **Security Roles**: `_world`는 create만, read 제거. `admin` 역할에 read + 개발자 본인
   userRecordName 등록 (피드백 인박스 하단에서 복사 가능).
4. **Production 배포**: Schema → Deploy Schema Changes to Production.

배포 전에는 통계 화면이 "불러오지 못했어요 / read 권한 필요" 안내를 보여준다(정상).
읽기에 실패한 항목만 비고, 성공한 항목은 그대로 표시된다.

## 끄는 방법 (사용자 옵트아웃 없음)

사용자가 끄는 설정은 두지 않는다(앱 소유자 결정). 대신 **원격 킬스위치**로 즉시 멈춘다:
`RemoteFlags` 레코드의 `usageReportingEnabled`를 0으로 (→ `docs/OPERATIONS_CHECKLIST.md`).
조회 실패 시엔 켬으로 동작하고 갱신은 6시간 쓰로틀이라 즉시 전파되지는 않는다.

⚠️ 심사 가이드라인 5.1.1(ii)(사용 데이터 수집 동의)와 GDPR/ePrivacy(설치 식별자 저장) 관점에서
지적 여지가 있는 선택이다. 리젝되면 옵트아웃 토글이 가장 빠른 해법이다.

## App Store 제출 시

- App Privacy: Data Type **Product Interaction(Usage Data)**, 목적 Analytics,
  **사용자와 연결되지 않음**, 추적(Tracking) 아님(ATT 불필요).
- 앱 안에 끄는 스위치가 없으므로 개인정보 처리방침에 수집 항목·목적·보관을 명시할 것.
