# Rereminder - Claude 개발 워크플로우 문서

## 프로젝트 개요
Rereminder(두번알림)는 iOS, watchOS, 위젯을 지원하는 스마트 타이머 애플리케이션입니다.
사용자가 원하는 시점마다 알림을 받을 수 있으며, 운동, 발표, 스터디 등 시간 관리가 필요한 순간에 활용됩니다.

## 프로젝트 구조

```
Rereminder/
├── Rereminder/                      # 메인 iOS 앱
│   ├── Views/                 # UI 컴포넌트
│   │   ├── Components/        # 재사용 가능한 UI 컴포넌트
│   │   └── *.swift           # 화면별 뷰
│   ├── ViewModels/           # 뷰모델 (MVVM 패턴)
│   ├── Assets.xcassets/      # 앱 리소스
│   └── RereminderApp.swift         # 앱 진입점
│
├── RereminderWatch/      # Apple Watch 앱
│   ├── Views/                # Watch 전용 UI
│   ├── ViewModels/           # Watch 뷰모델
│   └── RereminderWatchApp.swift    # Watch 앱 진입점
│
├── RereminderAlarm/                # 위젯 & Live Activity
│   ├── RereminderAlarm.swift       # 위젯 구현
│   └── RereminderAlarmLiveActivity.swift  # Live Activity 구현
│
├── RereminderClip/           # App Clip (경량 체험판)
│   ├── RereminderClipApp.swift   # 클립 진입점
│   ├── ClipTimerView.swift       # 단일 화면 UI
│   ├── ClipTimerViewModel.swift  # TimerEngine 래핑
│   ├── ClipAlertPlanner.swift    # 알림 3개 자동 배분 로직
│   └── Assets.xcassets/
│
└── Shared/                   # 공유 모듈 (iOS, Watch, Widget)
    ├── Models/               # 데이터 모델
    │   ├── Timer.swift       # 타이머 모델
    │   ├── TimerRecord.swift # 타이머 기록
    │   ├── RereminderTimerData.swift
    │   ├── TimerActivityAttributes.swift
    │   └── AlarmAttributes.swift
    ├── Modules/              # 비즈니스 로직
    │   ├── TimerEngine.swift # 타이머 엔진
    │   ├── RereminderAlarmManager.swift
    │   ├── AppStateManager.swift
    │   ├── WatchConnectivityManager.swift
    │   └── ToastManager.swift
    └── Intents/              # App Intents (Siri, Shortcuts)
        └── TimerIntents.swift
```

## 개발 워크플로우

### 1. 브랜치 전략
- **main**: 프로덕션 릴리즈 브랜치
- **dev**: 개발 통합 브랜치 (기본 작업 브랜치)
- **feature/이슈번호**: 새 기능 개발
- **fix/이슈번호**: 버그 수정
- **refactor/설명**: 리팩토링 작업

**현재 브랜치**: `dev`

### 2. 개발 시작 전
```bash
# dev 브랜치 최신화
git checkout dev
git pull origin dev

# 새 기능 브랜치 생성
git checkout -b feature/이슈번호
```

### 3. 개발 중
- Xcode에서 개발 진행
- 빌드 및 테스트 확인
- 변경사항 커밋 (Commit 가이드 참고)

### 4. PR 생성
- dev 브랜치로 PR 생성
- PR 템플릿 참고하여 설명 작성

## 버전 관리

### 중앙 집중식 버전 관리
모든 타겟(iOS, Watch, Widget)의 버전을 한 곳에서 관리합니다.

**설정 파일**: `Config/Version.xcconfig` (프로젝트 레벨 baseConfiguration — 타겟 하드코딩 금지)

### 버전 업데이트 방법

```bash
# 현재 버전 확인
./scripts/update_version.sh --show

# 새 버전 릴리즈 (예: 1.0.7)
./scripts/update_version.sh 1.0.7

# 빌드 번호만 증가 (TestFlight 업로드 전)
./scripts/update_version.sh --build-only
```

### 버전 규칙
- **MARKETING_VERSION**: 사용자에게 보이는 버전 (예: 1.0.7)
  - X.Y.Z 형식
  - Major.Minor.Patch
- **CURRENT_PROJECT_VERSION**: 빌드 번호 (정수)
  - TestFlight 업로드마다 증가

### 동작 방식 (설정 완료 — 추가 작업 없음)
`Config/Version.xcconfig` 가 프로젝트 레벨 base configuration 이고,
**어떤 타겟도 버전을 자기 빌드 설정에 갖고 있지 않습니다.** 파일 하나 = 전 타겟.

**절대 하지 말 것** (2026-07-27 에 정리한 문제들):
- 타겟 Build Settings 에 `MARKETING_VERSION` 을 넣기 → xcconfig 를 덮어써서 중앙 관리가 무력화됨
- 저장소 루트에 `Version.xcconfig` 를 만들기 → 예전에 루트/`Config/` 두 파일이 공존했고,
  프로젝트는 루트를, 스크립트·문서는 `Config/` 를 봐서 값이 계속 어긋났음

검증: `./scripts/update_version.sh --show` 와 각 타겟의 `-showBuildSettings` 값이 일치해야 함

## 커밋 컨벤션

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Type 종류
- **feat**: 새로운 기능 추가
- **fix**: 버그 수정
- **docs**: 문서만 수정
- **style**: 코드 포맷팅 (기능 변화 없음)
- **refactor**: 코드 구조 개선 (기능 변화 없음)
- **test**: 테스트 코드 추가/수정
- **chore**: 빌드, 설정 등 유지보수

### 커밋 예시
```
feat: 타이머 일시정지 기능 추가

사용자가 진행 중인 타이머를 일시정지하고 재개할 수 있는 기능을 구현했습니다.
- TimerEngine에 pause/resume 메서드 추가
- TimerRunningView에 일시정지 버튼 UI 추가
- Watch 앱 동기화 처리
```

## 코딩 스타일 가이드

### Swift 스타일
- [Apple Developer Academy Swift Style Guide](https://github.com/DeveloperAcademy-POSTECH/swift-style-guide) 준수
- MVVM 아키텍처 패턴 사용
- SwiftUI 기반 UI 구현

### 네이밍 컨벤션
- **View**: `*View.swift` (예: TimerRunningView.swift)
- **ViewModel**: `*ViewModel.swift` (예: TimerViewModel.swift)
- **Model**: 명사형 (예: Timer.swift, TimerRecord.swift)
- **Manager**: `*Manager.swift` (예: AppStateManager.swift)

### 파일 구조
```swift
// 1. Import 문
import SwiftUI
import Combine

// 2. 타입 정의 (struct, class, enum)
struct TimerView: View {
    // 3. Properties
    @StateObject private var viewModel: TimerViewModel

    // 4. Body
    var body: some View {
        // UI 구현
    }

    // 5. Private methods
    private func setupTimer() {
        // 구현
    }
}

// 6. Extensions (필요시)
extension TimerView {
    // 추가 기능
}
```

## 주요 컴포넌트 설명

### Core Components
- **TimerSections** (`Shared/Modules/TimerSections.swift`): 알림 경계로 구간을 나누는 단일 소스.
  링·구간 리스트·발표 시작이 전부 이 계산을 쓴다 (따로 계산하면 보이는 구간과 울리는 구간이 갈라진다)
- **TimeMapper** (`Shared/Modules/AngleCalculator.swift`): 시간↔각도 + 시간 표기(`mmss`,
  한 시간 넘으면 `clockText`)·입력 범위
  (`maxMinutes`/`clampedInput`). 다이얼 범위를 아는 유일한 곳 — 피커가 따로 60분을 적어 뒀다가
  110분을 못 줄이던 버그가 났다
- **TimerEngine** (`Shared/Modules/TimerEngine.swift`): 타이머 로직의 핵심 엔진
- **AppStateManager** (`Shared/Modules/AppStateManager.swift`): 앱 상태 관리
- **WatchConnectivityManager** (`Shared/Modules/WatchConnectivityManager.swift`): iOS-Watch 통신
- **RereminderAlarmManager** (`Shared/Modules/RereminderAlarmManager.swift`): 알림 관리
- **ReviewRequestManager** (`Shared/Modules/ReviewRequestManager.swift`): 앱스토어 리뷰 요청 관리

### 사용 통계·피드백 (서비스 판단 루프)
"이 앱이 실제로 쓸모가 있나"를 개발자가 앱 안에서 확인하는 경로. 설계·운영 문서는
`docs/USAGE_STATS_HUB.md`(수집·집계)와 `docs/FEEDBACK_CLOUDKIT.md`(피드백).
- **UsageMetrics** (`Shared/Modules/UsageMetrics.swift`): 이 기기의 로컬 누적 카운터
  (완주 횟수·관리한 시간 등). `AnalyticsManager.log`가 단독으로 갱신한다.
- **ActivityReporter** (`Rereminder/Modules/ActivityReporter.swift`): 수집 정책(쓰로틀·킬스위치)
  + 허브 조회/기간별 집계. 전송 엔진은 LeeoKit `LeeoUsageReporter`.
- **UsageInsights** (`Rereminder/Modules/UsageInsights.swift`): 퍼널·리텐션·분포 계산(순수 함수,
  유닛 테스트 대상 — `RereminderTests/UsageInsightsTests.swift`).
- **UsageStatsView** (`Rereminder/Views/UsageStatsView.swift`): 마스터 모드 전용 대시보드
  (설정 → Info의 버전 행 7번 탭 → Help에 노출). 피드백 인박스로 이어진다.
- **UsageChartViews** (`Rereminder/Views/Components/UsageChartViews.swift`): 통계 화면의 차트 조각
  (분포·퍼널·비율·나열·리텐션). 규칙 — **한 차트에 축은 하나**(단위가 다른 값은 겹치지 말고 피커로
  갈아 끼운다), 계열이 하나면 색도 하나(테마 강조색), 값은 막대에 직접 적는다. 색으로 계열을
  나누는 건 리텐션(D1·D7·D30)뿐이고 그 3색은 색각 이상 검증을 통과한 고정 조합 + 점 모양까지
  다르게 쓴다 — **임의로 바꾸지 말 것.**
- **주로 쓰는 알림 개수**: `alertsMax`(최대값)만으로는 "한 번 해 봤다"와 "늘 그렇게 쓴다"가
  구분되지 않아, 실행마다 개수를 세는 히스토그램(`UsageMetrics.AlertRun` → `alertRuns.*`)을 함께
  보낸다. 화면은 **실행 기준 / 사람 기준**을 피커로 갈아 끼워 본다(`UsageInsights.alertRunDistribution`).
- **UserSegmentListView** (`Rereminder/Views/UserSegmentListView.swift`): 설치를 결제까지의
  거리로 나눠 한 명씩 보는 명단(익명 ID 앞 8자리). 판정은 하지 않고 `UsageInsights` 결과만 그린다.
- **결제 퍼널은 이벤트가 아니라 스냅샷으로 센다.** 이 앱의 결제는 "알림을 몇 개까지 켜나"로
  갈리므로(무료 1개 → 5+5 체험 → 결제), 통계도 **알림 한도까지 남은 거리**를 잰다:
  `PaymentStage`(pro/blocked/nearLimit/trialing/demand/freeFit/dormant) → 퍼널 6칸 →
  결제 후보 명단. 이벤트는 이름당 6시간 쓰로틀 + 과거형이라 "지금 몇 명"을 못 센다.
  **한도 상수(5+5·무료 1개)는 앱에서 계산해 보내지 말 것** — 원자료(`trial.prealerts`,
  `alertsMax` 등)만 보내고 해석은 `UsageInsights`가 한다. 설계는 `docs/USAGE_STATS_HUB.md`.
- **FeatureTips** (`Rereminder/Modules/FeatureTips.swift`): 기능 발견용 TipKit 팁.
  원칙 — 써 본 뒤에 뜨고(완주·시작 도너), 이미 쓰는 기능이면 안 뜨고(`hasUsed*` 파라미터),
  한 화면에 하나씩. 지금은 발표 모드(완주 2회+), 템플릿 저장(시작 3회+) 둘.
  기기별 활용 안내는 팁이 아니라 온보딩 마지막 장과 설정 > Help 가 담당한다.
- **DeviceOwnership** (`Rereminder/Modules/DeviceOwnership.swift`): "워치·맥 있으세요?"를 타이머가
  막 돌기 시작한 순간에 한 번 묻고(워치 → 하루 뒤 맥), 답을 설정 > **내 기기**에 저장한다.
  원칙 — **없다고 한 기기는 질문도 안내도 다시 꺼내지 않는다.** 있다고 했는데 아직 그 기기에서
  안 써 봤으면 타이머를 걸 때 가끔(5회 간격, 최대 3회) 토스트로 권한다.
  페어링된 워치(`WCSession.isPaired`)·Mac Catalyst 실행은 묻지 않고 `confirmOwned`로 확정한다.
  워치에서 조작이 오면 `markUsed` + `watchSyncUsed` 이벤트(그 전까지 워치 사용 지표가 늘 0이었다).
  ⚠️ 안내 주기를 "시작 횟수 % 5 == 0"으로 만들지 말 것 — 카운터 증가와 판정이 같은 순간에 일어나
  한 칸 어긋나면 그 차례를 통째로 건너뛴다. "지난번 이후 몇 번 더 걸었나"로 잰다
  (테스트: `RereminderTests/DeviceOwnershipTests.swift`).
- **DevicePresence** (`Rereminder/Modules/DevicePresence.swift`): "내 맥에서 지금 이 앱이 켜져
  있나"를 iCloud 키-값 저장소로 확인한다. 앱이 앞에 있는 동안 5분마다 표시(기기 ID·종류·이름·시각)를
  남기고, 다른 기기가 그걸 읽어 10분 안쪽이면 **연결됨**으로 본다.
  **타이머 동기화 스냅샷(`cloudTimerSnapshot`)도 증거로 함께 읽는다** — 동기화는 멀쩡히 되는데
  "연결 안 됨"이라고 말하면 거짓말이다. 그래서 스냅샷에 `sourcePlatform`을 함께 싣는다
  (2.1.0 이하가 남긴 스냅샷은 종류를 알 수 없어 세지 않는다 — 양쪽 다 올라오면 해결된다).
  **맥에서는 앱이 뒤로 가도 표시를 멈추지 않는다**(메뉴 막대로 쓰는 앱이라 창이 뒤에 있어도 사용 중).
  ⚠️ 여기서 "연결됨"은 실시간 연결이 아니라 **최근에 켜져 있었다**는 뜻이다(KVS는 앱을 못 깨운다).
  창은 심장박동 간격의 두 배 — 한 번 놓쳤다고 깜빡이면 안 된다. 기기 ID는 `CloudTimerSyncManager`와
  **같은 값**을 쓴다(따로 만들면 한 기기가 둘로 보인다).
  워치는 이 경로가 아니라 `WatchConnectivityManager.linkStatus`가 답한다 — **페어링 + 워치에 앱 설치**
  까지만 본다(`WatchLinkStatus.resolve`).
  ⚠️ **`isReachable`을 판정에 넣지 말 것.** iOS에서 그 값은 "워치 앱이 지금 화면에 떠 있다"에 가깝고,
  타이머는 `updateApplicationContext`로 워치 앱이 꺼져 있어도 넘어간다 — 도달성으로 판정했더니
  **동기화가 되는 중에도 "연결 안 됨"** 이 떴다(2.1.1에서 고침, `DevicePresenceTests`).
  설정 > **내 기기**에서 "있어요"라고 한 기기에만 상태 심볼이 붙는다.
- **FeedbackNudge** (`Rereminder/Modules/FeedbackNudge.swift`): 앱이 먼저 의견을 묻는 경로
  (10회째 실행 → 이후 40회 간격, "다시 보지 않기"=6개월 유예, 만족도 게이트에 양보).
  통계가 "어디서 떨어지는지"를 말해 준다면 이유는 이 경로로 들어온다.
- ⚠️ 개발자 전용 화면은 `Text(verbatim:)`으로 쓴다. `Text("한글")`·`Picker("", …)`·
  Charts의 `.value("한글", …)` 리터럴은 문자열 카탈로그에 추출돼 다국어 게이트를 막는다.
  동적 키(`guide_*`)·플랫폼 조건부 문자열은 카탈로그에서 `extractionState: manual`로 둘 것
  (그러지 않으면 빌드마다 stale로 찍혀 predeploy가 실패한다).

### Live Activity 버튼 (일시정지·재개·정지)

다이나믹 아일랜드·잠금화면의 세 버튼. **인텐트 파일의 타겟 멤버십이 이 기능의 전부다.**

- ⚠️ **`LiveActivityIntent` 는 위젯 확장이 아니라 앱 프로세스에서 실행된다.**
  Apple: *"the system runs the app intent in the app's process. Make sure to add your custom
  app intent to your app target."* 그래서 인텐트 타입이 확장 타겟에만 있으면 시스템이 앱에서
  그 인텐트를 못 찾아 **버튼을 눌러도 아무 일도 일어나지 않는다** — 2.2.0 까지 재생·정지가
  죽어 있던 이유이고, 코드 주석은 반대로("확장에서 돈다") 적혀 있었다.
- 그래서 세 인텐트는 `Shared/Intents/LiveActivityIntents.swift` 에 있고 **앱·확장 양쪽에서
  컴파일된다**(확장에도 있어야 위젯의 `Button(intent:)` 가 타입을 참조할 수 있다.
  양쪽에 있으면 Apple 은 앱 쪽 것을 실행한다). 확장 멤버십은 pbxproj 의
  `Exceptions for "Shared" folder in "RereminderAlarmExtension" target` 에 적혀 있다 —
  **파일을 옮기거나 이름을 바꾸면 이 목록도 함께 고칠 것.**
- **검증법** (30초): 빌드한 뒤
  `Rereminder.app/Metadata.appintents/extract.actionsdata` 에
  `PauseIntent`·`ResumeIntent`·`StopIntent` 가 있는지 본다. appex 에만 있으면 깨진 것이다.
  ```bash
  grep -o 'PauseIntent' <빌드경로>/Rereminder.app/Metadata.appintents/extract.actionsdata
  ```
- 버튼이 앱에 닿는 길은 두 겹이다(`LiveActivityCommand`):
  ① 앱 그룹에 명령을 남기고 ② `NotificationCenter` 로 알린다.
  앱이 인텐트 때문에 백그라운드로 막 깨어난 참이면 화면(`TimerViewModel`)이 아직 없어서
  ②는 아무도 못 받는다 — 그 경우는 다음에 앱이 앞으로 나올 때
  `applyPendingLiveActivityCommand` 가 ①을 읽어 적용한다.
- **"앱이 받았나"는 기록이 지워졌는지로 판정한다.** 받은 쪽(`TimerViewModel` 의 옵저버)이
  처리했으면 `LiveActivityCommandStore.clear()` 를 부르고, `dispatch()` 는 그걸 보고 `true` 를
  돌려준다. `false` 일 때만 인텐트가 표시를 앞질러 바꾼다
  (`markPaused`/`markResumed`/`endAll`). 이 핸드셰이크가 깨지면 둘 중 하나가 난다 —
  진짜 상태를 어림값이 덮거나, 눌러도 화면이 그대로거나.
  (`NotificationCenter.post` 는 동기라서 `dispatch()` 가 돌아온 시점이면 옵저버는 이미 다 돌았다.)
- 상태에 맞지 않는 명령은 **처리하지 않고 기록도 남겨 둔다** — cold launch 로 타이머를 아직
  복원하기 전일 수 있고, 그때는 복원 뒤에 적용되어야 한다.
- 테스트: `RereminderTests/LiveActivityCommandTests.swift`

### 알림 배지 (종을 옮길 때 뜨는 툴팁)
종 노브를 끌면 그 지점을 **두 가지로** 읽어줍니다. 발표자는 "몇 분 남았나"와
"몇 분째 말하고 있나"를 둘 다 알아야 하기 때문입니다.

```
⚑ 1:00   ← 종료 전 남은 시간 (주황, DSColor.marker)
▶ 4:00   ← 시작 후 경과 (강조색)
```
(5분 발표에서 종료 1분 전에 종을 두면 위와 같이 나옵니다)

- **배지 두 줄의 색은 링에서 그 종의 양옆 구간 색을 그대로 씁니다**(`sectionColors(around:)`).
  링은 이미 알림 경계로 구간마다 색이 나뉘어 있어서, 종을 잡았다고 다른 색 체계(주황/강조색)로
  갈아타면 "지금 만지는 구간이 어디였더라"를 다시 찾게 됩니다. 배지 줄 색과 링 구간 색이 같아야
  어느 숫자가 어디인지 읽히므로, **한쪽만 바꾸지 마세요.**
- 드래그 중에는 링 경계도 손끝을 따라옵니다(`liveOffsets` — 저장은 손을 뗄 때 이뤄지므로,
  저장된 값만 보면 색 경계가 따라오지 않습니다).
- 종이 여러 개일 때 잡고 있는(또는 방금 놓은) 종만 100%, 나머지는 25%로 물러납니다.
  **종 노브(`alertKnobs`)와 작대기 마커(`ClockMarkers.dimmedIndices`) 둘 다** 흐려져야 합니다.
  하나만 흐려지면 따로 노는 것처럼 보입니다.
- 배지·링 강조·흐리기가 모두 `highlightedMarker`(클립은 `highlightedAlert`) 하나를 따라갑니다.
  드래그 중이면 손가락 위치, 놓은 뒤 **3초**(`tooltipLingerSeconds`) 동안은 확정된 위치입니다.
- 3초가 지나면 배지·링 강조·흐려진 종이 **한꺼번에 0.35초 디졸브**로 원래대로 돌아옵니다
  (`dissolveDuration`). 들어올 땐 0.2초로 빠르게, 나갈 땐 천천히 — `highlightAnimation` 이
  방향에 따라 두 값을 골라 씁니다. 사라지는 뷰에는 `.transition(.opacity)` 가 붙어 있어야
  뚝 끊기지 않습니다.
- 구현: `TimerMainView.markerDragTooltip` / `alertSplitArc`,
  `ClipClock.alertDragTooltip` / `alertSplitArc` — **두 곳을 함께 고쳐야 합니다.**
- **가운데 시간·버튼은 링 안쪽에 가둡니다**(`centerContentDiameter`). 두 줄일 때는 안쪽 줄
  안쪽이 한계라, 바깥 원 기준으로 글자 크기를 잡으면 "110:00" 이 링을 덮습니다. 시간 묶음이
  ZStack 의 마지막 자식이라 그 위에 그려지고, 그러면 **링 위의 종·핸들 터치까지 글자가 가로챕니다.**
- 배지가 3시·9시 방향에서 화면 밖으로 나가지 않도록 메인 앱은 x 오프셋을 화면 폭으로 자릅니다
  (`markerBadgeHalfWidth`). 배지 글꼴·여백을 키우면 이 어림값도 같이 올리세요.
- **배지는 언제나 최상단이어야 합니다.** 3시·9시 방향 종은 배지가 가운데 시간 글자와 같은
  높이에 오고, 안쪽으로 잘린 x 오프셋 때문에 실제로 겹칩니다. 두 겹으로 보장합니다:
  - `clockView` ZStack 안: 두 툴팁에 `.zIndex(2)` — 시간+버튼 묶음이 마지막 자식이라
    zIndex 없이는 배지를 덮습니다.
  - 바깥 `VStack`: `clockView` 에 `.zIndex(1)` — 배지가 원 밖으로 나가 아래쪽 템플릿 바·
    구간 리스트에 덮이지 않게.
  - 클립은 `ClipTimerView.clock(size:)` 에서 **가운데 시간을 `ClipClock` 보다 먼저** 둡니다.
    순서를 되돌리면 같은 문제가 재발합니다.

### 링 구간 색 (진행 중에도 유지)
알림으로 나뉜 링은 **타이머가 도는 동안에도 구간 색을 그대로 쓴다**(`showsAlertSectionColors`는
오버타임에서만 꺼진다). 시작하자마자 단색으로 바뀌면 "지금 몇 번째 구간인가"가 사라지는데,
발표 중에 가장 알고 싶은 게 그거다. 남은 호만 줄어들고 색 경계는 제자리에 있어서, 경계를 지날
때마다 색이 하나씩 없어진다.

- 구간 번호 역매핑은 **`TimerSections.ringSectionIndex`** 하나를 쓴다. 링은 "남은 시간" 좌표라
  경과 순서와 반대이고, **진행 중에는 지나간 경계가 호에서 빠져 조각 수가 줄어든다** —
  자리 번호(조각 수 − 1 − i)로 세면 그 순간 남은 구간의 색이 통째로 밀린다.
  "이 조각 끝보다 뒤에 있는 알림이 몇 개인가"로 세면 언제나 맞는다(테스트: `TimerSectionsTests`).
- 구간 **번호(1·2·3)** 는 대기 중에만 붙인다 — 진행 중에는 구간이 하나씩 사라지며 번호만 바뀌어
  어지럽다.

### 타이머 모양 (설정에서 고른다 · 한 번에 하나)
실행 중 화면의 모양은 **설정 > 타이머 모양**에서 고른다 — 원형 링 / 줄 + 링 / 구간 막대 /
접은 줄(ㄹ자). 정의는 `Shared/Modules/TimerShape.swift` 한 곳, 저장은 `@AppStorage("timer.shape")`.

- **한 번에 하나만 그린다.** 예전엔 원과 구간 막대를 같이 세웠는데, 같은 시간을 두 번 그리는
  셈이라 눈이 매번 어느 쪽을 볼지 골라야 했다. 그래서 원 아래 `SectionProgressBar` 자리는
  없어지고, 막대는 **모양 중 하나**가 됐다.
- **대기 중에는 언제나 다이얼(원)이다.** 흰 핸들·종 노브를 끌어 시간과 알림을 정하는 조작이
  원에 묶여 있어서, 모양 선택은 **실행 중 표시**에만 적용한다(`usesLinearShape`).
- 고르는 화면은 이름이 아니라 **실루엣**을 보여준다(`TimerShapeSilhouette`) — "줄 + 링"이라는
  말로는 무엇을 고르는 건지 알 수 없다. 실루엣은 **실제 화면과 같은 컴포넌트**로 그린다
  (`SectionInnerRing`·`SectionProgressBar`·`SnakeTimerView`). 미리보기만 따로 그리면
  고르고 나서 "이게 아닌데"가 된다. 네 그림은 **같은 예시 타이머의 같은 순간**을 그린다.
- 가운데 큰 숫자는 원형 링에서만 전체 남은 시간이고, 나머지 셋은 **이 구간**의 남은 시간 +
  아래 작은 `Total:` 줄이다(`centerSection`).
- **접은 줄**(`SnakeTimerView`)은 경로 길이가 곧 시간이라 구간을 길이 비율로 자른다.
  U턴에 얹힌 짧은 구간은 곡선으로 말려 실제보다 짧아 보이므로 줄 수를 늘리지 말 것(4줄).
- **알림 지점에는 어디서나 종이 선다.** 링은 종 노브, 막대·접은 줄은 구간 사이에 주황 종.
  구간 경계를 틈으로만 표시하면 "줄이 왜 끊겼지"로 읽힌다 — 왜 끊겼는지는 종이 말해 준다.
  막대의 칸 사이 여백(`gap`)은 종이 앉을 자리라 막대 두께를 따라 같이 벌어진다.
- **버튼(시작·정지)은 원 밖에 있다** (`TimerActionBar`). 원 안에 두면 가운데를 반 넘게 먹어서
  시간 두 줄이 들어갈 자리가 없고, 링 위의 종·핸들 터치까지 버튼이 가져간다.
  - 주 동작은 **채운 캡슐 하나**(아이콘 + 글자) — ▶ 하나만 있으면 "시작"인지 "재개"인지 유추해야
    한다. 정지는 곁들이라 회색 원, 대기 중에는 아예 없다.
  - 색은 **테마 강조색**. 예전 시작 버튼은 분홍 고정(`DSColor.positive`)이라 파란 링 아래에서
    혼자 튀었다. **주황은 쓰지 않는다** — 이 화면에서 주황은 알림 종의 색이다.
  - **움직임은 하나의 스프링으로 묶는다.** 정지 버튼이 들어오는 것·캡슐이 밀리는 것·글자가
    바뀌는 것이 각자 다른 속도로 움직이면 그게 허접해 보이는 이유다.
    심볼은 `.contentTransition(.symbolEffect(.replace))`, 글자는 `.contentTransition(.opacity)`,
    정지 버튼은 옆에서 밀려들지 않고 제자리에서 커지며 나타난다.
  - **일시정지 ↔ 재개에서 캡슐 폭이 변하면 안 된다.** 도는 동안 나올 수 있는 글자를 전부
    ZStack 에 겹쳐 두고(보이지 않게) 그중 가장 넓은 것으로 폭을 잡는다.
    ⚠️ `.background` 에 유령 글자를 깔면 폭이 안 잡힌다(배경은 부모 크기를 따를 뿐).
    ⚠️ 글자 수로 긴 쪽을 고르지 말 것 — 언어마다 폭이 다르다.
- **"줄 + 링"에서는 60분을 넘겨도 링이 두 줄이 되지 않는다** — 링 한 바퀴가 "이 구간"이라
  바퀴를 셀 이유가 없다(`usesAbsoluteRing` 예외). 전체 길이는 위의 줄이 갖는다.
- 가운데는 모양에 따라 다르다: 원형 링은 전체만, **줄 + 링은 이 구간만**(전체는 위의 줄),
  막대·접은 줄은 전체가 크고 그 아래 이 구간. 예전의 "Next 알림" 안내 박스는 없앴다 —
  같은 이야기를 원 밖에서 한 번 더 하던 자리였다.

### 줄 + 링 (위=전체, 링=이 구간) — 옛 "이중 링"을 대체
진행 중에 원 **위**로 얇은 일자 줄이 서고, 원(링)은 **지금 지나는 구간 하나만** 센다.

왜 바꿨나 — 2.2.0 까지는 원 안에 링을 한 겹 더 두른 **이중 링**이었다(바깥=전체, 안쪽=구간).
같은 모양이 둘이면 볼 때마다 "어느 쪽이 무엇이더라"를 먼저 골라야 한다. 1초 안에 답을 얻어야
하는 화면에서 그 한 번의 선택이 비싸다. 그래서 **질문 둘을 형태 둘로 갈랐다** —
길이(줄)는 *전체가 어디쯤인가*, 각도(링)는 *이 구간이 얼마 남았나*. 형태가 다르면 고르지
않아도 눈이 알아서 나눈다.

- 정의는 `TimerShape.lineAndRing`. ⚠️ **원시값은 `dualRing` 그대로** — 바꾸면 이미 이걸 고른
  사람의 설정이 기본값으로 되돌아간다. 판정은 `TimerShape.ringShowsSection` 하나.
- 위의 줄은 **`TotalTimelineStrip`**(`Views/Components/`). 그림은 구간 막대
  (`SectionProgressBar`)를 **그대로** 쓰고 `showsLabels: false` 로 칸 숫자만 끈다 —
  칸 색·종·재생헤드가 두 모양에서 같아야 설정에서 모양을 바꿔도 다시 배우지 않는다.
  숫자는 줄 오른쪽 끝의 전체 남은 시간 하나뿐이다(칸마다 또 붙이면 한 화면에 시간이 다섯 개다).
- 링이 구간을 세는 동안 **링 위에서 사라지는 것 넷**: 알림 종 노브(좌표가 전체 시간 기준이라
  구간 한 바퀴에 얹으면 엉뚱한 각도에 선다 — 그 종들은 위의 줄이 갖고 있다), 구간 색 분할
  (`showsAlertSectionColors`), 두 줄 링(구간은 언제나 전체보다 짧다), 절대 각도
  (`usesAbsoluteRing` — 한 바퀴가 "이 구간"이지 60분이 아니다). 판정은 전부
  `TimerMainView.ringSectionProgress != nil` 하나를 본다.
- 링 색은 `SectionPalette` 의 그 구간 색 — 위 줄에서 지금 지나는 칸과 **같은 색**이어야 이어진다.
- 가운데 큰 숫자는 **이 구간**의 남은 시간(구간 색 점 + 시간, `sectionTimeRow`).
  전체는 위의 줄에 이미 있으므로 가운데에 또 적지 않는다.
  막대·접은 줄은 그대로 전체가 크고 구간이 그 아래 작은 줄이다.
- 구간이 하나뿐이면(`sectionProgress` 가 nil) 이 모양은 **원형 링과 같아진다** — 나눌 것이
  없는데 줄과 링을 둘 다 세우면 같은 말을 두 번 하게 된다.
- 원은 줄의 높이만큼 작아진다(`stripReserve`) — 그러지 않으면 작은 화면에서 줄이 동작 버튼을 민다.
- ⚠️ **워치는 아직 이중 링이다**(`RereminderWatch/Views/TimerView.swift` + `SectionInnerRing`).
  워치에는 모양 설정이 없고 화면이 좁아 줄을 세울 자리가 없다. `SectionInnerRing` 은 그래서
  남아 있다 — iPhone 에서 안 쓴다고 지우지 말 것.

### 온보딩 — 읽는 안내가 아니라 해 보는 안내
`OnboardingFlowView` (2.1.2에서 갈아엎음). 흐름은 **환영 → 어디에 쓸 건가요 → 60배속 체험 →
템플릿 저장 → 기기 안내** 다섯 장.

- **상황을 먼저 고르게 한다**(`OnboardingUseCase`: 발표·운동·집중·요리·회의·아직 모르겠어요).
  "끝나기 전에 여러 번 알려 준다"가 왜 좋은지는 자기 상황에 대입해야 안다. 고른 상황의
  추천 설정은 **알림이 두 개 이상**이 되게 잡는다 — 하나짜리는 체험에서 보여 줄 것이 없다.
- **체험은 진짜 타이머가 아니다**(`OnboardingDemoTimer`). `TimerEngine`·알림·Live Activity를
  건드리지 않아서 껐다 켜도 흔적이 없다. 종이 울릴 때 배너가 뜨고 햅틱이 온다.
  - **길이와 상관없이 체험은 늘 10초다**(`demoSeconds`). 배속을 60으로 고정했더니 30분짜리
    회의 상황이 30초를 잡아먹었다 — 온보딩에서 30초는 아무도 안 기다린다.
    배속은 길이를 따라 계산한다(10분 → 60배, 30분 → 180배). 테스트: `OnboardingDemoTests`.
  - ⚠️ 장난감 타이머는 **서브뷰의 `@StateObject`** 로 들고 있어야 한다. 부모의 `@State` 에 담으면
    참조만 갖고 `@Published` 를 구독하지 않아 **화면이 10:00 에서 멈춘 채로** 보인다(실제로 그랬다).
- **온보딩이 끝나면 고른 설정이 이미 다이얼에 올라가 있다.** 그래서 온보딩은 `screenVM` 이 있는
  `TimerUnifiedView` 에서 띄운다(예전엔 `ContentView` 라 손이 닿지 않았다). 템플릿 저장도
  같은 이유로 여기서 된다(`saveCurrentAsTemplate`).
- 옛 일곱 장짜리 안내는 지웠다. 마지막 "기기 안내" 한 장만 `OnboardingPageView` 로 남아 있고,
  쓰이지 않게 된 문구(`onboarding_*_1`~`6`)는 카탈로그에서 제거했다.

### 알림 문구는 알림을 켜는 자리에서 쓴다
"울릴 때 뭐라고 할까요"는 **알림 시트(`PrealertSettingsView`)** 안에, 켜 둔 알림 목록 바로 아래
있다. 설정 > Messages(`NotificationMessageSettingView`)에도 같은 값이 있지만, 거기까지 찾아가는
사람은 없다 — **문구가 필요하다고 느끼는 순간은 알림을 켤 때다.**

- 두 화면은 같은 값(`prealertMessages` / `finishMessage`)을 본다. 한쪽만 고치지 말 것.
- 빈칸의 placeholder 는 **실제로 나갈 기본 문구**여야 한다(`Timer.getPrealertMessage` 와 같은 말).
- ⚠️ 발표 모드로 시작하면 구간 이름으로 문구가 자동 생성돼(`"도입 complete"`) **사용자가 쓴
  문구를 덮어쓴다**(`applyPresentationSections`). 설정 화면에 그 사실을 적어 두었다.

### 발표 구간 대본 (구간마다 말할 것)
구간에 **대본·메모**를 적어 두면 발표 중 그 구간 차례에 원 아래에 펴진다.

- 저장은 이름과 같은 방식 — `TimerScreenViewModel.sectionScripts[구간 번호]`.
  구간은 알림 경계에서 파생되므로 **글도 번호를 따라간다**(알림을 옮겨 구간이 줄면 그 번호의
  글은 화면에서 사라진다. 지워지지는 않는다).
- 시작할 때 `syncSectionsFromAlerts()` 가 `PresentationSection.script` 로 실어 보내고,
  템플릿으로 저장하면 `sectionsData` 에 함께 들어간다. **`script` 에 기본값이 있어야**
  대본이 없던 시절 템플릿도 그대로 열린다.
- 적는 곳: 구간 카드의 대본 줄 → `SectionScriptSheet`(시트). 카드 안에 여러 줄 입력을 넣으면
  목록이 키보드마다 출렁인다.
- 보는 곳: `PresentationScriptPanel` — **발표가 도는 동안** 구간 목록 대신 선다(목록은 고칠 때
  필요한 것이고, 도는 동안에는 읽을 것만 남는다). 대본이 비어 있으면 목록이 그대로 선다.
- ⚠️ 발표 화면은 **`TimerMainView` 하나뿐**이다(앱은 `TimerUnifiedView` → `TimerMainView` 로 돈다).
  예전에 있던 `PresentationDisplayView`·`PresentationSetupView`·`PresentationContainerView` 는
  어디에서도 열리지 않는 죽은 화면이라 2.2.0 에서 지웠다 — 발표 화면을 새로 만들지 말고 여기를 고칠 것.

### 다이얼 드래그 (튐 방지)
흰 핸들·종 노브 모두 **손가락 각도만 이어 붙이고, 자르는 건 화면에 그릴 때 한 번만** 합니다.

- `TimeMapper.ringAngle(at:center:)` — 고정 좌표계 좌표 → 링 각도(12시 = 0°, 시계 방향)
- `TimeMapper.unwrappedAngle(_:continuing:)` — 359° → 1° 를 +2° 로 이어 붙임 (두 바퀴째까지)
- 잡은 순간 `value.startLocation` 으로 **손가락과 노브의 각도 차(grab delta)** 를 기억합니다.
  이게 없으면 노브를 집는 순간 손끝으로 순간이동합니다(히트 영역이 지름 2.8 × 선 두께라 최대 13° ≈ 130초).
- 각도는 회전에 휘둘리지 않게 **이름 붙인 고정 좌표계**에서 읽습니다
  (`rereminder.dial` / `rereminder.alerts` / 클립 `clip.dial`).
  좌표계를 얹은 뷰에 `.frame(width: size, height: size)` 가 있어야 중심이 `size/2` 로 확정됩니다.
  클립은 히트 여백까지 포함한 프레임이라 중심이 `size/2 + hitMargin` 입니다(`dialCenter`).
- **`TimeMapper.angleDelta` 를 다시 쓰지 마세요.** "지금 표시 중인(=잘린) 각도"를 기준 삼기 때문에,
  손가락이 허용 범위를 크게 벗어나면 최단 방향이 뒤집혀 반대편으로 순간이동합니다.
  (종을 총 시간 너머로 계속 끌면 0 으로 / 흰 핸들을 0 아래로 끌면 30분으로 튀던 문제)
- 드래그 중에는 `withAnimation` 을 걸지 않습니다. 손가락보다 늦게 따라와 미끄러지는 느낌이 납니다.
  10초 단위 스냅은 손을 뗄 때(`onEnded` / `angleToSeconds`)만 합니다.
- **손을 뗄 때도 애니메이션을 걸지 않습니다** (`Transaction.disablesAnimations`).
  종 목록의 `ForEach` id 가 **알림 초**라서, 옮긴 값을 지웠다 다시 넣는 순간 SwiftUI 는
  "다른 종이 사라지고 새 종이 나타났다"고 보고 `.transition(.scale + .opacity)` 를 재생합니다 —
  종이 펑 튀어 보이던 정체입니다. 링 밖으로 끌어 **지우는** 경우만 그대로 페이드아웃시킵니다.
- 종 크기도 `isDraggingThis` 가 아니라 **`isFocused`**(배지가 남아 있는 동안) 를 따릅니다.
  손 떼는 순간 2.0 → 1.6 으로 줄면 그것도 튀어 보입니다. 배지가 녹을 때 같이 작아집니다.
- 메인 앱(`TimerMainView.alertKnobs`)과 App Clip(`ClipClock.alertKnobs`) **둘 다 같은 규칙**입니다.

### 기본 타이머 설정 (초기화의 기준점)
`TimerScreenViewModel.DefaultSetup` — **10분 + 종료 1분 전 알림 하나**.
앱을 갓 설치했을 때 보이는 설정이고, 다음 세 가지가 전부 이 상수 하나를 따라갑니다:

1. `@Published` 초기값 (`mainMinutes`·`selectedOffsets`·`configuredMainSeconds`)
2. `isAtDefaultSetup` — "사용자가 아직 아무것도 안 바꿨다" 판정
3. `resetToDefaultSetup()` — 다이얼 아래 **초기화** 버튼

**기본값을 바꿀 땐 `DefaultSetup` 만 고치세요.** 값을 다른 곳에 다시 적으면 세 곳이 어긋나
"바꾼 적 없는데 저장 버튼이 떠 있는" 상태가 됩니다. `DefaultSetupResetTests` 가 이걸 지킵니다.

`TemplateQuickBar` 의 두 버튼은 **사용자가 뭔가 바꿨을 때만** 나옵니다
(왼쪽 초기화 = `!isAtDefaultSetup`, 오른쪽 템플릿 저장 = 그 위에 "기존 템플릿과도 다를 때").
갓 설치한 상태면 바에는 템플릿 칩만 남습니다.
두 버튼에는 `.layoutPriority(1)` 이 있어야 템플릿 칩 스크롤뷰에 밀려 글자가 잘리지 않습니다.
초기화는 `persistLastUsedConfig` 로 "마지막 사용 설정"까지 기본값으로 덮으므로 재실행해도 유지됩니다.

### UI Components
- **SectionProgressBar** (`Rereminder/Views/Components/SectionProgressBar.swift`): 실행 중
  원 아래 **완전 선형 구간 막대**. 링이 각도로 "전체가 얼마나 남았나"를 말한다면, 이건 길이로
  "이 구간이 전체에서 얼마나 큰 덩어리인가"를 말한다 — 크기를 읽는 채널은 *공통 축 위의 위치 >
  길이 > 각도* 순서라, 서로 다른 각도 위치에 놓인 호 두 개의 비교(5분 구간 vs 25분 구간)는
  원이 잘 못 하는 일이다. 왼쪽 끝·오른쪽 끝이라는 기준점이 생기는 것도 원에 없던 것(원은 12시뿐).
  **읽는 법은 링과 같다**: 오른쪽의 진한 부분이 남은 시간, 왼쪽 옅은 부분이 지나간 시간,
  경계의 흰 표시가 지금(링에서 줄어드는 호 끝의 흰 점과 같은 역할).
  색은 `SectionPalette`, 남은 시간은 `TimerSections.remainingSeconds` 하나만 본다.
  알림이 하나뿐이면(구간 1개) 대신 `nextAlertInfo`가 선다.
  - 숫자 규칙 세 가지 — **지나간 구간은 숫자를 지우고**(`0:00` 이 여럿 늘어서면 지금 숫자를 다시
    찾아야 한다), **지금 구간의 숫자는 칸을 넘겨서라도 그린다**(마지막 1분처럼 칸이 좁아지는 때가
    하필 그 숫자가 가장 급한 때다), 아직 오지 않은 구간은 제 칸에 들어가고 지금 숫자와 겹치지
    않을 때만 붙인다.
- **SectionBarLayout** (`Rereminder/Views/Components/SectionBarLayout.swift`): 그 막대의 자리 계산
  (순수 함수, `SectionBarLayoutTests`). 시간에 비례한 폭이 기본이지만 **`minWidth`(6pt)보다
  좁아지는 칸은 최소 폭으로 올린다** — 60분 중 30초 구간은 비례대로면 2.5pt 라 사라지고,
  사라진 구간은 "없는 구간"으로 읽힌다. 그만큼 다른 칸이 줄어들므로 **좁은 칸이 섞이면 길이가
  시간에 정확히 비례하지 않는다**(알고 쓰는 거짓말).
  ⚠️ **재생헤드는 비례 좌표가 아니라 실제로 그려진 칸 폭을 따라간다.** 최소 폭으로 넓힌 칸이
  있는데 비례로 계산하면 알림이 울리는 순간 재생헤드가 경계에 있지 않고, 그러면 이 막대는
  못 믿을 물건이 된다.
- ~~SectionCountdownList~~ — 위 막대로 대체됐다(파일은 남아 있으나 쓰이지 않음). 같은 정보를
  세로 목록의 **숫자**로만 줘서 5분과 25분의 차이를 눈이 아니라 머리로 계산해야 했다.
- **DeviceLinkChips** (`Rereminder/Views/Components/DeviceLinkChips.swift`): 원 아래 기기 연결
  상태 칩. **"있어요"라고 답한 기기만**, 그리고 **안 될 때만 글자**를 붙인다(연결됨은 초록 심볼만).
  **대기 중에도 보인다** — 연결은 타이머를 걸기 *전에* 고쳐야 의미가 있다. 발표 모드에서만 뺀다
  (구간 리스트가 화면 절반을 쓰는 자리라 한 줄이 아쉽다).
  누르면 `DeviceConnectionHelpView` 로 들어간다.
- **DeviceConnectionHelpView** (`Rereminder/Views/DeviceConnectionHelpView.swift`): "그래서
  어쩌라고"에 답하는 화면 — 지금 상태 + 순서대로 할 일 + 그 자리에서 다시 확인.
  칩과 설정 > 내 기기의 상태 줄이 **같은 화면**으로 들어온다. 맥 안내에는 "연결됨 = 최근 10분 안에
  켜져 있었다"는 뜻을 반드시 적어 둔다(안 그러면 "켜 뒀는데 왜 안 뜨지"가 된다).
- ~~Clock / ClockMarkers / TimerRunningView~~ — **2.1.1에서 삭제**. 메인 화면은 자체 렌더링을
  쓰고 있었고(`TimerMainView`), 종 노브가 이미 알림 지점을 표시한다. 그 아래 깔려 있던 주황
  작대기(`ClockMarkers`의 `Rectangle`)는 종이 흐려질 때(울린 뒤 0.35) 혼자 진하게 남아
  "종 밑에 직사각형이 깔린" 것처럼 보였다. 되살리지 말 것 — App Clip(`ClipClock`)도 작대기가 없다.
- **PresentationSectionList** (`Rereminder/Views/Presentation/PresentationSectionList.swift`):
  발표 모드 구간 카드 목록(이름 편집). 구간 계산은 하지 않고 받은 것만 그린다
- **SectionPalette** (`Shared/DesignSystem/SectionPalette.swift`): 구간 색 규칙 —
  링의 호·리스트 점·진행 중 표시가 **같은 구간이면 같은 색**이어야 해서 한 곳에 둔다.
  iPhone·워치가 같은 색을 써야 해서 Shared 에 있다(예전엔 `Rereminder/Views/Components/`)
- **TimerDialRings** (`Rereminder/Views/Components/TimerDialRings.swift`): 다이얼의 링들
  (바탕·남은 시간·구간 색·구간 번호). 화면이 `Plan` 을 만들어 넘기면 그것만 그린다 —
  링이 이상할 때 **값이 틀렸는지(TimerMainView.ringPlan) 그림이 틀렸는지(여기)** 를 갈라 본다.
  `SectionOuterRing` (발표 모드 바깥 얇은 링)도 같은 파일
- **MarkerDragBadge** (`Rereminder/Views/Components/MarkerDragBadge.swift`): 종을 끌 때 뜨는
  두 줄 배지. 색은 부르는 쪽이 링 구간 색으로 정해 넘긴다 (위 "알림 배지" 규칙)
- **SnakeTimerView** (`Rereminder/Views/Components/SnakeTimerView.swift`): ㄹ자로 접은 줄.
  선의 길이 비교를 지키면서 가로 폭을 접는다 — 긴 타이머용 (위 "타이머 모양" 참고)
- **TimerShapeSilhouette** (`Rereminder/Views/Components/TimerShapeSilhouette.swift`): 설정에서
  모양을 고를 때 보여주는 실루엣. 예시 타이머 값은 이 파일 한 곳에만 둔다
- **SectionInnerRing** (`Shared/DesignSystem/SectionInnerRing.swift`): **워치 전용이 됐다** —
  iPhone 은 "줄 + 링"으로 갈아탔지만 워치에는 모양 설정이 없고 줄을 세울 자리도 없다. 지우지 말 것
- **TotalTimelineStrip** (`Rereminder/Views/Components/TotalTimelineStrip.swift`): "줄 + 링"에서
  원 위에 서는 전체 타이머 줄 (위 "줄 + 링" 참고)
- **TimePresetButtons** (`Rereminder/Views/Components/TimePresetButtons.swift`): 시간 프리셋 버튼
- **ToastViewModifier** (`Rereminder/Views/Components/ToastViewModifier.swift`): 토스트 메시지

### App Clip (RereminderClip)
앱의 핵심 가치인 **"끝나기 전 여러 번 알림"**만 남긴 경량 체험판입니다.

- **번들 ID**: `com.xa.toki.Clip` (부모 앱 `com.xa.toki`에 임베드)
- **조작**: 메인 앱과 같은 다이얼 UX입니다. 흰 핸들을 끌어 총 시간을,
  주황 종 노브를 끌어 알림 지점을 정합니다. 시간 프리셋(10·30·60분) 버튼도 있습니다.
- **ClipAlertPlanner**: 총 시간만 받아 알림 지점을 자동 배분합니다(사용자가 종을 옮기기 전 기본값).
  총 시간의 1/3·1/6·1/30 지점을 계산한 뒤 사람이 말하는 단위(10분·5분·1분 등)로 스냅합니다.
  (예: 30분 → 10분·5분·1분 전)
  - 목표에서 2배 넘게 벗어나면 그 알림은 만들지 않습니다.
  - **알림 사이 최소 간격 150초**를 강제합니다. 링이 절대 각도(1° = 10초)라 150초 = 15°인데,
    그보다 가까우면 종 노브가 겹쳐서 집을 수가 없습니다.
    간격을 못 만들면 3개보다 적게 만듭니다 (10분 타이머 → 3분 전·20초 전 2개).
  - 사용자가 종을 한 번이라도 옮기면(`hasCustomizedAlerts`) 시간이 바뀌어도 다시 배분하지 않고,
    총 시간 밖으로 나간 지점만 버립니다.
- **코드 재사용**: `TimerEngine`, `ThemeManager`, 디자인 시스템(DS*), `RingSound`, `AppName`,
  `ring.swift`, `Localizable.xcstrings`를 메인 앱과 공유합니다.
  Xcode 동기화 그룹(`PBXFileSystemSynchronizedBuildFileExceptionSet`)으로 멤버십만 추가하는 방식이라
  파일이 복제되지 않습니다.
- **`ClipClock`**: 시계는 공유하지 않고 클립 전용으로 다시 그렸습니다.
  메인 화면(`TimerMainView.clockView`)은 공유 `Clock.swift`가 아니라 자체 렌더링을 쓰기 때문에,
  `Clock`을 재사용하면 오히려 앱과 달라 보입니다(선 두께 고정 8pt vs 지름의 8.3%, 노브 없음 등).
  `ClipClock`은 메인과 같은 규칙으로 맞췄습니다:
  - 대기 중에는 **절대 각도**(`TimeMapper`, 1° = 10초, 2바퀴까지 / 2바퀴째는 연두)
  - 실행 중에는 남은 비율 + 줄어드는 호 끝의 흰 점
  - 지름의 8.3% 선 두께, `plain` 50% 트랙, 주황 종 노브, 드래그 툴팁
  - 알림 배지도 메인과 같이 두 줄입니다 (아래 "알림 배지" 참고).
- **한 화면 레이아웃 (스크롤 없음)** — 클립은 진입 후 바로 조작할 수 있어야 하므로
  절대 스크롤되지 않아야 하고, **원 크기가 이 화면의 최우선**입니다.
  - `ClipTimerView` 의 세로 스택에서 헤더·칩·프리셋·버튼·안내가 먼저 제 높이를 가져가고,
    **남는 자리를 `clockArea`(GeometryReader)가 전부 받습니다.** 원 크기를 화면 높이의
    고정 비율(예전 0.38)로 잡으면 요소가 하나만 늘어도 넘치므로, 비율로 되돌리지 마세요.
  - `clockSide = min(폭 × 0.88, 높이 − badgeMargin × 2)`
    - `0.88` 은 종 노브가 링 밖으로 나가는 몫(반지름 + 노브 = 지름 × 0.5664)입니다.
      이걸 빼지 않으면 3시·9시 종이 화면 가장자리에서 잘립니다.
    - `badgeMargin`(48pt)은 두 줄 알림 배지가 원 위·아래로 삐져나오는 몫입니다.
  - `clockArea` 만 `.padding(.horizontal, -DSSpacing.xl)` 로 화면 좌우 여백을 되찾아 씁니다.
    배지가 이웃 위로 겹쳐 그려져야 해서 `.zIndex(1)` 도 함께 붙어 있습니다.
  **메인 시계 디자인을 바꾸면 여기도 함께 손봐야 합니다.**
- **테마**: 클립에도 `.tint(themeManager.accentColor)` + `.preferredColorScheme`를 적용합니다.
  이게 없으면 에셋의 `AccentColor`(분홍)가 나와 앱(기본 Ocean 블루 + 다크)과 완전히 달라 보입니다.
- **`APPCLIP` 컴파일 조건**: 클립에는 App Group·위젯·인앱결제가 없으므로,
  `TimerEngine`의 공유 상태 저장 / `WidgetCenter` 갱신 / `AnalyticsManager`(ProGate 의존) 호출을
  `#if !APPCLIP`으로 제외합니다. **Shared 코드를 고칠 때 이 가드를 깨지 않도록 주의하세요.**
- **알림 권한**: `Info.plist`의 `NSAppClipRequestEphemeralUserNotification`으로
  클립 세션(8시간) 동안 알림을 보낼 수 있습니다.
- **호출 URL**: `?minutes=N` (1~120) 쿼리로 시작 시간을 지정할 수 있습니다.
- **고급 App Clip 경험 / 도메인 연결** — GitHub Pages (`M1zz/m1zz.github.io` 저장소):
  - 초대 URL: `https://m1zz.github.io/rereminder/`
  - 클립 엔타이틀먼트: `com.apple.developer.associated-domains` = `appclips:m1zz.github.io`
  - AASA: `m1zz.github.io/.well-known/apple-app-site-association` 의 `appclips.apps` 에
    `QGAQ3AY3R3.com.xa.toki.Clip` 포함.
    ⚠️ **FindMe 클립과 같은 파일을 공유합니다. 고칠 때 기존 항목을 지우지 마세요.**
  - 저장소 루트에 `.nojekyll` 이 있어야 `.well-known` 폴더가 서빙됩니다.
  - GitHub Pages 는 이 파일을 `application/octet-stream` 으로 주지만 **Apple 은 문제없이 파싱합니다.**
    (문서에는 `application/json` 이 요구사항이라 적혀 있으나 실제로는 통과 — FindMe 로 검증됨)
  - 검증: `curl https://app-site-association.cdn-apple.com/a/v1/m1zz.github.io`
    (Apple CDN 캐시라 푸시 직후에는 옛 내용이 나올 수 있음)
  - 랜딩 페이지 원본은 `web/index.html`. 고치면 블로그 저장소로 복사해 푸시.
  - **앱 소개 페이지(`docs/index.html` → `m1zz.github.io/Rereminder/`, 대문자 R)에서
    이 초대 URL(소문자 r)로 가는 링크가 내비·히어로 보조 CTA·푸터 세 군데 있습니다.**
    두 페이지는 배포처가 달라(이 저장소 `docs/` vs 블로그 저장소) 경로 대소문자도 다릅니다.
    자세한 건 `web/README.md` 참고.
  - **도메인을 바꾸면 엔타이틀먼트·AASA·App Store Connect 세 곳을 모두 고쳐야 합니다.**
- **주의**: 클립 버전(`MARKETING_VERSION`)은 메인 앱과 **반드시 일치**해야 제출이 통과합니다.

### Models
- **Timer**: 타이머 데이터 구조
- **TimerRecord**: 타이머 사용 기록
- **RereminderTimerData**: 타이머 공유 데이터
- **TimerActivityAttributes**: Live Activity 속성

## Claude와 작업할 때 가이드라인

### 1. 코드 변경 전
- 항상 관련 파일을 먼저 읽고 이해하기
- 기존 코드 스타일과 패턴 유지하기
- Shared 모듈 변경 시 iOS, Watch, Widget 모두에 영향 고려

### 2. 새 기능 추가 시
1. 관련 Model이 필요한지 확인 (Shared/Models/)
2. 비즈니스 로직은 ViewModel 또는 Manager에 구현
3. UI는 View 또는 Components에 구현
4. 플랫폼 간 공유가 필요하면 Shared 모듈 활용

### 3. 버그 수정 시
1. 버그 재현 조건 파악
2. 관련 파일 분석 (TimerEngine, AppStateManager 등)
3. 최소한의 변경으로 수정
4. 사이드 이펙트 확인

### 4. 리팩토링 시
- 기능 변경 없이 구조만 개선
- 한 번에 하나의 리팩토링 작업만 수행
- 테스트 가능한 단위로 커밋

### 5. 문서화
- 복잡한 로직에는 주석 추가
- Public API에는 문서 주석 작성
- 이 claude.md 파일을 주요 변경사항마다 업데이트

## 테스트 체크리스트

### iOS 앱
- [ ] 타이머 시작/정지/리셋 동작 확인
- [ ] 알림 설정 및 발송 확인
- [ ] 백그라운드 동작 확인
- [ ] Live Activity 표시 확인

### Watch 앱
- [ ] iOS 앱과 동기화 확인
- [ ] Watch 독립 실행 확인
- [ ] 컴플리케이션 업데이트 확인

### 위젯
- [ ] 홈 화면 위젯 표시 확인
- [ ] 잠금 화면 위젯 표시 확인
- [ ] 위젯에서 타이머 제어 확인

### App Clip
- [ ] 시간 프리셋 선택 시 알림 3개 지점이 갱신되는지
- [ ] 실기기에서 백그라운드 3번 알림 수신 확인 (시뮬레이터로는 검증 불가)
- [ ] 전체 앱 유도 `SKOverlay` 표시 확인
- [ ] 호출 URL `?minutes=N` 으로 시작 시간이 반영되는지

## Mac (Mac Catalyst)

메인 앱은 **Mac Catalyst 로 함께 빌드된다**(`SUPPORTS_MACCATALYST = YES`,
`TARGETED_DEVICE_FAMILY[sdk=macosx*] = "2,6"`). 2026-07-26 에 한 번 껐다가(`8a4dd74`) 2.1.1 에서 되살렸다 —
앱은 온보딩·기기 안내·연결 칩에서 맥을 계속 이야기하는데 정작 설치가 불가능한 상태였다.

- **App Clip 은 iOS 전용이다.** 임베드 항목에 `platformFilter = ios;` 가 붙어 있어야 한다.
  없으면 Catalyst 빌드가 *"target is built for macOS but contains embedded content built for
  the iOS platform (RereminderClip.app)"* 로 실패한다.
- ⚠️ **iPad 는 지원하지 않는다. `TARGETED_DEVICE_FAMILY` 는 SDK 조건으로 갈라 둔다.**
  ```
  TARGETED_DEVICE_FAMILY = 1;                      // iOS 빌드 = iPhone 전용
  "TARGETED_DEVICE_FAMILY[sdk=macosx*]" = "2,6";   // Catalyst 빌드에서만 iPad+Mac
  ```
  메인 앱과 위젯 확장에 걸려 있고, App Clip 은 `1` 하나만 둔다(Catalyst 에서 아예 빠지므로).
  Catalyst 는 iPad 앱을 바탕으로 만들어져 iPad(`2`)를 요구하는데, 그 값이 iOS 빌드까지
  번지면 **iOS 앱이 iPad 앱이 되어 App Store 에 iPad 스크린샷을 내야 한다.** 이 앱은 iPad 화면을
  만든 적이 없으므로 조건부로 잘라 둔 것. 결과: iOS `UIDeviceFamily = [1]`, Catalyst = `[6]`.
- ⚠️ 위 조건을 지우고 `"1,2"` 로 되돌리면 업로드가 두 번 거부된다(2026-08-20 에 겪음):
  1. *"The UIDeviceFamily of an App Clip ('[1]') must be equal to ... parent app ('[1, 2]')"*
     — 클립도 `"1,2"` 로 맞춰야 한다
  2. 그다음엔 *"you need to include all of the ... orientations to support iPad multitasking"*
     — iPad 를 지원하면 `..._iPad` 방향 네 개를 전부 적어야 한다
  둘 다 "iPad 를 지원하겠다"는 전제에서만 필요한 작업이다. 지원할 생각이 없으면 조건부 설정을 유지할 것.
- 메뉴 막대 번들(`RereminderMenuBar`)은 반대로 `platformFilter = maccatalyst` 로 Catalyst 에서만
  들어간다. Catalyst 전용 엔타이틀먼트는 `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` 로 연결돼 있다.
- ⚠️ **iOS 배포 타깃이 26.0 이라 Catalyst 앱은 macOS 26 이상에서만 돈다**
  (`LSMinimumSystemVersion = 26.0`). 더 낮은 맥을 지원하려면 iOS 타깃부터 낮춰야 한다.
- ⚠️ **App Store Connect 에 macOS 플랫폼을 따로 추가하고 별도 심사를 받아야** 맥에 설치된다.
  빌드 설정만 켠다고 스토어에 나타나지 않는다.
- 빌드 확인: `xcodebuild -scheme Rereminder -destination 'platform=macOS,variant=Mac Catalyst' build`
- 맥에서는 자기 자신의 연결 상태를 보여주지 않는다(`DevicePresence` 가 자기 기기를 세지 않으므로
  그대로 두면 "Mac 연결 안 됨"이 늘 떠 있다).

## 빌드 환경
- **Xcode**: 15.0+
- **iOS Deployment Target**: iOS 26.0 (프로젝트 설정 기준 — 문서에 16.0 으로 적혀 있던 건 옛날 값)
- **watchOS Deployment Target**: watchOS 11.6
- **Swift Version**: Swift 5.9+

## 의존성
- **LeeoKit** (SPM, 2.9.0+): 공용 StoreKit 2 엔진(LeeoStore)·사용 리포터·원격 킬스위치(LeeoRemoteFlags)·MetricKit 크래시 진단(LeeoDiagnostics) 등 자체 공용 모듈. 킬스위치 플래그는 `Rereminder/Modules/RereminderFlags.swift`, Dashboard 수동 작업은 `docs/OPERATIONS_CHECKLIST.md` 참고
- **외부 분석 SDK 없음**: Firebase(2026-07)에 이어 TelemetryDeck(2026-08)도 제거했다.
  App ID 가 비어 있어 실제로 아무것도 보내지 않았고, 사용 통계는 CloudKit 허브가 이미 담당한다.
  이벤트는 `AnalyticsManager` → `ActivityReporter` 한 경로로만 나간다.

## CI / 린트
- **GitHub Actions** (`.github/workflows/ci.yml`): main/dev push·PR 시 iOS 시뮬레이터에서 유닛 테스트 실행 + SwiftLint
  - 주의: `CODE_SIGNING_ALLOWED=NO` 로 빌드하면 entitlements 가 빠져 CloudKit 초기화가 크래시하므로 사용 금지
- **SwiftLint** (`.swiftlint.yml`): 로컬에서 `swiftlint lint` 로 실행

## 릴리즈 프로세스
1. dev 브랜치에서 기능 개발 및 테스트
2. dev → main PR 생성 (모든 머지된 PR 목록 포함)
3. main 브랜치 머지 후 버전 태그 생성
4. App Store Connect에 빌드 업로드

## 문서 업데이트 규칙

### 이 문서를 업데이트해야 하는 경우
1. **새로운 주요 기능 추가**: 새 모듈, 매니저, 주요 컴포넌트 추가 시
2. **아키텍처 변경**: MVVM 구조, 데이터 플로우, 상태 관리 방식 변경 시
3. **프로젝트 구조 변경**: 새 디렉토리 추가, 파일 구조 재구성 시
4. **개발 워크플로우 변경**: 브랜치 전략, 커밋 규칙, PR 프로세스 변경 시
5. **의존성 추가/제거**: 새 라이브러리 추가 또는 제거 시
6. **빌드 환경 변경**: Xcode 버전, iOS 타겟, Swift 버전 변경 시

### 업데이트 방법
```bash
# 변경 사항이 있을 때마다 이 파일 수정 후 커밋
git add claude.md
git commit -m "docs: claude.md 업데이트 - [변경 내용 요약]"
```

## 버전 히스토리

### v2.2.0 (2026-08-22)
- **타이머 모양 선택** (`TimerShape` + 설정 > 화면 > 타이머 모양): 원형 링 / 이중 링 / 구간 막대 /
  접은 줄(ㄹ자). 실루엣을 보고 고르고(`TimerShapeSilhouette`), 실행 중에는 **한 번에 하나만** 그린다
  (원 아래 보조 막대 자리는 없어지고 막대가 모양 중 하나가 됐다)
- **이중 링** (`SectionInnerRing`, iPhone·워치 공용): 바깥=전체, 안쪽=지금 구간.
  계산은 `TimerSections.progress` 하나. 60분 초과여도 이중 링에서는 '전체 한 바퀴' 좌표를 쓴다
- **가운데 두 줄**: 전체 남은 시간 + 지금 구간 남은 시간(구간 색 점). "Next 알림" 안내 박스는 제거
- **동작 줄** (`TimerActionBar`): 버튼을 원 밖으로. 채운 캡슐 + 글자, 테마 강조색
- **접은 줄** (`SnakeTimerView`) 신설, 막대·접은 줄에도 **알림 종** 표시
- **발표 구간 대본** (`sectionScripts` → `SectionScriptSheet` / `PresentationScriptPanel`):
  구간마다 할 말을 적고, 발표 중 그 구간 차례에 펼쳐진다
- **알림 문구를 알림 시트에서** 편집(설정 깊숙한 곳에만 있어 아무도 못 찾던 기능)
- **새 온보딩** (`OnboardingFlowView`): 용도 고르기 → **10초 체험**(길이와 무관, `OnboardingDemoTimer`)
  → 템플릿 저장 → 기기 안내. 끝나면 고른 설정이 다이얼에 올라가 있다. 옛 7장 안내·문구는 제거
- **통계(개발자)**: 주로 쓰는 알림 개수 히스토그램(`alertRuns.*`), 화면 전체를 차트로
  (`UsageChartViews` — 분포·퍼널·비율·나열·리텐션)
- 테스트 202개, 릴리즈 노트: `docs/release-notes-2.2.0.md` (ko/en/ja)


### v2.1.1 (2026-08-19)
- **Mac Catalyst 재활성화**: `SUPPORTS_MACCATALYST=YES`·`TARGETED_DEVICE_FAMILY="1,2"` 복구
  (2026-07-26 에 꺼져 있어 맥에 설치 자체가 불가능했다). App Clip 임베드에 `platformFilter = ios`
  를 달아 Catalyst 빌드 실패를 해결. 맥에서 실행·창 표시까지 확인
  → **App Store Connect 에 macOS 플랫폼 추가 + 별도 심사 필요, macOS 26 이상만 지원**
- **구간별 카운트다운 리스트** (`SectionCountdownList`): 실행 중 원 아래에 구간마다 한 줄.
  앞 구간이 줄어드는 동안 뒤 구간은 제자리에 서 있다가 경계를 지나면 줄기 시작한다.
  글자 색은 링의 구간 색과 같고, 지금 구간만 진하다 (테스트 3개)
- **연결 판정 수정**: 워치는 도달성(`isReachable`)이 아니라 **페어링 + 앱 설치**로 판단하고,
  맥은 심장박동 표시가 없어도 **타이머 동기화 스냅샷**을 증거로 본다 —
  "동기화는 되는데 연결 안 됨"이 뜨던 문제 (테스트 8개)
- **기기 연결 상태 칩** (`DeviceLinkChips`): 원 아래에 워치·맥 연결 상태.
  "있어요"라고 답한 기기만, 안 될 때만 글자를 붙인다. **대기 중에도 보인다**(걸기 전에 고쳐야 하니까)
- **연결 안내 화면** (`DeviceConnectionHelpView`): 칩이나 설정의 상태 줄을 누르면 지금 상태 +
  할 일(워치 4단계·맥 3단계) + "다시 확인" + 기기별 활용 안내로 이어진다
- **기기 종류를 SDK 조건으로 분리**: Catalyst 를 켜며 딸려온 iPad(`2`)가 iOS 빌드까지 번져
  업로드가 거부됐다(App Clip 기기 종류 불일치 → iPad 멀티태스킹 방향).
  iPad 를 지원할 계획이 없으므로 `TARGETED_DEVICE_FAMILY = 1` +
  `[sdk=macosx*] = "2,6"` 으로 갈라, **iOS 는 iPhone 전용·Mac 만 Catalyst** 로 유지
- **레거시 삭제**: `Clock.swift` / `ClockMarkers.swift` / `TimerRunningView.swift` (아무도 안 씀).
  종 노브 아래 깔려 있던 주황 작대기가 사라져, 알림이 울린 뒤 종이 흐려질 때 혼자 남던 직사각형도 없어짐
- **진행 중에도 링 구간 색 유지**: 타이머를 시작하면 단색(강조색)으로 바뀌던 링이 이제 알림으로
  나뉜 구간 색을 그대로 유지한다. 구간 번호 역매핑을 `TimerSections.ringSectionIndex`로 옮기고
  자리 번호 대신 "뒤에 남은 알림 수"로 계산 — 진행 중 색이 한 칸씩 밀리던 문제 방지(테스트 4개)
- **기기 연결 상태 심볼**: 설정 > 내 기기에서 "있어요"라고 한 기기에 연결 상태를 보여준다
  - 워치: `WatchConnectivityManager.linkStatus`(페어링 없음 / 워치에 앱 없음 / 닿지 않음 / 연결됨)
  - 맥: `DevicePresence` — 각 기기가 iCloud KVS에 5분마다 남기는 표시를 읽어 10분 안쪽이면 연결됨
- **기기 보유 질문** (`Rereminder/Modules/DeviceOwnership.swift`): 타이머가 실제로 돌기 시작한
  순간에 "Apple Watch를 쓰시나요?"를 한 번 묻고, 하루 뒤 "Mac을 쓰시나요?"를 묻는다
  - 답은 설정 > **내 기기** 섹션에 저장되고 거기서 바꿀 수 있다
  - **없다고 하면 그 기기 이야기는 질문도 안내도 다시 나오지 않는다**
  - 있다고 하면 그 자리에서 "이제 워치에서도 남은 시간을 확인하세요" 토스트,
    이후 그 기기에서 아직 안 써 봤으면 타이머를 걸 때 가끔(5회 간격, 최대 3회) 권한다
  - 페어링된 워치·Mac Catalyst 실행은 묻지 않고 확정, 워치에서 조작이 오면 사용까지 확정
  - 통계에도 `flag.ownsWatch`·`flag.ownsMac`(답한 설치만) + `device_ownership_answered` 이벤트
  - 시뮬레이터에서 질문 알림·안내 토스트 실제 노출 확인, 테스트 10개
- **통계를 결제 퍼널로 재편** — "지금 결제에 가까운 사람이 몇 명인가"에 답하도록.
  이 앱의 결제는 알림 개수로 갈리므로(무료 1개 → 5+5 체험 → 결제) 그 거리를 지표로 삼는다
  - 수집 추가(`UsageMetrics`): `alertsMax`(한 타이머 최대 알림 수)·`multiAlertRuns`·
    `alertLimitHits`(막힌 횟수)·`paywallViews`, `ActivityReporter`가 `trial.prealerts`·
    `flag.prealertTrialExtended`(체험 상태)를 스냅샷에 실어 보낸다
    (`metrics`는 JSON 한 필드라 CloudKit 스키마 배포 불필요)
  - `AnalyticsManager.timerStarted`에 `alertCount` 추가 (TimerEngine이 실제 알림 수를 넘긴다)
  - `UsageInsights` 신설 함수: `profiles`(설치별 결제 근접도)·`paymentFunnel`(6칸, 스냅샷 기준)·
    `purchaseReadiness`·`hotLeads`·`alertDemandDistribution`·`segmentCounts` — 테스트 9개 추가
  - `UsageStatsView`에 "결제 준비도(지금)"·"결제 퍼널(지금 상태)"·"알림 개수 수요"·"사용자 구분"
    섹션 추가, 기존 이벤트 퍼널은 "결제 이벤트(기간 누적)"으로 이름을 갈라 뜻이 섞이지 않게 함
  - **`UserSegmentListView` 신설**: 설치를 구분별로 한 명씩 보는 명단(익명 ID 앞 8자리,
    알림 최대 개수·막힌 횟수·남은 체험·마지막 활동)

### v2.1.0 (2026-08-16)
- **LeeoKit 2.9.0 상향**: `UsageEvent`에 `occurredAt`·`installID`가 실린다
  (⚠️ 배포 전 CloudKit 스키마 배포 필수 — `docs/OPERATIONS_CHECKLIST.md` 3번)
- **로컬 카운터 도입** (`Shared/Modules/UsageMetrics.swift`): 이벤트 쓰로틀(6시간) 때문에
  셀 수 없던 "몇 번 했나"를 기기에서 세어 스냅샷 `metrics`로 보낸다
  (완주 횟수·관리한 시간·템플릿/발표/워치 사용·알림 권한 플래그)
- **ActivityReporter 확장**: 이름당 쓰로틀, `app_open`(20시간, 화면이 실제로 뜨는 경로에서만),
  이벤트 스트림 조회(커서 3,000건)·이름별 집계·기간별 추이
- **UsageInsights 신설**: 활성화/온보딩/결제 퍼널, 주간 코호트 리텐션, 완주 횟수 분포,
  기능 채택률 — 전부 순수 함수 + 유닛 테스트 12개
- **통계 대시보드 자체 구현** (`Rereminder/Views/UsageStatsView.swift`): LeeoKit 기본 화면 대신
  이 앱의 판단 지표(완주율·0회 사용자·알림 권한 허용률)를 보여주고, 피드백 인박스로 이어진다.
  기간별 추이 차트(일·주·월·연, 좌우 스크롤·탭 값 읽기)는 `Views/Components/UsageTrendChartView.swift`
- **의견 요청 도입** (`Rereminder/Modules/FeedbackNudge.swift`): 설정 안에 숨은 피드백 버튼을
  스스로 찾아오는 사용자는 드물다 — 앱이 먼저 묻고, 노출·수락을 이벤트로 남겨 통계 화면의
  "의견 요청 수락률"로 확인한다 (테스트 4개)
- **현지화 위생**: 동적 키 41건을 `extractionState: manual`로 전환 — 빌드마다 stale로 찍혀
  predeploy 게이트를 막던 문제 해소
- **문서**: `docs/USAGE_STATS_HUB.md` 신설(수집 항목·집계 설계·스키마 배포 순서),
  `docs/FEEDBACK_CLOUDKIT.md`에 피드백 유입 경로 3가지 정리
- **다이얼**: 알림을 경계로 구간 색 상시 분할, 60분 초과 시 두 줄 링(바깥=첫 바퀴)
- **알림 칩**: 켜 둔 알림을 맨 앞으로 정렬
- **발표 구간 이름 편집**: 빈 곳 탭으로 키보드 내림(contentShape 누락 수정), 편집 카드 자동 스크롤
- **버그**: 60분 초과 시간을 수동 입력으로 줄일 수 없던 문제(분 휠 0~60 고정) 수정
- **정리**: TelemetryDeck 제거(외부 SDK 0개), 시간 표기·구간 계산·알림 게이트 중복 제거,
  죽은 코드 삭제(TimerSetupView 등), 발표 구간 목록을 별도 뷰로 분리, 테스트 118개
- 릴리즈 노트: `docs/release-notes-2.1.0.md` (ko/en/ja)

### v2.0.4 (2026-08-02)
- **서비스 성숙도 강화 (클립키보드 수준 정렬)**
  - LeeoKit 2.7.0 상향: 원격 킬스위치(LeeoRemoteFlags — usageReporting/diagnostics/cloudSync) + MetricKit 크래시 진단(LeeoDiagnostics) 통합
  - 분석 활성화: AnalyticsManager.eventSink → 익명 사용 허브(CloudKit) 전송 결선, 온보딩(shown/completed/skipped)·프리셋(saved/used) 퍼널 이벤트 추가
  - 리뷰 레거시 정리: ReviewRequestManager 죽은 정책 코드 제거(만족도 게이트가 단독 담당)
  - CI/배포 게이트: scripts/predeploy.sh(다국어 검사 + 전체 테스트) 단일 게이트를 CI·fastlane 공용으로 도입
  - 버전 관리 단일화: xcconfig 단일 소스(타겟 하드코딩 제거) — 이후 2.0.5에서 `Config/Version.xcconfig`로 정착
  - 현지화 위생: stale 키 72건 제거, 알림 권한 상태 오역 수정, 타이머 적용 토스트 현지화(ko/ja)


### v1.0.6 (2026-01-28)
- **중앙 집중식 버전 관리 시스템 도입**
  - Version.xcconfig로 모든 타겟의 버전 통합 관리
  - 버전 업데이트 스크립트 (update_version.sh) 추가
  - 수동으로 여러 곳을 수정할 필요 없이 한 번에 관리
  - Config/README.md에 상세 가이드 포함

### v1.0.6 (2026-01-28)
- **Live Activity 실시간 타이머 구현**
  - ContentState에 endDate 필드 추가하여 시스템이 자동으로 카운트다운
  - Text.timer 스타일 적용으로 실시간 업데이트 구현
  - 일시정지 시 정적 표시, 실행 중 자동 카운트다운 표시
  - 업데이트 빈도 최적화 (상태 변경 시에만 업데이트)

- **Live Activity UI 최적화**
  - 타이머 폰트 크기 조정 (40 → 28~32)으로 긴 숫자 잘림 방지
  - 타이머 이름: "dummy time setting" → 시간 기반 자동 생성 (예: "10분", "1시간 30분")
  - 타이머 이름 폰트 크기 축소 및 minimumScaleFactor 적용
  - 버튼 UI 간소화: 텍스트 제거, 아이콘만 표시 (공간 절약, 국제화 용이)
  - 버튼 크기 통일: 40x32 고정, 균일한 레이아웃
  - 버튼 간격 조정 (8 → 6)으로 공간 효율성 향상

- **앱스토어 리뷰 요청 시스템 구현**
  - ReviewRequestManager 추가로 Apple 가이드라인 준수
  - 타이머 5회 완료 시 자동으로 네이티브 리뷰 팝업 표시
  - 90일마다 최대 1회만 자동 요청 (사용자 경험 보호)
  - 사용자가 원할 때 직접 리뷰 작성 가능 (설정 화면)
  - 테스트 모드에서 완료 횟수 디버그 정보 표시

- **신규 파일**:
  - `Shared/Modules/ReviewRequestManager.swift`: 리뷰 요청 관리 로직

- **수정 파일**:
  - `Shared/Models/TimerActivityAttributes.swift`: endDate 추가
  - `RereminderAlarm/RereminderAlarmLiveActivity.swift`: 실시간 타이머, UI 최적화, 버튼 간소화
  - `Rereminder/ViewModels/TimerViewModel.swift`: Live Activity endDate 처리, 리뷰 요청 체크
  - `Rereminder/ViewModels/TimerScreenViewModel.swift`: 타이머 이름 자동 생성 로직
  - `Rereminder/ViewModels/NoticeSettingView.swift`: 리뷰 관련 버튼 개선 및 디버그 정보 추가

### v1.0.5 (2026-01-28)
- 초기 claude.md 문서 작성
- 프로젝트 구조 및 워크플로우 문서화
- 개발 가이드라인 정립

---

**최종 업데이트**: 2026-01-28
**문서 버전**: 1.0.6
**작성자**: Claude AI Assistant
