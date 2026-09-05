# Rereminder 작업 메모

## 완료 (이번 라운드)
- [x] **App Clip 을 업로드에서 잠시 뺀다** (타겟은 남기고 연결만 끊음)
  - `Embed App Clips` 항목 + 메인 앱 `dependencies` 두 줄 제거 → `Rereminder.app/AppClips/` 가
    생기지 않는 것으로 확인. 워치 앱·위젯 확장 임베드는 그대로
  - 되살리는 법은 `CLAUDE.md` 의 App Clip 절 머리말에 적어 뒀다 (정의는 pbxproj 에 남겨 둠)
  - iOS·Mac Catalyst 빌드 성공, 테스트 311개 통과
  - [ ] ⚠️ **App Store Connect 쪽은 따로 정리해야 한다** — 빌드에서 빠질 뿐, 이미 등록된
        App Clip 경험·AASA(`m1zz.github.io`)는 그대로 남는다
- [x] **"프로모션 코드를 썼는데 여전히 결제하라고 뜬다" — 원인 3개 수정**
  - ① **가장 큰 것: 구매 기록이 실패한 조회 한 번에 지워졌다.** `syncFromStore` 가
    `store.hasPro` 를 그대로 미러링해 false 를 Keychain 에 적었는데,
    `Transaction.currentEntitlements` 는 App Store 로그아웃·기기 초기화 직후에도 조용히 빈 값을
    낸다 → **돈 낸 사람의 평생 해제가 지워지고 페이월이 다시 떴다**
    → 기록을 **래치**로 바꿈. 내리는 근거는 `Transaction.all` 로 확인한 **회수(환불)** 하나뿐
    (`isRevoked(proTransactionRevocationDates:)` 순수 함수)
  - ② **`ProGate` 가 static 이라 SwiftUI 가 다시 그리지 않았다** — 구매·복원·코드 교환이 끝나도
    자물쇠가 그대로 남아 앱을 껐다 켜야 풀렸다 → 게이트를 읽는 뷰 5곳에
    `@ObservedObject StoreManager.shared` 추가 (`TemplateQuickBar`·`TimerTemplateView`·
    `TimerHistoryView`·`OnboardingFlowView`·`NoticeSettingView`)
  - ③ **전경 복귀 시 권한을 다시 확인하지 않았다** — `verifyCurrentEntitlements` 는 정의만 있고
    **호출부가 0곳**이었다. 코드 교환은 언제나 "앱 → App Store → 복귀"인데 복귀에서 아무것도
    안 했다 → `handleScenePhase(.active)` 에서 호출
  - 덤: `loadProducts` 도 호출부가 0곳이라 페이월 가격이 빈 문자열로 뜰 수 있었다
    → `PaywallView.task` 에서 로드
  - 테스트 9개 추가(`StorePurchaseLatchTests`), 전체 **311개 통과** / iOS·Mac Catalyst 빌드 성공 /
    다국어 검사 통과
  - [ ] ⚠️ **실기기 확인 필요** — 인앱결제 프로모션 코드를 실제로 교환해 앱 복귀만으로 풀리는지
  - [ ] ⚠️ 제보자에게 먼저 확인할 것: 준 코드가 **앱** 코드인가 **인앱결제** 코드인가
        (앱은 원래 무료라 앱 코드는 Pro 를 열지 않는다)
- [x] **"템플릿이 저장되지 않는다" 제보 — 원인 2개 수정**
  - ① **진짜 원인: SwiftData 스토어가 아예 열리지 않았다.** `.modelContainer(for:)` 의 기본값이
    CloudKit 자동 동기화라, 피드백 허브용 iCloud 엔타이틀먼트(2026-07-19)가 붙은 뒤로
    `Timer`/`TimerRecord` 가 CloudKit 스키마 규칙(optional·관계 optional·unique 금지)에 걸려
    **스토어 로드 실패 → 템플릿·기록이 하나도 저장되지 않음**. 화면에는 오류가 안 뜨고
    콘솔에만 `Store failed to load` 가 찍혀 조용히 깨져 있었다
    → `RereminderApp.sharedModelContainer` (앱 그룹 경로 유지 + `cloudKitDatabase: .none`)
  - ② 무료 사용자의 템플릿이 **지워지고 있었다** — "저장은 Pro"를 한도 0 으로 구현해서,
    타이머를 한 번 시작하면 정리 루프가 시드 템플릿까지 전부 삭제. 판정을 `saveIfNeeded`
    첫 줄로 올려 무료는 **저장도 삭제도 하지 않게** 함
  - 덤: 중복 판정을 전체 템플릿 + 정규화된 오프셋 기준으로(같은 설정이 복사본으로 쌓이던 문제),
    "저장됨" 토스트는 실제로 저장됐을 때만
  - 테스트 5개 추가(`TemplateSaveTests` — 실제 앱 컨테이너가 열리는지까지 검증), 전체 통과
  - **버전 2.2.3 (빌드 1)** + 릴리즈 노트 `docs/release-notes-2.2.3-{ko,en,ja}.md`
  - [ ] ⚠️ **실기기에서 눈으로 확인 필요** — 2.0.x 부터 저장이 안 됐으므로 기존 사용자의
        템플릿·기록은 그 사이 쌓인 게 없다(스토어에 도달한 적이 없음)
- [x] **업로드 거부 2건 해결 — iPad 를 지원하지 않으면서 Mac Catalyst 유지**
  - Catalyst 를 켜며 딸려온 iPad(`2`)가 iOS 빌드까지 번져 두 번 거부됨:
    ① App Clip 기기 종류가 부모(`[1,2]`)와 달랐고(`[1]`), ② iPad 를 넣으면 `..._iPad` 방향
    네 개를 전부 적어야 함(멀티태스킹)
  - iPad 화면·스크린샷이 없으므로 **iPad 를 지원하지 않는 쪽**으로 정리:
    `TARGETED_DEVICE_FAMILY = 1` + `"TARGETED_DEVICE_FAMILY[sdk=macosx*]" = "2,6"`
    (메인 앱·위젯 확장, 클립은 `1`)
  - 확인: iOS 빌드 `UIDeviceFamily = [1]`(앱·클립·위젯 모두) / Catalyst 빌드 `[6]`, 양쪽 빌드 성공
- [x] **버전 2.1.1 (빌드 1)**
- [x] **종을 놓을 때 튀던 애니메이션 제거** (메인 앱 + App Clip)
  - 원인 ①: `ForEach` id 가 알림 초라서 옮긴 값을 지웠다 넣으면 SwiftUI 가 "다른 종"으로 보고
    `.transition(.scale + .opacity)` 를 재생 → 손 떼는 순간 종이 사라졌다 나타남
    → 놓는 순간의 상태 변경을 `Transaction.disablesAnimations` 로 감쌈 (지우는 경우는 그대로 페이드)
  - 원인 ②: 종 크기가 `isDraggingThis` 를 따라 2.0 → 1.6 으로 즉시 줄어듦
    → `isFocused`(배지 유지 중) 기준으로 바꿔 배지가 녹을 때 같이 작아지게
  - iOS·Mac Catalyst·App Clip 빌드 + 전체 게이트 통과 / **손드래그는 눈으로 미확인**(자동 드래그 불가)
- [x] **맥에 앱이 설치 안 되던 이유 확인 + 복구** — 메인 타겟이 맥용으로 빌드되지 않고 있었음
  - `SUPPORTS_MACCATALYST=NO`, `TARGETED_DEVICE_FAMILY=1` (2026-07-26 `8a4dd74` 에서 의도적으로 끔)
  - 되돌림: `YES` / `"1,2"` → **Catalyst 빌드 성공, 맥에서 실행·창 표시 확인**
  - App Clip 임베드에 `platformFilter = ios` 추가 (없으면 "iOS content in macOS target" 로 빌드 실패)
  - 맥에서는 맥 연결 칩·상태 줄을 감춤 (자기 자신은 세지 않아 늘 "연결 안 됨"으로 보임)
  - [ ] **App Store Connect 에 macOS 플랫폼 추가 + 별도 심사 필요** — 빌드 설정만으로는 스토어에 안 나옴
  - [ ] ⚠️ iOS 배포 타깃 26.0 → 맥은 **macOS 26 이상**만 설치 가능. 더 낮추려면 iOS 타깃부터 낮춰야 함
- [x] **구간별 카운트다운 리스트** (원 아래) — 45분=20+25면 앞 20:00만 줄고 25:00은 서 있다가
      경계 지나면 줄어듦. 글자 색 = 링 구간 색, 지금 구간만 100%(예정 55%·지난 30%)
  - 계산은 `TimerSections.phase` / `remainingSeconds` (테스트 3개)
  - 알림이 하나뿐이면 기존 "다음 알림" 안내가 그대로 선다
  - **시뮬레이터에서 확인** — 진행 중 8:56(파랑, 지금) / 1:00(초록, 대기) → 경계 후 ✓0:00 / 0:54
- [x] **"동기화는 되는데 연결 안 됨" 수정**
  - 워치: `isReachable`(워치 앱이 지금 떠 있나)로 판단하던 것 → **페어링 + 워치에 앱 설치**로 변경.
    타이머는 `updateApplicationContext`로 워치 앱이 꺼져 있어도 넘어가므로 도달성은 틀린 기준이었음
  - 맥: 심장박동 표시(2.1.1+)가 없어도 **타이머 동기화 스냅샷**을 증거로 읽음.
    스냅샷에 `sourcePlatform` 추가 (구버전 스냅샷은 종류를 몰라 못 셈 — 양쪽 다 업데이트되면 해결)
  - 맥은 앱이 뒤로 가도 표시를 멈추지 않음 (메뉴 막대 앱이라 창이 뒤에 있어도 쓰는 중)
  - 판정을 순수 함수로 분리(`WatchLinkStatus.resolve`, `DevicePresence.entries(presence:syncSnapshot:)`)
    + 테스트 8개
- [x] **연결 안내 화면** (`DeviceConnectionHelpView`) — "연결 안 됨"을 누르면 뭘 해야 하는지
  - 지금 상태(페어링 없음/앱 없음/연결 안 됨) + 순서대로 할 일 + **다시 확인** + 기기별 활용 안내
  - 칩과 설정 > 내 기기의 상태 줄이 같은 화면으로 들어감
  - 맥 안내에는 "연결됨 = 최근 10분 안에 켜져 있었다"는 뜻을 명시
  - **시뮬레이터에서 워치·맥 안내 화면 둘 다 눈으로 확인** (System Events 클릭으로 실제 탭)
  - `DeviceOwnership.defaults` 주입구 추가 — 테스트가 앱 실제 저장소를 쓰다가 시뮬레이터에
    남아 있던 값 때문에 실패했음. 이제 테스트마다 빈 suite
- [x] **기기 연결 상태 칩** (`DeviceLinkChips`) — 대기 중에도, 실행 중에도 원 아래에
  - "있어요"라고 답한 기기만, **안 될 때만 글자**("연결 안 됨"), 연결되면 초록 심볼만
  - 타이머 시작 순간·iCloud 표시 변화 때 다시 읽음
  - **대기 화면에서도 확인** — 걸기 전에 고칠 수 있어야 의미가 있다 (발표 모드에서만 숨김)
  - **시뮬레이터에서 워치·맥 둘 다 "연결 안 됨" 칩 확인**
- [x] **레거시 삭제** — `Clock.swift`·`ClockMarkers.swift`·`TimerRunningView.swift` (아무도 안 씀)
  - 종 노브 아래 깔려 있던 주황 **작대기(Rectangle)** 제거 — 알림이 울려 종이 흐려지면(0.35)
    작대기만 진하게 남아 "종 밑에 직사각형"으로 보였음. 클립(`ClipClock`)에는 원래 없었음
  - 딸려 있던 접근성 문자열 3개도 카탈로그에서 제거(stale 게이트)
- [x] **진행 중 링 구간 색 유지** — 시작하면 단색이 되던 걸 구간 색 그대로 쓰게
  - `showsAlertSectionColors`가 이제 오버타임에서만 꺼짐 (대기·실행·일시정지 모두 구간 색)
  - 구간 번호 역매핑을 `TimerSections.ringSectionIndex`로 분리 — 자리 번호로 세면 진행 중
    지나간 경계가 빠지면서 색이 한 칸씩 밀린다 (테스트 4개)
  - 구간 번호(1·2·3)는 대기 중에만 (진행 중엔 번호만 바뀌어 어지러움)
  - **시뮬레이터에서 실행 중 초록/파랑 구간이 유지되는 것 확인** (5:12 남았을 때 스크린샷)
- [x] **기기 연결 상태 심볼** — 설정 > 내 기기에서 "있어요"라고 한 기기만
  - 워치: `WatchConnectivityManager.linkStatus` (페어링 없음/워치에 앱 없음/닿지 않음/연결됨)
  - 맥: `DevicePresence` — iCloud KVS에 5분마다 남기는 표시를 읽어 10분 안쪽이면 연결됨
    (실시간 연결이 아니라 "최근에 켜져 있었다"는 뜻 — 앱이 앞에 있는 동안만 표시를 남긴다)
  - [ ] **설정 화면 눈으로 미확인** — 시뮬레이터 자동 탭이 안 돼 화면 이동 불가
- [x] **워치·맥 보유 질문** (`DeviceOwnership`) — 타이머가 돌기 시작할 때 한 번 묻는다
  - 워치 먼저, 하루 뒤 맥. 답은 설정 > **내 기기**에 저장되고 거기서 바꿀 수 있음
  - **"없어요" → 그 기기는 질문도 안내도 끝.** "있어요" → 바로 "이제 워치에서도 확인하세요" 토스트
  - 있다고 했는데 아직 그 기기에서 안 써 봤으면 타이머 걸 때 5회 간격·최대 3회로 권함
  - 페어링된 워치(`WCSession.isPaired`)·맥 실행은 안 묻고 확정 / 워치에서 조작 오면 사용 확정
    (이때 `watchSyncUsed`도 처음으로 기록 — 그 전까지 통계의 워치 지표가 늘 0이었음)
  - ko/en/ja 문구 17개 추가, 테스트 10개, **시뮬레이터에서 질문 알림·안내 토스트 눈으로 확인**
  - [ ] 설정 화면의 "내 기기" 섹션은 빌드만 확인 — 시뮬레이터 자동 탭이 안 돼 눈으로는 미확인
- [x] **통계 → 결제 퍼널 재편** ("지금 결제에 가까운 사람이 몇 명인가"에 답하게)
  - 이 앱의 결제 경계는 **알림 개수**(무료 1개 → 5+5 체험 → 결제) → 통계도 그 거리를 잰다
  - 수집: `alertsMax`·`multiAlertRuns`·`alertLimitHits`·`paywallViews` (UsageMetrics),
    `trial.prealerts`·`flag.prealertTrialExtended` (ActivityReporter 스냅샷)
    → `metrics`는 JSON 한 필드라 **CloudKit 스키마 배포 불필요**
  - `AnalyticsManager.timerStarted`에 `alertCount` 추가 (TimerEngine이 실제 알림 수를 넘김)
  - 집계: `UsageInsights.profiles / paymentFunnel / purchaseReadiness / hotLeads /
    alertDemandDistribution / segmentCounts` (순수 함수, 테스트 9개 추가 — 전체 통과)
  - 화면: "결제 준비도(지금)"·"결제 퍼널(지금 상태)"·"알림 개수 수요"·"사용자 구분" 섹션,
    기존 이벤트 퍼널은 "결제 이벤트(기간 누적)"으로 이름 분리
  - **유저 구분**: `UserSegmentListView` — 구분별 명단(익명 ID 앞 8자리, 알림 최대 개수·
    막힌 횟수·남은 체험·마지막 활동·근접도)
  - 문서: `docs/USAGE_STATS_HUB.md`에 결제 퍼널·구분 규칙·근접도 정의 추가
  - [ ] **실제 데이터 확인 미완** — 새 지표는 앱이 나간 뒤 스냅샷이 올라와야 채워진다.
        그 전까지 "알림 개수 수요"는 대부분 "기록 없음" 칸에 몰린다(정상)

## 완료 (이전 라운드)
- [x] **버전 2.0.6**
- [x] **알림 배지 두 줄로 확장** — 종을 옮길 때 한 지점을 두 가지로 읽어줌
      (5분 발표 + 종료 1분 전 종 → ▶ 4:00 / ⚑ 1:00)
  - 위 줄 `▶` = 시작 후 경과(강조색), 아래 줄 `⚑` = 종료 전 남은 시간(주황)
  - 링도 종을 경계로 두 색으로 갈라져 어느 숫자가 어느 구간인지 바로 보임
  - 종이 여러 개면 잡고 있는 것 외에는 25% 로 흐려짐
  - 메인 앱(`TimerMainView`)·App Clip(`ClipClock`) 양쪽 동일 적용
  - 시뮬레이터에서 배지 + 링 분할 확인 완료 / **여러 개일 때 흐려지는 건 미확인**
  - 시간 글자 키움 (subheadline → title3 bold), 배지 거리 반지름+52 로 조정
  - 줄 순서: 주황(종료 전)이 위, 파랑(시작 후)이 아래
  - 물러날 때 종 노브뿐 아니라 **작대기 마커도 같이** 흐려짐 (`ClockMarkers.dimmedIndices`)
  - 손 뗀 뒤 유지 시간 5초 → **3초**, 이후 0.35초 디졸브로 전부 원래대로 (배지·링 강조·흐림 동시)
- [x] **소개 페이지 → App Clip 체험 페이지 링크** (`docs/index.html`)
  - 상단 내비 + 모바일 메뉴 "바로 써보기", 히어로 보조 CTA "설치 없이 바로 써보기", 푸터 링크
  - en/ko 번역 키 4개 추가 (`nav.tryClip`·`hero.ctaClip`·`hero.clipNote`·`footer.tryClip`)
  - 헤드리스 크롬으로 데스크톱 렌더링 확인 (모바일 폭 오버플로는 원본에도 있던 헤드리스 아티팩트)
  - [ ] **푸시해야 반영됨** — `docs/` 는 이 저장소 GitHub Pages(`/Rereminder/`)
- [x] **알림 칩 목록: 새 알림이 생기면 그 칩으로 자동 스크롤**
  - 전에는 `+` 버튼으로 추가할 때만 스크롤했음 → 링에서 종을 끌어 만든 알림·템플릿 적용도 포함
  - `displayOffsets` 변화에서 "새로 들어온 것"을 직접 계산 (`pendingScrollOffset` 상태 제거)
  - 여러 개가 한꺼번에 들어오면 가장 큰(=가장 오른쪽) 것을 기준으로 스크롤
  - **시뮬레이터 자동 입력이 계속 실패해 눈으로 미확인** — 손으로 `+` 눌러 확인 필요
- [x] **다이얼 아래 바: 초기화 버튼 추가 + 저장 버튼 노출 조건 수정**
  - 갓 설치한 기본 설정(10분 + 1분 전 알림 하나) 그대로면 **두 버튼 다 숨김**
    (전에는 저장 버튼이 손 안 대도 떠 있었음)
  - 저장 버튼 왼쪽에 **초기화** — 갓 설치했을 때의 설정으로 되돌림, 재실행해도 유지
  - 기준값은 `TimerScreenViewModel.DefaultSetup` 한 곳 (초기값·판정·초기화가 전부 여기서)
  - 번역 2개 추가 (ko/ja), `DefaultSetupResetTests` 7개 통과 / 전체 79개 통과
- [x] **App Clip 한 화면 레이아웃** — 원 크기 최우선, 스크롤 없이 전부 보이게
  - 원 크기를 높이 고정 비율(0.38) → **남는 자리 전부**(GeometryReader)로 변경
  - `min(폭 × 0.88, 높이 − 48×2)` — 0.88 은 종 노브가 가장자리에서 안 잘리게 하는 몫
  - 원만 좌우 화면 여백을 되찾아 씀(`-DSSpacing.xl`) + 배지가 위로 겹치게 `zIndex(1)`
  - iPhone 17 Pro 시뮬레이터에서 한 화면에 다 들어오는 것 확인 (원 지름 354pt)
  - **작은 화면(SE 등) 미확인** — 시뮬레이터 런타임이 없음. 다만 남는 자리 기준이라 넘칠 일은 없음
- [x] **다이얼 드래그 튐 수정** — 흰 핸들·종 노브 공통
  - 잡는 순간 노브가 손끝으로 순간이동하던 것 → `startLocation` 으로 grab delta 를 기억해 제자리 유지
  - 범위 밖으로 끌면 반대편으로 순간이동하던 것 → 잘린 각도를 되먹이지 않고 손가락만 이어 붙임
    (종을 총 시간 너머로 / 흰 핸들을 0 아래로 끌 때 재현)
  - 회전에 휘둘리던 제스처 좌표계 → 이름 붙인 고정 좌표계 + `ringAngle` 로 명시 계산
  - 드래그 중 `withAnimation(.linear(0.3))` 제거 (손가락보다 늦게 따라오던 미끄러짐)
  - **실기기/시뮬레이터 손드래그 확인 필요** — 자동 입력이 불안정해 미검증

## 완료 (App Clip 라운드)
- [x] `dev` 스태시 팝 충돌 해결 — 철 지난 Mac Catalyst 레이아웃(스태시) 버리고 발표 모드 쪽(upstream) 채택
      (`TimerMainView.swift`, `TimerUnifiedView.swift`)
- [x] **App Clip 타겟 `RereminderClip` 추가** (`com.xa.toki.Clip`, 메인 앱에 임베드)
  - 메인 앱과 같은 다이얼 UX — 흰 핸들로 시간, 종 노브를 끌어 알림 지점 조절 (절대 각도 1°=10초)
  - 알림 지점 기본값은 자동 배분 (`ClipAlertPlanner`) — 30분 → 10분·5분·1분 전
  - 종끼리 겹치지 않도록 최소 간격 150초(15°) 강제 — 못 만들면 3개보다 적게
  - 문구 한국어화: 헤더 "종 모양을 움직여서…", 하단 "발표 모드·템플릿·기록은 전체 앱에서"
  - `TimerEngine`·`ThemeManager`·디자인 시스템을 메인 앱과 공유 (동기화 그룹 멤버십으로 재사용)
  - 시계는 `ClipClock`으로 직접 구현 — 메인 화면이 공유 `Clock.swift`를 안 쓰기 때문
    (공유 `Clock`은 선 8pt 고정·노브 없음이라 오히려 앱과 달라 보임)
  - 테마 적용(`.tint` + `.preferredColorScheme`)으로 앱과 같은 블루·다크
  - `APPCLIP` 컴파일 조건으로 App Group·위젯·분석(ProGate 의존) 코드 제외
  - 호출 URL `?minutes=N` 지원, 종료 시 `SKOverlay`로 전체 앱 유도
- [x] 시뮬레이터에서 실행·카운트다운·알림 권한 요청까지 확인, iOS 빌드 2종 성공

## App Clip 후속 (확인 필요)
- [x] `com.xa.toki.Clip` App ID·프로파일 — Xcode 자동 서명이 생성, 아카이브 성공 확인
- [x] **도메인 연결 — GitHub Pages 배포 완료** (`M1zz/m1zz.github.io`, 커밋 `60166a3`)
      - AASA `appclips.apps` 에 `QGAQ3AY3R3.com.xa.toki.Clip` 병합 (FindMe 항목 유지)
      - 랜딩 페이지 `https://m1zz.github.io/rereminder/` — HTTP 200 확인
      - 초대 URL: `https://m1zz.github.io/rereminder/` (`?minutes=N` 지원)
- [x] **Apple CDN 반영 확인 완료** (2026-07-29)
      `curl https://app-site-association.cdn-apple.com/a/v1/m1zz.github.io`
      → `QGAQ3AY3R3.com.xa.toki.Clip` 있음 (FindMe 항목도 유지됨)
- [ ] **실기기**: 임시 알림 권한(8시간)으로 백그라운드 알림이 실제로 오는지
- [ ] 원 확대 후 다이얼·종 드래그 손으로 재확인 (시뮬레이터 자동 입력이 먹통이라 미검증)
- [x] **버전 2.0.5 + 중앙 관리 정상화** — 전 타겟이 `Config/Version.xcconfig` 하나만 읽음
      (아카이브 산출물 4종 모두 2.0.5 build 1 확인)
- [x] App Clip 카드 헤더 이미지 `web/appclip-card-1800x1200.png` (생성 스크립트 동봉)
- [x] **2.0.5 App Store 출시됨** (2026-07-28, `itunes.apple.com/lookup?id=6752551268` 확인)
- [ ] TestFlight 업로드 전 빌드 번호 올리기: `./scripts/update_version.sh --build-only`
- [ ] `SKOverlay` 전체 앱 유도 배너 동작 (시뮬레이터에서는 확인 불가)

## App Clip Code 가 "사용할 수 있는 데이터 없음" (2026-07-29, 미해결)

`https://m1zz.github.io/rereminder/` 로 App Clip Code 를 만들었는데 카메라가 못 읽음.
**앱 쪽은 전부 정상**이므로 아래를 다시 뒤지지 말 것:

- [x] Apple CDN 의 AASA 에 `QGAQ3AY3R3.com.xa.toki.Clip` 있음
- [x] 랜딩 페이지 HTTP 200
- [x] 클립 엔타이틀먼트 `appclips:m1zz.github.io`
- [x] 2.0.5(클립 포함) App Store 출시됨

남은 원인은 **App Store Connect 의 고급 App Clip 경험(Advanced App Clip Experience)** 뿐:

- [ ] App Store Connect > 두번알림 > App Clip > 고급 App Clip 경험에
      `https://m1zz.github.io/rereminder/` 등록 (헤더 이미지 1800×1200, 부제, 액션 버튼)
- [ ] 등록 후 **심사 통과 → "배포 준비됨"** 이 되어야 실제로 열림 (심사 중에는 계속 실패)
- [ ] 코드에 넣은 URL 과 등록 URL 이 **정확히** 같은지 (https / 소문자 `rereminder` / 끝 슬래시)

승인 전에 실기기로 확인하려면 로컬 경험을 쓸 것:
설정 > 개발자 > App Clips Testing > Local Experience
→ URL Prefix `https://m1zz.github.io/rereminder/`, Bundle ID `com.xa.toki.Clip`
(개발자 모드 켜고, Xcode 로 클립을 기기에 설치해 둔 상태여야 함)

## 해결됨 — 버전 관리가 망가져 있던 이유 (2026-07-27)
1. `Version.xcconfig` 가 **두 개**였음. 프로젝트는 루트의 것(2.0.3)을,
   스크립트·문서는 `Config/` 의 것(2.0.4)을 봄 → 루트 파일 삭제, 프로젝트가 `Config/` 를 보도록 변경
2. 타겟마다 `MARKETING_VERSION` 을 하드코딩해 xcconfig 를 덮어씀 → 전부 제거
3. `update_version.sh` 가 존재하지 않는 `Toki.xcodeproj` 를 가리킴 → 죽은 코드 제거

**앞으로**: 타겟 Build Settings 에 버전을 넣지 말고, 루트에 `Version.xcconfig` 를 만들지 말 것.

## 완료 (이번 세션)
- [x] 머지 충돌 해결 + Toki.xcodeproj 잔재 정리
- [x] 메인 화면 VoiceOver 접근성 개선 (장식 숨김 / 다이얼 위·아래 스와이프 시간조정 / 상태+시간 통합 라벨)
- [x] 타이머 ↔ 프레젠테이션 좌우 스와이프 페이지네이션 (실행 중 잠금)
- [x] 상단 버튼 3개 → 하단 바로 이동 (기록·예비알림·메시지·설정)
- [x] 예비알림을 메인에서 분리 → 종모양 버튼 시트(`PrealertSettingsView`)
- [x] 빠른설정: 사용자 편집 가능, 3개만 표시 (길게 눌러 편집)
- [x] 예비알림 프리셋: 추가(+)·삭제(길게 눌러 제거) 가능 — `PresetStore`(UserDefaults) 영구 저장
- [x] 다국어 정리: 한국어 158개 + 일본어 138개 누락 번역 채움 (en/ko/ja 100%)

## 완료 (Mac 확장 라운드)
- [x] 개발자/macOS 환경 Pro 자동 부여 (`StoreManager.isDeveloperUnlock` — macOS=on, iOS DEBUG는 `dev.forcePro` 토글)
- [x] 발표모드 하단 버튼 ↔ 페이지 인디케이터 겹침 수정 (페이지 양쪽에 하단 여백 확보)
- [x] ~~**Mac Catalyst 활성화**~~ → **2026-08-02: Mac Catalyst/iPad 지원 해제됨**(커밋 8a4dd74, SUPPORTS_MACCATALYST=NO). 아래 Mac 관련 항목은 전부 보류.
- [x] Mac 창 크기 제약 + 타이틀바 정리 (`ContentView.configureMacWindowIfNeeded`)

## Mac 후속 (네이티브 레이어 — 추후)
- [ ] 메뉴바 타이머(`MenuBarExtra`) — Catalyst엔 없어 별도 native 처리 필요
- [ ] 다중 동시 타이머 / 외부 디스플레이 발표 모드 / 전역 단축키
- [ ] CloudKit 동기화(템플릿·히스토리·프리셋·테마)
- [ ] Mac 키보드 커맨드(`.commands`) — 시작/일시정지 ⌘ 단축키

## 구간 표시 선형화 (진행 중)
- [x] `SectionBarLayout` — 구간 폭·재생헤드 자리 계산(순수 함수, 테스트 9개)
- [x] `SectionProgressBar` — 원 아래 완전 선형 구간 막대(길이 = 구간 길이, 흰 표시 = 지금)
- [x] `TimeMapper.clockText` — 한 시간 넘는 구간 표기("1:05:00") 단일화
- [x] `TimerMainView` 실행 중 표시를 리스트 → 막대로 교체
- [x] HTML 미리보기로 모양 비교 (시나리오 6개 · 노브 12개 · 코드 값 출력)
- [x] 🐛 숫자 겹침 판정을 칸 프레임 → **글자가 덮는 범위**로 수정 — 칸 사이 간격(3pt)이
      판정 여백(6pt)보다 좁아 **바로 옆 칸 숫자가 늘 사라지던 문제** (HTML 미리보기에서 발견)
- [ ] 숫자 보임/숨김 판정을 `SectionBarLayout`으로 내려 테스트 대상으로 만들기
      (지금은 View 안 private이라 눈으로만 확인 가능 — 위 버그가 그래서 늦게 잡혔다)
- [ ] **실기기에서 눈으로 확인** — 링 아래 자리·원 크기가 커진 만큼 어색하지 않은지
- [ ] `SectionCountdownList` 삭제 여부 결정 (막대로 대체돼 지금은 아무도 안 씀)
- [ ] 발표 모드에도 막대를 넣을지 (지금은 대기/실행 일반 모드만)

## 확인 필요 (실기기/시뮬레이터)
- [ ] Mac 앱 실행 시 창 크기·동작, Live Activity 미동작은 정상(무시)
- [ ] 발표모드에서 버튼/인디케이터 겹침 해소 확인
- [ ] 페이지 인디케이터 점이 하단 바와 겹치지 않는지
- [ ] 빠른설정 길게 눌러 편집 동작 / 페이지 스와이프와 제스처 충돌 여부
- [ ] 예비알림 추가·삭제 후 영구 저장 확인
- [ ] 한국어/일본어 화면 텍스트 자연스러움 최종 점검

## 미정/논의
- [ ] 커밋 분리 방식 (접근성 / 레이아웃 / 프리셋 / 다국어)
