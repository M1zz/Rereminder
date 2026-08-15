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
- **FeedbackNudge** (`Rereminder/Modules/FeedbackNudge.swift`): 앱이 먼저 의견을 묻는 경로
  (10회째 실행 → 이후 40회 간격, "다시 보지 않기"=6개월 유예, 만족도 게이트에 양보).
  통계가 "어디서 떨어지는지"를 말해 준다면 이유는 이 경로로 들어온다.
- ⚠️ 개발자 전용 화면은 `Text(verbatim:)`으로 쓴다. `Text("한글")`·`Picker("", …)`·
  Charts의 `.value("한글", …)` 리터럴은 문자열 카탈로그에 추출돼 다국어 게이트를 막는다.
  동적 키(`guide_*`)·플랫폼 조건부 문자열은 카탈로그에서 `extractionState: manual`로 둘 것
  (그러지 않으면 빌드마다 stale로 찍혀 predeploy가 실패한다).

### 알림 배지 (종을 옮길 때 뜨는 툴팁)
종 노브를 끌면 그 지점을 **두 가지로** 읽어줍니다. 발표자는 "몇 분 남았나"와
"몇 분째 말하고 있나"를 둘 다 알아야 하기 때문입니다.

```
⚑ 1:00   ← 종료 전 남은 시간 (주황, DSColor.marker)
▶ 4:00   ← 시작 후 경과 (강조색)
```
(5분 발표에서 종료 1분 전에 종을 두면 위와 같이 나옵니다)

- 같은 순간 **링도 종을 경계로 두 색으로 갈라집니다.**
  0° ~ 종 = 주황(= 위 줄), 종 ~ 설정 시간 = 강조색(= 아래 줄).
  배지 줄 색과 링 구간 색이 같아야 어느 숫자가 어디인지 읽히므로, **한쪽만 바꾸지 마세요.**
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
- **Clock** (`Rereminder/Views/Components/Clock.swift`): 타이머 시계 UI
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

### (미출시) 서비스 판단 루프 — 통계·피드백으로 효용 확인 (2026-08-15)
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
