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
├── RereminderWatchWidget/    # 워치 스마트 스택 위젯 (워치 앱에 임베드)
│   ├── RereminderWatchWidgetBundle.swift   # 위젯 묶음 진입점
│   └── RereminderWatchTimerWidget.swift    # 타이머 카드 (4가지 accessory 가족)
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
- **EscalatingAlert** (`Shared/Modules/EscalatingAlert.swift`): "확인할 때까지 알린다" —
  종료 알림 되풀이 + 다른 기기로 번지기 (아래 절 참고)
- **RoundedRectRing** (`Shared/DesignSystem/RoundedRectRing.swift`): 화면 테두리를 따라가는
  둥근 사각 링의 경로·좌표(순수 함수). **워치 실행 화면**이 쓴다
- **WatchTimerState** (`Shared/Modules/WatchTimerState.swift`): 워치 앱 ↔ 워치 스마트 스택 위젯이
  함께 보는 타이머 상태 한 벌. 두 프로세스가 같은 숫자를 말하게 하는 유일한 장치
  (아래 "워치 스마트 스택" 참고)
- **RereminderAlarmManager** (`Shared/Modules/RereminderAlarmManager.swift`): 알림 관리
- **ReviewRequestManager** (`Shared/Modules/ReviewRequestManager.swift`): 앱스토어 리뷰 요청 관리

### 반복을 앱이 먼저 알아챈다 (RepeatDetector)
이 앱은 **상황이 반복되는 사람**에게만 팔린다(매주 수업, 매일 운동, 매번 같은 발표 형식).
그런데 그 반복을 앱에 남기려면 사용자가 스스로 "저장"을 결심해야 했고, 결심은 잘 나지 않는다.
반복은 이미 증거로 남아 있으므로 그 결심을 앱이 대신한다 — `RepeatDetector`.

판정은 두 갈래다 — **①저장 제안**("이 설정을 기억해 둘까")과 **②시간대 제안**("지금 이걸
하려던 참 아닌가"). 답이 다르므로 상한·기록도 따로 센다.

- 타이머를 시작할 때마다 **설정 지문(시간 + 알림 지점) + 그날 날짜 + 요일·시각**을 남긴다
  (`TimerViewModel.start`). 문구·이름은 지문에 넣지 않는다 — 같은 상황이면 같은 설정이다.
- **서로 다른 날 2일 이상**이면 반복으로 본다. ⚠️ **같은 날 다섯 번은 한 번의 상황이다** —
  실행 횟수로 세면 포모도로처럼 하루에 여러 번 도는 사용이 첫날부터 걸린다.
- 제안은 앱을 열었을 때 **마지막 설정을 복원한 뒤에** 판단한다(`offerToSaveRecurringSetupIfDue`).
  그 순간 다이얼에 올라온 설정이 곧 "또 하려는 그것"이다.
- ⚠️ **잔소리가 되지 않는 것이 이 기능의 성패다.** 세 겹으로 막는다:
  한 설정에 **한 번만**(거절해도 저장해도 `markProposed`), 전체 **3회** 상한,
  그리고 다른 안내(기기 질문·피드백 넛지·그랜드파더링)가 뜨는 차례면 **양보**한다.
- 이미 같은 시간·알림의 템플릿이 있으면 ①의 후보가 아니다(앱이 이미 기억하고 있다).
- **②시간대 제안**(`timeOfDaySuggestion`): 같은 **요일**·비슷한 **시각**(±1시간)에 서로 다른 날
  2일 이상 되풀이했으면, 그 시간에 앱을 열었을 때 "늘 이맘때 하시던 거네요"라고 묻고
  수락하면 다이얼에 올려 준다(`applyRepeatConfig` — 시작하지는 않는다).
  상한은 **2회**로 ①보다 적다 — 틀렸을 때 더 성가시다.
  ⚠️ **①과 ②를 한 번에 띄우지 말 것** — 앱을 열자마자 두 번 물으면 둘 다 안 읽힌다.
  ②를 먼저 보고, 띄웠으면 ①은 그 차례를 건너뛴다.
- ⚠️ 문구는 덮지 않는다 — 지문에 문구가 없으므로, 덮으면 사용자가 써 둔 말을 근거 없이 지운다.

⚠️ **날짜는 `LocalDay.stamp` 로 센다** — `timeIntervalSince1970 / 86400` 으로 세면 UTC 자정이
경계라 **한국에서는 오전 9시에 하루가 바뀐다.** 아침 8시와 10시에 한 번씩 쓴 것이 "이틀 반복"이
되어 첫날부터 제안이 뜬다(`RepeatDetectorTests` 가 이걸 잡았다). `PrealertGrace` 의 "하루 한 번"도
같은 함수를 쓴다.

### 다음 자리 예약 — 석 달 뒤에 기억해 주길 기대하지 않는다
`Rereminder/Modules/NextOccasionReminder.swift` + `Views/NextOccasionSheet.swift`.

돈을 낼 사람 중 하나(학회 발표자·분기 워크숍 진행자)는 **아픔은 강한데 주기가 길다.** 발표에서
잘린 그날 저녁에 앱을 깔고, 전날 리허설에서 잘 쓰고, 석 달 동안 열지 않는다. 그 사이 앱은 알림
한 번 보내지 않고 잊히며, 다음 발표가 잡히면 그는 **같은 검색을 다시 해서 다른 앱을 깐다.**

- ⚠️ **`RepeatDetector` 로는 이 사람을 못 잡는다** — 그쪽은 **주 단위 반복**(같은 요일·시각)을
  보는 장치라 분기 주기에는 영영 걸리지 않는다. 그래서 별도 경로다. 둘을 합치지 말 것.
- 세션을 **끝까지 마친 직후** 날짜 하나만 묻고(`NextOccasionSheet`), 그 **전날 저녁 19시**에
  로컬 알림을 건다. 발표 전날 저녁이 리허설 시간대다 — 당일 아침에 알려 봐야 고칠 게 없다.
  그래서 **고를 수 있는 날짜는 모레부터**다(내일 자리는 전날 저녁이 이미 지났다).
- 시트에서 **날짜 말고는 아무것도 묻지 않는다.** 세션을 막 끝낸 사람은 뒷정리 중이고, 그 자리에서
  폼을 채우게 하면 그냥 닫는다. 설정은 방금 쓴 것을 그대로 싣는다.
- ⚠️ **잔소리가 되면 실패하는 기능이다.** 네 겹으로 막는다(`NextOccasionReminderTests` 11개):
  ① 세션 모드로 완주했을 때만 ② 주 단위 반복 사용자에게는 묻지 않음
  ③ 아직 지나지 않은 예약이 있으면 묻지 않음 / 거절하면 완주 5회 유예 ④ 전체 3회 상한.
  다른 안내(피드백 넛지·기기 질문·반복 감지·창단 후원자)가 뜨는 차례면 양보한다.
- ⚠️ 지난 예약은 앱을 열 때 `clearIfPassed` 로 치운다 — 남겨 두면 "예약이 있다"고 판단해
  **발표 한 번 하고 영영 다시 묻지 않는다.**
- 판정 기준: `next_occasion_booked` 이벤트를 남긴 설치가 실제로 그날 돌아오는가.

### 결제 게이트 — 파는 축은 "세션 운영"이다
⚠️ **예비 알림은 무제한 무료다.** `ProGate.freePrealertLimit`(무료 2개)·`PrealertGrace`(하루 한 번
유예)·`Feature.unlimitedPrealerts` 는 **삭제됐다 — 되살리지 말 것.**

왜: 이 앱이 기본 시계 앱 대신 설치될 이유는 "끝나기 전에 여러 번 알려 준다" 하나뿐인데, 바로
그것을 개수로 세면 무료 사용자가 손에 쥔 것은 **기능적으로 기본 타이머**다. 결제는 잔존 위에서만
일어나는데 잔존이 생길 자리를 게이트가 먼저 막았다. 게다가 그 벽에 걸리는 사람은
**발표자·강사·퍼실리테이터**(= 실제로 돈을 낼 사람)이고, 25/5로 고정된 포모도로 사용자는 알림
2개로 충분해 페이월을 한 번도 보지 않았다 — **정확히 반대로 걸려 있었다.**

- **Pro 가 파는 한 문장은 "앱이 당신의 설정을 기억한다"**이다. 템플릿 저장·불러오기 +
  마지막 설정 복원이 그 알맹이고, 세션 모드(구간 이름·대본)·오버타임·기록도 같은 Pro 안에 있다.
  게이트는 흩어지지 않고 `ProGate.canRememberSetup` 하나로 통일된다.
- ⚠️ **템플릿에 무료 몫이 없다.** 예전의 `freeTemplateLimit = 3` 은 삭제됐다 — **개수로 다시
  나누지 말 것.** 저장·불러오기 자체가 파는 물건이다. 체험(5+5)도 없다: 기억은 쌓여야 값이
  나오는데 체험이 끝나면 쌓인 것이 사라져 "몇 번 더 써 보세요"가 성립하지 않는다.
- ⚠️ **무료 사용자는 앱을 껐다 켜면 다이얼이 기본값으로 돌아온다**
  (`restoreLastUsedConfigIfNeeded` 가 `canRememberSetup` 을 본다). 단 **콜드 런치에만** —
  홈에 다녀오는 정도로 초기화되면 그건 제한이 아니라 **고장**으로 읽힌다
  (`onAppear` + `didRestoreLastUsedConfig` 가 그 경계를 만든다).
- ⚠️ **저장(`persistLastUsedConfig`)은 무료에서도 계속 한다.** 결제하는 순간 마지막에 쓰던
  설정이 그대로 돌아오는 편이, 결제하고 빈손으로 시작하는 것보다 낫다.
- ⚠️ **못 하는 일을 권하지 않는다.** 무료 사용자에게는 반복 저장 제안(`RepeatDetector`)을 띄우지
  않고, 온보딩의 "템플릿 저장" 버튼도 내지 않는다(대신 그런 것이 있다는 한 줄만).
  이미 저장해 둔 템플릿은 **사라지지 않고 잠긴 채로 보인다** — 소리 없이 없어지면 "잃어버렸다"가
  되고 그건 결제가 아니라 분노다.
- 지표 임계값은 게이트를 따라가지 않는다: `UsageInsights.templateUserThreshold`(1, 고정).
- ⚠️ **사람에게 보이는 이름은 "세션 모드"다("발표 모드" 아님).** 필라테스·요가 강사는
  "발표 모드"를 보고 자기 것이라고 생각하지 않는데 실제로는 그가 이 기능의 주 사용자다
  ("세션"은 강사·트레이너가 쓰는 말이고 학회 발표자에게도 통한다).
  ⚠️ 반면 **코드 식별자는 `presentationMode` 그대로 둔다** — `Feature.rawValue` 가 분석 이벤트
  슬라이스(`paywall_shown:presentationMode`)와 스냅샷 키에 그대로 실려 있어 바꾸면 예전 데이터와
  갈라진다. 파일·타입 이름(`PresentationSectionList` 등)도 같은 이유로 유지.
  ⚠️ 온보딩의 **"발표"는 상황 이름**(`OnboardingUseCase`)이라 그대로 둔다 — 모드 이름이 아니다.
- ⚠️ **워치·맥을 유료로 돌리지 말 것.** 수업 중 강사 손목에서 진동하는 워치 화면은 다른 강사에게
  보이는 **유일한 광고**다. 막으면 획득 경로를 스스로 끊는다.
- ⚠️ 지표 임계값을 게이트에 묶지 말 것. `UsageInsights.heavyAlertThreshold`(3, 고정)와
  `UsageMetrics.multiAlertThreshold`(2, 고정)는 **게이트를 따라가지 않는다** — 따라가게 만들면
  변경 전후를 같은 자로 비교할 수 없다. `legacyFreeAlertLimit`(2)은 **과거 스냅샷을 읽을 때만** 쓴다.
- 결제 퍼널(`UsageInsights.stage`)의 "유료 영역을 건드렸나"는 이제 **발표 모드·템플릿**으로 센다.
  옛 축(알림 한도에 막힘)의 흔적도 함께 보는데, 예전 스냅샷을 계속 읽어야 하기 때문이다.
- 스냅샷 키 `trial.presentation`·`flag.presentationTrialExtended` 가 새 축의 체험 상태다.
  옛 키(`trial.prealerts`)는 늘지 않지만 **이름을 재활용하지 않는다** — 재활용하면 예전 값과
  합산돼 지표가 조용히 틀어진다. `UsageMetrics` 의 `alertLimitHits`·`graceGrants` 도 같은 이유로
  **늘지 않지만 남겨 둔** 키다.

### 창단 후원자 — 먼저 산 사람에게 값이 떨어지지 않게
`Rereminder/Modules/FoundingSupporter.swift`. 파는 물건의 축이 바뀌고(알림 개수 → 세션 운영)
가격이 오를 때, **먼저 산 사람이 손해를 봤다**가 되면 그 사람들은 두 번 다시 이 앱을 편들지
않는다. 그래서 바꾸기 전에 약속을 먼저 걸어 둔다 — *앞으로 생기는 유료 기능은 전부, 값 없이.*

- ⚠️ **이 약속은 되돌릴 수 없다.** `grant` 만 있고 revoke 가 없는 이유다. **앞으로 유료 기능을
  추가할 때 게이트에서 `FoundingSupporter.isFounder` 를 반드시 함께 볼 것** — 그러지 않으면
  이 파일은 지키지 않은 약속의 기록이 된다.
- 경계는 **"이 버전을 처음 실행한 순간"**(`windowClosedAt`)이다. ⚠️ **출시 날짜 상수를 찍지
  말 것** — 출시일은 심사·재제출로 밀리는데 상수는 안 밀린다. 하루만 어긋나도 옛 가격에 산
  사람이 자격에서 빠지거나, 새 가격에 산 사람이 평생 무료를 받는다.
- ⚠️ **그래서 이 기능은 모델 변경과 반드시 같은 릴리즈에 나가야 한다.** 먼저 내보내면 그
  시점에 창이 닫혀, 그 뒤 변경 전까지 옛 가격에 산 사람이 자격을 못 받는다.
- 판정 세 갈래:
  ① **첫 실행에 이미 Pro** → 결제는 반드시 그보다 앞이다(`refreshFromCurrentState`).
    StoreKit 없이도 참이라 오프라인·콜드런치에서 자격을 놓치지 않는다.
    자동 Pro 환경(개발·샌드박스·맥)은 결제가 아니므로 제외한다.
  ② **`originalPurchaseDate` < `windowClosedAt`** (`refreshFromStoreKit`) — 재설치·기기 교체로
    복원해도 결제 시각은 그대로라 **한참 뒤에 복원해도 자격이 살아 돌아온다.**
  ③ **그랜드파더링된 기존 사용자**도 같은 대접(`Origin.grandfathered`). 이미 "평생 무료"라고
    말해 뒀고, 그 말의 범위를 나중에 좁히는 건 약속을 깨는 것이다.
- ⚠️ 판정을 `StoreManager`(`Shared/`)에 넣지 말 것 — 그 파일은 워치·위젯에서도 컴파일되므로
  앱 전용 코드를 참조하면 그쪽 빌드가 깨진다.
- 저장은 **Keychain + UserDefaults 두 벌**이고, 자격뿐 아니라 **창이 닫힌 시각까지** Keychain 에
  남긴다 — 시각을 안 남기면 새 가격에 산 사람이 **재설치·복원만으로 자격을 주워 간다**
  (`testReinstallDoesNotLetLatePurchaserSneakIn`). 테스트에서는 Keychain 을 주입해 갈아 끼운다
  (시뮬레이터에 남은 값이 다음 테스트로 샌다).

**보이는 곳** — 안내는 한 번, 표식은 계속:
- `FounderWelcomeView` (`Rereminder/Views/`): 혜택 변경 안내 **화면**. 알림 한 줄이 아니라
  화면인 이유는, 먼저 산 사람의 불안("내가 산 게 값이 떨어졌나")이 한 문장으로는 안 풀리기
  때문이다. 무엇이 어떻게 바뀌는지 **앞뒤로** 보여 주고 무엇도 빼앗기지 않는다고 확인시킨다.
  최초 1회 자동, 이후엔 설정 > Pro 줄의 "바뀌는 내용 보기"로 다시 연다.
  ⚠️ 그랜드파더링 안내(`showGrandfatherThanks`)보다 **우선한다** — 같은 말을 더 자세히 하므로
  둘 다 띄우면 겹친다. 다른 안내(기기 질문·피드백 넛지·반복 감지)는 이 화면에 양보한다.
- ⚠️ `FounderChange.current` 의 문구는 **실제로 그 변경이 나가는 릴리즈에 맞춰** 고칠 것.
  아직 안 바뀐 것을 바뀐다고 적으면 이 화면은 신뢰를 얻는 대신 잃는다.
- `FounderBadge` / `FounderPromiseRow` (`Views/Components/`): 설정 Pro 줄과 페이월에 남는 표식.
  안내는 한 번뿐이지만 **대접받고 있다는 사실은 계속 보여야** 한다.
- 테스트: `RereminderTests/FoundingSupporterTests.swift` (20개)

### 저장소 (SwiftData) — ⚠️ CloudKit 자동 동기화를 켜지 말 것
템플릿(`Timer`)·기록(`TimerRecord`)은 앱 그룹 안의 로컬 SwiftData 스토어에 저장된다.
컨테이너는 `RereminderApp.sharedModelContainer` **하나**이고, `cloudKitDatabase: .none` 이다.

- ⚠️ **`.modelContainer(for:)` 를 쓰지 말 것.** 기본값이 `cloudKitDatabase: .automatic` 이라,
  앱에 iCloud(CloudKit) 엔타이틀먼트가 있으면 로컬 스토어에도 CloudKit 스키마 규칙을 강요한다:
  모든 속성이 optional 이거나 기본값이 있어야 하고, 관계도 optional 이어야 하며,
  `@Attribute(.unique)` 는 쓸 수 없다. `Timer`·`TimerRecord` 는 셋 다 어긴다
  (`id` 가 unique, `runs` 가 non-optional, 기본값 없는 속성 여럿).
- 그래서 피드백 허브용 iCloud 엔타이틀먼트가 붙은 뒤로 **스토어가 통째로 로드에 실패했고,
  템플릿·기록이 하나도 저장되지 않았다.** 화면에는 아무 오류도 뜨지 않고 콘솔에만
  `CoreData: error: Store failed to load` 가 찍힌다 — "템플릿이 저장되지 않는다"는 제보의 정체.
- 기기 간 타이머 동기화는 CloudKit 이 아니라 `CloudTimerSyncManager`(iCloud KVS)가 한다.
  템플릿까지 동기화하고 싶어지면 엔타이틀먼트가 아니라 **모델을 먼저** 위 규칙에 맞춰야 한다
  (unique 제거 + 마이그레이션).
- 검증: `RereminderTests/TemplateSaveTests.test_appModelContainer_loadsRealStoreAndPersists`
  (메모리 폴백으로 떨어지지 않았는지까지 본다 — 폴백은 저장이 되는 것처럼 보인다).

### 템플릿 저장 (`TimerConfigService`)
저장은 Pro 다(`ProGate.canSaveTemplate`). 그 판정은 **`saveIfNeeded` 첫 줄에서 한 번만** 한다.

- ⚠️ **"무료 = 한도 0" 으로 구현하지 말 것.** 저장한 뒤 한도 초과분을 지우는 정리 루프가
  **시드 템플릿까지 통째로** 지웠다. 무료 사용자는 타이머를 한 번 시작하는 것만으로
  (시작이 `applyCurrentSettings` → `saveIfNeeded` 를 부른다) 칩이 전부 사라졌다.
  저장을 막는 것과 갖고 있던 것을 지우는 것은 전혀 다른 일이다 — 칩은 잠긴 채로 남아야 한다
  (`TemplateQuickBar` 머리말).
- 중복은 **전체 템플릿**과 견주고, 견주기 전에 알림 오프셋을 저장될 모양(`validateInPlace` —
  범위 밖 제거 + 오름차순)으로 정규화한다. 맨 앞 하나만 보면 A·B 를 번갈아 쓸 때마다,
  정렬을 안 맞추면 순서만 다른 같은 설정이 매번 새 칩으로 쌓인다.
- `saveIfNeeded` 는 저장 결과를 돌려주고, "저장됨" 토스트는 **참일 때만** 뜬다.

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

### Live Activity 생김새 — 앱과 같은 색 체계
잠금화면·다이나믹 아일랜드는 **앱과 같은 색 규칙**을 쓴다. 예전에는 여기만 초록(재개)·주황
(일시정지)·빨강(정지) 세 원색을 `.borderedProminent` 사각 버튼으로 칠하고 keyline 도 주황
고정이라, 앱을 보다가 잠금화면을 보면 **다른 앱처럼** 보였다.

- 진행·강조 = **사용자가 고른 테마 강조색**. ⚠️ 확장은 `UserDefaults.standard` 를 읽지 못하므로
  (자기 컨테이너를 본다) 앱이 테마를 바꿀 때마다 **앱 그룹에 hex 를 한 벌 적어 둔다**
  (`SharedAccent`). `ThemeManager` 의 `didSet` **과 `init` 양쪽**에서 쓴다 — init 에서는 didSet 이
  돌지 않아, 그것만 빼먹으면 업데이트 직후 잠금화면만 기본색으로 남는다.
- 버튼은 **동그라미**, 색도 앱과 같다: 정지 `DSColor.plain`(회색, 왼쪽) / 일시정지
  `DSColor.negativeSoft`(주황) / 재개 `DSColor.positive`. 배치도 앱의 원 안과 같은 순서다.
- ⚠️ **주황을 진행 표시에 쓰지 말 것** — 이 앱에서 주황은 알림 종의 색이다.
- ⚠️ 카운트다운은 **`Text(timerInterval:countsDown:)`** 으로 그린다.
  `Text(endDate, style: .timer)` 는 잠금화면의 큰 글씨에서 iOS 가 **"8 minutes" 같은 자연어**로
  대체해 버려 초가 사라진다(다이나믹 아일랜드 컴팩트에서는 "9:10" 으로 나와 더 헷갈렸다).
- `Color(hex:)` 는 `SharedAccent.swift` 에 있다(예전엔 `ThemeManager` 안). ⚠️ 그 파일은 앱·위젯
  확장·**App Clip** 세 타겟에 모두 들어가야 한다 — 클립도 `ThemeManager` 를 쓰므로 빠지면
  클립 빌드가 깨진다.

### 워치 스마트 스택 — 손목에서 앱을 열지 않고 보는 자리
`RereminderWatchWidget/` (타겟 `RereminderWatchWidgetExtension`, 번들 ID
`com.xa.toki.watchkitapp.widget`). **워치 앱 안에 임베드된다** — `RereminderWatch.app/PlugIns/`.

⚠️ **아이폰 위젯(`RereminderAlarm`)을 아무리 고쳐도 손목에는 나타나지 않는다.** 스마트 스택에는
워치 앱의 확장만 올라가므로 별도 타겟이 필요하다. 2.2.2 까지 그 타겟이 없어서 사용자가 이 앱을
스마트 스택에 고정할 방법이 **아예 없었다**(실제로 들어온 피드백이다).

- 카드에서 가장 큰 숫자는 **전체 남은 시간**, 그 아래 한 줄은 **다음 알림까지**다.
  ⚠️ 그 한 줄을 빼지 말 것 — 빼는 순간 이 카드는 기본 시계 앱의 타이머 위젯과 구별되지 않는다.
  구간이 둘 이상이면 오른쪽 위에 `2/4`(`TimerSections`)가 붙는다.
- 가족은 넷 — `accessoryRectangular`(스마트 스택 카드) · `accessoryCircular` ·
  `accessoryInline` · `accessoryCorner`. 뒤 셋은 **워치 페이스 컴플리케이션**이기도 하다.
- **관련도**(`relevance()`, watchOS 11+): 타이머가 도는 동안(`RelevantContext.date(from:to:)`)만
  스마트 스택이 이 카드를 위로 올린다. 없으면 사용자가 직접 고정하지 않는 한 좀처럼 보이지 않는다.
- 탭하면 워치 앱이 열린다(`widgetURL` 없이 기본 동작). 타이머가 돌고 있으면 앱이 켜지면서
  `restoreFromSavedState` 가 실행 화면을 세우므로, 따로 딥링크를 만들지 않았다.

**상태를 넘기는 길** — `Shared/Modules/WatchTimerState.swift`:

- 위젯은 앱과 **다른 프로세스**라 `UserDefaults.standard` 로는 서로를 못 본다(각자 제 컨테이너를
  본다). 그래서 앱 그룹(`group.leeo.toki`)에 한 벌 적고 양쪽이 그것만 읽는다.
  ⚠️ 워치 앱(`RereminderWatch/RereminderWatch.entitlements`)과 위젯
  (`RereminderWatchWidget/RereminderWatchWidget.entitlements`) **양쪽에 같은 그룹**이 있어야
  한다 — 하나만 빠지면 위젯이 늘 "활성 타이머 없음"만 보여준다.
  (앱 그룹 컨테이너는 **기기마다 따로**다 — 아이폰과 이어지는 통로가 아니다. 아이폰↔워치는
  `WatchConnectivityManager` 가 담당한다.)
- ⚠️ **남은 시간을 저장하지 않는다.** 시작 시각만 적고 읽는 쪽에서 뺀다
  (`WatchTimerState.remainingSeconds`). 그래서 앱이 꺼져 있어도 카운트다운이 정확하고,
  초마다 저장하지 않아 배터리도 덜 쓴다.
- ⚠️ **카운트다운을 타임라인 항목으로 세지 말 것.** `Text(timerInterval:)`·
  `ProgressView(timerInterval:)` 로 **시스템이** 세게 하고, 항목은 표시가 실제로 바뀌는
  순간(알림 경계·종료 = `refreshDates`)에만 세운다. 초마다 항목을 만들면 위젯 갱신 예산을
  그날 안에 다 써 버려 정작 필요할 때 카드가 멈춘다.
- ⚠️ **일시정지 중에는 `endDate` 가 nil 이다** — 멈춘 채로 흘러가는 카운트다운은 거짓말이다.
  그때는 고정된 숫자(`TimeMapper.clockText`)를 그린다.
- ⚠️ `WatchTimerStore.clear()` 는 **앱 그룹과 옛 저장소를 다 지운다.** 옛 저장소(2.2.2 이하가
  쓰던 `UserDefaults.standard`)를 남겨 두면 `load()` 의 되돌아보기가 이미 끝난 타이머를 되살려
  손목에 **유령 카드**가 선다. 그 되돌아보기는 타이머가 도는 중에 업데이트한 사용자의 복원이
  끊기지 않게 하려고 있는 것이다.
- 워치 앱의 `TimerViewModel` 은 저장·복원에 **`WatchTimerStore` 한 곳만** 쓴다. 여기서 따로
  `UserDefaults.standard` 에 적으면 위젯은 다른 컨테이너를 보고 있어 그 변화를 영영 모른다.
- 상태를 적으면 `reloadWidgets()` 가 함께 돈다 — 떼어 놓으면 "앱에서는 멈췄는데 위젯은 계속
  도는" 상태가 남는다.
- 테스트: `RereminderTests/WatchTimerStateTests.swift` (15개)

**빌드 배선** (Xcode 없이 pbxproj 를 고칠 때 함께 볼 것):
- 워치 앱 타겟에 `Embed Foundation Extensions`(dstSubfolderSpec 13) 페이즈와 위젯 타겟
  의존성이 있어야 한다. 없으면 확장이 `.app` 에 들어가지 않아 **빌드는 되는데 위젯이 안 보인다.**
- 위젯 타겟이 `Shared/` 에서 가져다 쓰는 파일은 pbxproj 의
  `Exceptions for "Shared" folder in "RereminderWatchWidgetExtension" target` 에 적혀 있다
  (`WatchTimerState`·`TimerSections`·`AngleCalculator`·`AppName`).
  **파일을 옮기거나 이름을 바꾸면 이 목록도 함께 고칠 것.**
- 문구를 쓰려면 `Localizable.xcstrings` 도 그 타겟에 있어야 한다(같은 방식의 예외로 걸려 있다).

### 워치 cold launch 복원 — 되살린 타이머를 다시 걸지 않는다
앱을 완전히 껐다 켜면 `SettingView.onAppear` 가 `TimerViewModel.restoreFromSavedState()` 로
돌던 타이머를 되살려 `fullScreenCover` 로 띄운다. 그 화면은 새 타이머와 **같은 `TimerView`** 다.

- ⚠️ **`start()` 는 이미 걸려 있으면 아무것도 하지 않는다**(`guard startDate == nil`).
  이걸 부르는 곳은 `TimerView.onAppear` 하나인데, 거기에는 복원한 타이머도 실린다. 가드가
  없으면 `startDate` 가 지금으로 덮여 **30분 타이머가 껐다 켤 때마다 30:00 부터 다시 시작**했다
  (스마트 스택 위젯도 같은 값을 읽으므로 손목까지 되감겼다). `onAppear` 는 화면이 다시 그려질
  때도 오므로 복원이 아니어도 다시 걸면 안 된다.
- ⚠️ **끝난 타이머는 되풀이 알림이 아직 울릴 때만 되살린다**(`shouldRestore`). 그때 화면이
  필요한 이유는 하나 — **확인 버튼을 주기 위해서**다. 이걸 빼면 알림은 울리는데 앱을 열면
  설정 화면이 떠서 **끌 방법이 화면에 없다**(알림을 직접 탭하는 길만 남는다).
  반대로 조건 없이 되살리면 세 시간 전에 끝난 타이머가 "00:00" 으로 떠오른다.
  되살리지 않을 때는 치우고, 그러면 스마트 스택의 "완료" 카드도 함께 정리된다.
  ⚠️ 판정은 `shouldRestore` **한 곳**에서만 한다 — `hasSavedState()` 도 그걸 본다.
- ⚠️ **복원 화면은 `path` 로 닫히지 않는다.** `fullScreenCover` 로 뜨고 `path` 가
  `.constant([])` 라, 정지를 눌러도 화면에 갇혀 있었다. 그래서 `TimerView` 가 닫는 법
  (`onExit`)을 부르는 쪽에서 받는다 — 밀어 넣은 화면은 `path` 를 비우고, 복원 화면은
  `restoredTimerVM = nil`.
- 일시정지 상태로 껐다 켜면 멈춘 채로 복원되고, 재개할 때 `togglePause` 가 **앱이 꺼져 있던
  시간까지** `accumulatedPause` 에 더한다.

### 워치 실행 화면 — 둥근 사각 링 (원이 아니다)
`RereminderWatch/Views/TimerView.swift` + `Shared/DesignSystem/RoundedRectRing.swift`.

애플워치 화면은 **둥근 사각형**이라 원을 그리면 네 모서리가 통째로 남는다. 예전에는 지름 120pt
원을 **고정으로** 그렸는데, 40mm(162×197pt)에서는 그 낭비 때문에 **아래 동작 버튼 두 개가
화면 밖으로 잘려** 있었고 알림 라벨("10분")도 오른쪽 가장자리에 걸쳤다. 링을 테두리로 밀어내면
가운데가 통째로 남아 상태·시간·버튼이 다 들어간다(40mm·46mm 스크린샷으로 확인).

- ⚠️ **링 경로와 알림 종 위치는 `RoundedRectRing` 하나에서 나온다.** `Ring`(Shape)의
  `trim(from:0,to:t)` 이 끝나는 자리가 곧 `point(atFraction: t)` 여야 한다 — 따로 계산하면
  줄어드는 호의 끝과 종이 서로 다른 시각을 가리킨다. 둘 다 `segments(in:cornerRadius:)` 를 쓴다.
- **12시에서 시작해 시계 방향**이다(원형 링과 같은 문법 — 사용자가 다시 배우지 않는다).
- ⚠️ 둘레를 걸을 때 **길이 0인 조각(모서리 반지름 0)은 건너뛴다.** 안 그러면 t 와 상관없이
  첫 모서리 좌표가 나와 **종이 전부 한 자리에 몰린다**(`RoundedRectRingTests` 가 잡는다).
- ⚠️ **링은 안전 영역을 넘고, 글자는 넘지 않는다.** 둘 다 가장자리로 내보내면 상태 줄이
  시스템 시계와 겹쳐 읽을 수 없다. 가운데 묶음은 `Spacer` 로 늘리지 **않는다** — 늘리면
  상태 줄이 화면 맨 위로 붙어 같은 문제가 난다.
- 알림 종은 **점만** 찍는다. 테두리 위에는 라벨 자리가 없고, 몇 분 남았는지는 가운데 큰 숫자가
  말한다(그 숫자 = 이 구간 남은 시간 = **다음 알림까지**).
- 링은 iPhone 과 같은 **구간 색**으로 나뉜다. 구간 번호는 반드시
  `TimerSections.ringSectionIndex` 로 센다(자리 번호로 세면 진행 중에 색이 한 칸씩 밀린다).
- 끝나면(`isFinished`) 화면이 한 가지만 말한다 — 🔔 + `00:00` + **확인 버튼 하나**.
  ⚠️ 시간 표시는 `max(0,…)` 로 자른다. 음수를 그대로 넣으면 `formattedTimeString` 이
  분·초를 따로 나눠 **"-1:-5"** 같은 값을 낸다.
- ⚠️ **`SectionInnerRing`(원형 이중 링)은 이제 아무도 쓰지 않는다.** 워치가 마지막 사용처였고
  둥근 사각 링으로 옮기며 빠졌다(모양이 섞이면 어지럽고, 40mm 에서는 안쪽 링을 넣을 자리도 없다).
  파일은 남겨 두었으니 되살릴 생각이 없으면 지워도 된다.
- 진행 방향 화살표(">>")는 걷어냈다 — 사각 경로에서는 접선 방향 계산이 필요한데, 작은 화면에서
  얻는 것보다 어수선함이 크다.

### 확인할 때까지 알림 — 놓친 알림은 알림이 아니다
`Shared/Modules/EscalatingAlert.swift` + 설정 > 알림 > **타이머가 끝나면**.

이 앱을 쓰는 이유는 **놓치면 안 되는 시간**인데 진동 한 번은(특히 손목에서) 놓치기 쉽다.
그래서 종료 알림을 사용자가 **정지·다시 알림**을 누를 때까지 되풀이한다.

- ⚠️ **되풀이는 알림 하나를 반복시키는 게 아니라 여러 개를 미리 깔아 두는 것이다.**
  `UNTimeIntervalNotificationTrigger(repeats:)` 는 60초 미만을 허용하지 않고, 무엇보다
  **앱이 꺼져 있으면 반복을 멈출 방법이 없다.** 그래서 종료 시각 기준으로 필요한 만큼 미리
  깔고, 확인하는 순간 남은 것을 전부 걷어낸다.
- ⚠️ **알림 예약은 앱당 64개가 상한이고 예비 알림과 같은 주머니를 쓴다.** 넘치면 iOS 가 조용히
  앞의 것을 버려 **정작 중요한 종료 알림이 사라진다.** 그래서 `EscalationSchedule.maxAlerts`(24)
  로 뚜껑을 씌웠다 — 설정에 더 긴 간격·시간을 열어 줄 때 이 숫자를 함께 볼 것.
- ⚠️ **기본값은 꺼짐이다.** 이 앱은 잔소리가 되는 순간 지워진다 — 켠 사람에게만 간다.
- **기기 사이로 번지기**: 손목이 먼저 울리고(워치 = 언제나 `.primary`), 30초
  (`EscalationSchedule.crossDeviceDelay`) 동안 확인이 없으면 iPhone 이 합류한다.
  iPhone 이 `.secondary` 가 되는 조건은 **워치가 돌리는 타이머를 받아 왔을 때**
  (`TimerEngine.applyRemoteRunning`)이고, 직접 시작한 타이머는 `.primary` 다.
  ⚠️ 둘 다 primary 로 두면 동시에 울려 "번진다"는 뜻이 사라진다.
- ⚠️ **반대 방향(iPhone → 워치)은 성립하지 않는다.** 워치 앱은 폰이 시작한 타이머를 받아
  처리하지 않고, 무엇보다 **꺼져 있는 워치 앱은 알림을 미리 깔 수 없다.** 대신 iOS 알림은
  잠긴 아이폰에서 페어링된 워치로 시스템이 전달하므로 손목은 그 경로로 울린다.
- **어느 기기에서 눌러도 전부 멈춘다** — `EscalatingAlert.acknowledgeEverywhere()` 하나로
  들어온다(알림 버튼·알림 탭·앱 안의 정지). 다른 기기에는 `WatchConnectivityManager` 가
  **두 경로**로 보낸다: `sendMessage`(상대 앱이 떠 있을 때 즉시) + `transferUserInfo`
  (꺼져 있어도 큐에 쌓였다가 전달). ⚠️ 후자만 쓰면 즉시성이 없고, 전자만 쓰면 주머니 속 폰에는
  영영 닿지 않는다.
- ⚠️ **정지든 다시 알림이든 그냥 탭이든 전부 "확인"으로 본다.** 알림을 탭해 앱을 열었는데
  계속 울리면 그건 기능이 아니라 고장으로 읽힌다.
- **다시 알림**(5분)은 **이 기기에서만** 다시 부른다 — 다른 기기엔 "멈춰"가 간다.
- `AlertNotificationDelegate`(`Rereminder/Modules/`): ⚠️ **이게 없으면 iOS 는 알림 버튼을
  눌러도 앱에 아무것도 전달하지 않는다.** 2.2.2 까지 이 앱에는 알림 델리게이트가 아예 없었다.
  앞에 있을 때는 **종료·되풀이 알림만** 배너로 띄운다(예비 알림까지 띄우면 타이머를 보는 내내
  배너가 쏟아지는데 그 숫자는 이미 화면에 있다).
- 워치는 앞에 있을 때 `willPresent` 가 매번 햅틱을 울리므로 **되풀이 햅틱이 그냥 따라온다** —
  따로 반복 타이머를 두지 않는다.
- ⚠️ 종료·예비 알림 문구는 iPhone·워치가 **같은 카탈로그 키**를 쓴다. 예전에는 워치 쪽만
  영어 리터럴이라, 되풀이를 켜면 첫 알림은 영어로 뜨고 두 번째부터 한국어로 바뀌었다.
- `interruptionLevel = .timeSensitive` — 엔타이틀먼트가 없으면 조용히 `.active` 로 내려앉을 뿐
  예약이 실패하지는 않는다. 집중 모드를 뚫으려면 포털에서 켤 것(`docs/OPERATIONS_CHECKLIST.md` 6번).
  ⚠️ **포털에서 켜기 전에 엔타이틀먼트 파일을 먼저 고치지 말 것** — 서명이 실패해 빌드가 막힌다.
- 설정 키(`alertRepeatInterval`·`alertRepeatDuration`·`alertEscalateAcrossDevices`)는
  iPhone 에서 고르고 `sendEscalationPolicy` 로 워치에 넘어간다. **양쪽이 같은 키를 읽는다.**
- 테스트: `RereminderTests/EscalatingAlertTests.swift` (12개),
  `RereminderTests/RoundedRectRingTests.swift` (9개)

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

### 대기 중 화면 — 구간 길이를 걸기 전에 보여준다
알림을 두 개 이상 켜 두면 원 아래에 **구간 길이 칩 한 줄**이 선다(`SectionLengthBar`) —
`○ 9:00  ○ 1:00` 처럼.

왜: 알림을 옮기는 조작은 링 위에서 **각도**로 한다. 각도는 "몇 분짜리 구간이 생겼나"를 말해
주지 못해서, 종을 옮겨 놓고 나서야 "그래서 첫 구간이 몇 분이지?"를 머리로 계산하게 된다.
그 답을 숫자로 바로 아래에 둔다.

- 색은 `SectionPalette` 그대로 — 링의 그 구간 호와 **같은 색**이어야 "저 파란 조각이 이 9:00"
  이라는 연결이 산다. 점 모양(빈 원)도 `SectionCountdownList` 의 '아직 오지 않은 구간'과 맞춘다.
- **실행 중에는 서지 않는다** — 그 자리는 줄어드는 숫자(`SectionCountdownList`) 몫이다.
  둘을 같이 세우면 같은 구간을 두 번 그리는 셈이고, 도는 동안 알고 싶은 건 남은 시간이다.
- 다 들어가면 **가운데**, 넘치면 가로로 민다(`ViewThatFits`). ⚠️ 스크롤뷰만 쓰면 칩이 늘 왼쪽에
  붙는데 바로 위의 원은 가운데라 어긋나 보인다.

### 실행 중 화면 — 링 한 겹 + 원 아래 구간 카운트다운
실행 중에도 화면은 **원 하나**다. 링은 알림 경계로 나뉜 구간 색을 그대로 유지하고
(`showsAlertSectionColors`), 가운데는 **전체 남은 시간 한 줄**, 그 아래에 동작 버튼 두 개,
원 밖 아래에 **구간별 카운트다운 리스트**(`SectionCountdownList`)가 선다.

⚠️ **2.2.0 에서 넣었던 "타이머 모양 선택"(원형 링 / 이중 링 / 구간 막대 / 접은 줄)과
이중 링·원 밖 버튼 바·선형 막대는 그 직후 전부 걷어냈다 — 모양 선택 자체를 없앴다.**
같은 시간을 두 군데에 그리면(원 두 겹, 또는 원 + 막대) 볼 때마다 어느 쪽이 무엇인지
골라야 해서 오히려 느리다.
`TimerShape`·`TimerActionBar`·`SectionProgressBar`·`SectionBarLayout`·`SnakeTimerView`·
`TimerShapeSilhouette`·`TotalTimelineStrip` 은 삭제됐다 — **되살리지 말 것.**

- **버튼은 원 안에 있다**(`TimerButtonStyle`, `buttonRow`) — 가운데 시간 바로 아래.
  원 밖으로 뺐던 이유는 가운데를 두 줄(전체 + 구간)로 쓰려던 것인데, 그 두 줄이 없어졌으므로
  버튼이 다시 안으로 들어왔다. 정지는 회색 원(`DSColor.plain`, 대기 중에는 없다),
  시작·재개는 `DSColor.positive`, 일시정지는 `DSColor.negativeSoft`(주황).
- **가운데는 전체 남은 시간 한 줄뿐이다.** "지금 구간이 얼마 남았나"는 원 아래 리스트가 답한다.
- **SectionCountdownList** (`Rereminder/Views/Components/SectionCountdownList.swift`):
  45분을 20+25로 나눴다면 앞의 20:00 만 줄고 25:00 은 제자리에 서 있다가 경계를 지나면
  줄기 시작한다. 색은 링의 구간 색(`SectionPalette`)과 같고 **지금 구간만 100%**.
  남은 시간 계산은 `TimerSections.remainingSeconds` 하나만 쓴다.
  알림이 하나뿐이라 구간이 하나면 대신 `nextAlertInfo` 한 줄이 선다(둘 다 두면 같은 말이 두 번).
- **SectionInnerRing 은 워치 전용으로 남아 있다** — 워치는 화면이 좁아 리스트를 세울 자리가
  없어서 안쪽 링이 그 역할을 한다. iPhone 에서 안 쓴다고 지우지 말 것.

### 온보딩 — 읽는 안내가 아니라 해 보는 안내
`OnboardingFlowView` (2.1.2에서 갈아엎음). 흐름은 **환영 → 어디에 쓸 건가요 → 60배속 체험 →
템플릿 저장 → 기기 안내** 다섯 장.

- **상황을 먼저 고르게 한다**(`OnboardingUseCase`: 발표·수업·워크숍·운동·집중·회의·아직 모르겠어요).
  "끝나기 전에 여러 번 알려 준다"가 왜 좋은지는 자기 상황에 대입해야 안다. 고른 상황의
  추천 설정은 **알림이 두 개 이상**이 되게 잡는다 — 하나짜리는 체험에서 보여 줄 것이 없다.
- ⚠️ **이 목록이 곧 "이 앱은 누구 것인가"의 선언이다.** 처음 연 사람은 여기서 자기를 찾고,
  못 찾으면 자기 앱이 아니라고 결론 내린다. 그래서 **돈을 내는 사람**(남 앞에서 시간을 운영하는
  사람 — 발표자·강사·퍼실리테이터)을 맨 위 셋에 둔다.
- ⚠️ **요리는 뺐다 — 되살리지 말 것.** "헤이 시리, 8분 타이머"를 이길 수 없는 싸움이고, 그 카드를
  고른 사람은 이틀 뒤 앱을 지운다. 이기지 못하는 상황으로 신규 사용자를 안내하는 건 획득이
  아니라 이탈 비용이다(`OnboardingDemoTests` 가 지킨다).
- ⚠️ **구간 이름 수 = 알림 수 + 1.** 구간은 알림 경계에서 파생되므로 어긋나면 이름이 조용히
  빠지거나 엉뚱한 구간에 붙는다. 길이는 다이얼 상한(`TimeMapper.maxMinutes`, 120분) 안이어야 한다.
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

### 원 아래 영역 — 하나의 묶음
원 아래 조각들(구간 길이 칩·기기 연결·템플릿 바/구간 리스트)은 **하나의 `VStack` 으로 묶여**
간격과 좌우 여백을 `TimerMainView` 한 곳에서 받는다. 예전에는 조각마다 제 여백(`spacing * 2` 등)을
갖고 떠 있어서 어떤 건 링에 달라붙고 어떤 건 한참 떨어져, 화면 아래 절반이 "정렬되지 않은 칩
무더기"로 보였다.

- ⚠️ 링과 구간 칩 사이 여백은 **고정값**(`DSSpacing.xxxl`)이다. 화면 높이 비례로 두면 작은
  기기에서 칩이 링에 달라붙어 링의 일부처럼 보인다.
- ⚠️ `DeviceLinkChips` 에 **채운 캡슐을 다시 씌우지 말 것.** 회색 캡슐 두 개가 각각 "연결 안 됨"을
  외치던 시절, 화면 아래 절반에서 **가장 눈에 띄는 것이 실패 문구**였다. 상태 표시지 버튼이 아니다.
- `TemplateQuickBar` 의 버튼 위계 — 초기화는 **아이콘만**(원형), 저장만 채운 캡슐.
  글자를 둘 다 달면 무엇이 주된 행동인지 흐려지고, 아이콘만이라 예전의 글자 잘림 문제도 사라졌다.

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
- **SectionInnerRing** (`Shared/DesignSystem/SectionInnerRing.swift`): **워치 전용**.
  iPhone 은 링 한 겹 + 원 아래 리스트로 돌아갔다 — 지우지 말 것(워치가 쓴다)
- **TimerButtonStyle** (`Rereminder/Views/Components/TimerButtonStyle.swift`): 원 안의 동그란
  동작 버튼 모양
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
  - **웹 페이지 넷은 기기 언어를 보고 한국어·영어를 고른다**(`web/index.html`,
    `docs/index.html`·`support.html`·`privacy.html`). `navigator.languages` 를 훑어
    `ko` 로 시작하는 태그가 있으면 한국어이고, 오른쪽 위 버튼으로 바꿀 수 있다.
    ⚠️ **저장 키는 네 페이지가 모두 `rereminder-lang` 이어야 한다** — 다르면 소개 페이지에서
    고른 언어가 지원·개인정보 페이지로 이어지지 않는다(예전에 `docs/index.html` 만 `lang` 을
    써서 실제로 끊겨 있었다). ⚠️ **자동 감지 결과는 저장하지 않는다** — 저장하면 기기 언어를
    바꿔도 첫 방문에 감지한 언어가 계속 따라온다. 자세한 건 `web/README.md` 참고.
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

### 확인할 때까지 알림
- [ ] 설정 > 알림 > 타이머가 끝나면에서 반복을 켜고, 타이머가 끝난 뒤 계속 울리는지
- [ ] 알림을 길게 눌러 **정지**를 누르면 그 뒤로 안 울리는지
- [ ] **다시 알림**을 누르면 5분 뒤에 다시 오는지
- [ ] 알림을 그냥 탭해 앱을 열어도 멈추는지 (열었는데 계속 울리면 고장으로 읽힌다)
- [ ] 되풀이가 우는 동안 **앱을 직접 열면** 확인(✓) 화면이 뜨는지
- [ ] 워치에서 타이머를 걸고 확인하지 않으면 30초 뒤 iPhone 도 울리는지
- [ ] 한쪽에서 정지하면 **다른 기기도** 멈추는지 (핵심 약속)
- [ ] 반복을 끈 상태(기본값)에서는 예전처럼 한 번만 울리는지

### 워치 실행 화면 (둥근 사각 링)
- [ ] 40mm 에서 아래 버튼이 잘리지 않는지
- [ ] 상태 줄이 시스템 시계와 겹치지 않는지
- [ ] 알림 종(주황 점)이 링 위 제자리에 찍히는지 (호 끝과 어긋나면 안 된다)
- [ ] 끝나면 00:00 + 확인 버튼 하나로 바뀌는지 (음수 시간이 뜨면 안 된다)

### 워치 cold launch 복원
- [ ] 타이머를 걸고 앱을 완전히 종료 → 다시 열면 **지나간 만큼 줄어든 상태로** 이어지는지
      (30:00 으로 되감기면 `start()` 가드가 빠진 것)
- [ ] 그 화면에서 정지(✕)를 누르면 화면이 닫히고 설정으로 돌아오는지
- [ ] 일시정지한 채로 종료 → 다시 열면 멈춘 그대로이고, 재개하면 꺼져 있던 시간이 빠지는지
- [ ] 타이머가 끝난 뒤 열면 설정 화면으로 돌아오는지(음수 시간이 뜨면 안 된다)

### 워치 스마트 스택 위젯
- [ ] 스마트 스택 편집(화면 아래에서 위로 쓸어올림 → 길게 누름 → +)에 두번알림이 뜨는지
- [ ] 실행 중 카드의 남은 시간·"다음" 알림이 **앱 화면과 같은 값**인지
- [ ] 일시정지하면 카드 숫자가 멈추는지 (흘러가면 `endDate` 가 nil 이 아니라는 뜻)
- [ ] 앱을 완전히 종료해도 카드가 계속 정확한지 (시작 시각으로 세므로 정확해야 한다)
- [ ] 타이머를 정지하면 카드가 "활성 타이머 없음"으로 돌아오는지 (유령 카드 확인)
- [ ] 워치 페이스 컴플리케이션(원형·한 줄·모서리)에도 붙는지

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

### 릴리즈 노트 작성 규칙
파일 이름은 `docs/release-notes-<버전>-<언어>.md` — **언어마다 파일 하나**다.
(예: `release-notes-2.2.2-ko.md` · `-en.md` · `-ja.md`)

- ⚠️ **지원하는 언어를 전부 쓴다.** 지금은 `ko`·`en`·`ja` 셋이다
  (`knownRegions` 와 `Localizable.xcstrings` 의 언어와 같다). 언어가 늘면 파일도 는다.
  한 언어라도 빠지면 그 지역 사용자는 App Store 에서 영어 원문을 보게 된다.
- ⚠️ **특수기호를 넣지 않는다.** App Store Connect 의 릴리즈 노트 칸은 **평문**이라
  `**굵게**` 는 별표가 그대로 보이고 `—`·`·`·`→`·`›` 같은 기호도 그대로 나간다.
  마침표와 쉼표만으로 쓴다.
- ⚠️ **최대한 간결하게.** 사용자는 이 칸을 스크롤하지 않는다. 한 항목은 한두 문장이고,
  **왜 그렇게 했는지는 길게 적지 않는다** — 그 설명은 이 문서(CLAUDE.md)의 몫이다.
- 한 릴리즈에 파일이 세 벌이므로 내용이 바뀌면 **세 벌을 함께** 고친다.
- ⚠️ 2.2.1 이하의 옛 노트는 **한 파일에 세 언어를 담은 옛 형식**이다(문단도 길다).
  그건 그대로 두고, 새로 쓰는 것만 이 규칙을 따른다.

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

### v2.2.3 (2026-09-02)
**"템플릿이 저장되지 않는다"는 제보를 따라가 보니 저장 자체가 깨져 있었다.** 원인 두 개:

- **SwiftData 스토어가 아예 로드되지 않았다** — `.modelContainer(for:)` 의 기본값이 CloudKit
  자동 동기화라, 피드백 허브용 iCloud 엔타이틀먼트(2026-07-19, `c86bc7a`)가 붙은 뒤로
  `Timer`·`TimerRecord` 가 CloudKit 스키마 규칙에 걸려 스토어가 통째로 열리지 않았다.
  **템플릿도 기록도 하나도 저장되지 않았고**, 화면에는 아무 오류도 뜨지 않았다
  → `RereminderApp.sharedModelContainer`(앱 그룹 경로 유지 + `cloudKitDatabase: .none`).
  자세한 건 위 "저장소 (SwiftData)" 절
- **무료 사용자의 템플릿이 지워지고 있었다** — "저장은 Pro"를 한도 0 으로 구현해서, 타이머를
  한 번 시작하면(`applyCurrentSettings` → `saveIfNeeded`) 정리 루프가 시드 템플릿까지 전부
  삭제했다. 판정을 `saveIfNeeded` 첫 줄로 올려 무료는 저장도 삭제도 하지 않는다
- 중복 판정을 맨 앞 하나가 아니라 **전체 템플릿** + 정규화된 오프셋 기준으로 바꿨다
  (순서만 다른 같은 설정이 매번 새 칩으로 쌓이던 문제)
- "저장됨" 토스트는 실제로 저장됐을 때만 뜬다(`saveIfNeeded` 가 결과를 돌려준다)
- 테스트 `RereminderTests/TemplateSaveTests.swift` 5개 추가 — 그중 하나는 **앱이 실제로 쓰는
  컨테이너**가 열리는지 보고, 메모리 폴백으로 떨어지지 않았는지까지 확인한다
- 릴리즈 노트: `docs/release-notes-2.2.3-{ko,en,ja}.md`

### v2.2.2 (2026-09-01)
⚠️ **원래 2.3.0 으로 준비하던 릴리즈다.** 코드는 그대로 두고 **번호만 2.2.2 로** 정했다.
그래서 아래에는 가격 축 개편(옛 2.3.0)과 워치 작업이 **한 릴리즈로** 들어 있고, 릴리즈 노트도
언어별로 `docs/release-notes-2.2.2-ko.md`·`-en.md`·`-ja.md` 세 벌이다
(옛 `release-notes-2.3.0.md` 는 여기 합치고 지웠다).
⚠️ 마지막 태그는 여전히 `v2.2.1` 이다 — 2.3.0 은 태그도 출시도 없이 main 까지만 갔다.

- **워치 스마트 스택 위젯**(`RereminderWatchWidget/`, 새 타겟 `RereminderWatchWidgetExtension`):
  손목에서 앱을 열지 않고 남은 시간·다음 알림을 본다. 워치 페이스 컴플리케이션 네 가족에도 붙는다.
  ⚠️ 아이폰 위젯을 아무리 고쳐도 손목에는 안 나온다 — 스마트 스택에는 워치 앱의 확장만 올라간다
  (그래서 지금까지 아예 목록에 없었다). 상태는 앱 그룹으로 넘긴다(`WatchTimerState`).
  **배포 전 앱 그룹 서명 준비 필요** — `docs/OPERATIONS_CHECKLIST.md` 5번
- **워치 실행 화면을 둥근 사각 링으로**(`RoundedRectRing`): 화면이 둥근 사각형인데 원을 그려
  네 모서리가 남았고, 40mm 에서는 **아래 버튼이 화면 밖으로 잘려** 있었다. 링을 테두리로
  밀어내고 가운데를 통째로 쓴다. `SectionInnerRing`(원형 이중 링)은 이제 쓰이지 않는다
- **확인할 때까지 알림**(`EscalatingAlert` + 설정 > 알림 > 타이머가 끝나면): 종료 알림을
  15/30/60초 간격으로 1·2·5분 동안 되풀이하고, 정지·다시 알림을 누르면 멈춘다.
  **기기 사이로 번지기** — 워치가 먼저, 30초 뒤 아이폰이 합류, **어디서 눌러도 전부 멈춘다**.
  기본값은 꺼짐. ⚠️ 알림 예약 64개 상한 때문에 `maxAlerts`(24) 로 뚜껑을 씌웠다
- **`AlertNotificationDelegate` 신설** — ⚠️ 2.2.2 까지 이 앱에는 iOS 알림 델리게이트가 **아예
  없었다.** 그래서 알림 버튼을 눌러도 앱에 아무것도 전달되지 않았다
- **버그 수정 셋**: ① 워치 cold launch 복원이 `start()` 로 `startDate` 를 덮어써 **타이머가
  처음부터 다시 시작**하던 문제(+ 복원 화면에서 정지를 눌러도 닫히지 않던 문제)
  ② 워치의 종료·예비 알림 문구가 영어 리터럴이라 되풀이를 켜면 첫 알림만 영어로 뜨던 문제
  ③ `"Time is up"` 의 한국어가 **"총 시간"** 으로 오역돼 있던 것(iOS `TimerAlertView` 도 같이 틀렸다)

- **파는 축을 "알림 개수"에서 "세션 운영"으로 옮겼다.** 예비 알림은 **무제한 무료**가 됐고
  (`freePrealertLimit`·`unlimitedPrealerts`·`PrealertGrace` 삭제 — 되살리지 말 것),
  Pro 가 파는 한 문장은 **"앱이 당신의 설정을 기억한다"**(`ProGate.canRememberSetup`)로 통일했다.
  기본 시계 앱 대신 설치될 이유 하나를 개수로 세면 무료 사용자가 쥔 것은 기능적으로 기본 타이머다
- **템플릿 개수 한도(3개)·체험(5+5) 삭제** — 저장·불러오기 자체가 Pro. 기억은 쌓여야 값이
  나오는데 체험이 끝나면 쌓인 것이 사라진다. 무료는 **콜드 런치에만** 다이얼이 기본값으로
  돌아오고(백그라운드 복귀는 아니다 — 그건 고장으로 읽힌다), 저장해 둔 템플릿은 잠긴 채로 남는다
- **"발표 모드" → "세션 모드"**(표시 문구만). 강사·퍼실리테이터가 주 사용자인데 그 이름을
  자기 것으로 읽지 않았다. ⚠️ 코드 식별자(`presentationMode`)는 지표 계약이라 그대로
- **창단 후원자**(`FoundingSupporter` + `FounderWelcomeView`/`FounderBadge`): 축이 바뀌고 가격이
  오르기 전에 산 사람에게 "앞으로 생기는 유료 기능은 전부 무료"를 약속한다. 경계는 출시 날짜
  상수가 아니라 **이 버전의 첫 실행 시각**(심사로 밀리는 것은 출시일이지 상수가 아니다).
  Keychain+UserDefaults 두 벌, 재설치·복원해도 자격이 살아 돌아온다. 테스트 20개
- **다음 자리 예약**(`NextOccasionReminder` + `NextOccasionSheet`): 학회 발표·분기 워크숍처럼
  주기가 긴 사용자는 `RepeatDetector`(주 단위)로 못 잡는다. 세션 완주 직후 날짜 하나만 받아
  **전날 저녁 19시**에 부른다. 잔소리 방지 네 겹, 테스트 11개
- **온보딩 상황 목록 재편**: 수업·워크숍 추가, **요리 제거**(시리를 이길 수 없는 싸움).
  돈을 내는 사람(발표자·강사·퍼실리테이터)을 맨 위 셋에 둔다
- **원 아래 영역을 하나의 묶음으로**: 조각마다 갖고 있던 여백을 걷고 간격·좌우 여백을
  `TimerMainView` 한 곳에서 준다. `DeviceLinkChips` 의 채운 캡슐 제거(화면에서 가장 눈에 띄는
  것이 "연결 안 됨"이었다), `TemplateQuickBar` 위계 정리(초기화=아이콘 원형, 저장=채운 캡슐)
- **지표**: 새 이벤트 `next_occasion_booked`·`founder_welcome_shown`(둘 다 payload 없음),
  새 스냅샷 키 `trial.presentation`·`flag.presentationTrialExtended`.
  옛 키(`trial.prealerts`·`alertLimitHits`·`graceGrants`)는 **늘지 않지만 이름을 재활용하지
  않고 남겨 둔다** — 재활용하면 예전 값과 합산돼 지표가 조용히 틀어진다.
  임계값(`heavyAlertThreshold` 3·`multiAlertThreshold` 2·`templateUserThreshold` 1)은 고정
- **l10n 수정**: 시간대 제안 문구가 **키에도 위치지정 서식**으로 적혀 있어 번역이 있는데도
  영어 원문이 나가던 문제(이 카탈로그의 규칙은 키=비위치지정, 값=위치지정)
- 테스트 240 → 289개(이번에 `RoundedRectRingTests` 9 · `EscalatingAlertTests` 12 ·
  `WatchTimerStateTests` 15 추가), 릴리즈 노트: `docs/release-notes-2.2.2-{ko,en,ja}.md`

### v2.2.1 (2026-08-23)
- **타이머 모양 선택 철회** — 2.2.0에서 넣은 원형 링/이중 링/구간 막대/접은 줄과 이중 링·원 밖
  버튼 바를 전부 걷어내고 **링 한 겹 + 원 안 버튼 + 원 아래 구간 카운트다운**(2.1.1 화면)으로
  되돌렸다. 같은 시간을 두 군데에 그리면 볼 때마다 어느 쪽이 무엇인지 고르게 된다
- **구간 목록에 길이 비례 막대**: 4분/8분/8분 → 폭 1:2:2, 오른쪽 정렬로 함께 줄어든다
  (`SectionCountdownList.trackWidth`/`fillRatio`, 테스트 7개)
- **대기 중 구간 길이**(`SectionLengthBar`): 걸기 전에도 각 구간이 몇 분인지 보인다
- **무료 알림 한도 1 → 2** + **막힌 자리에 하루 한 번 유예**(`PrealertGrace`) —
  가치를 경험하기 전에 벽을 만나면 결제가 아니라 이탈이 된다
- **반복 감지**(`RepeatDetector`): 같은 설정을 **서로 다른 날 2일 이상** 걸면 저장을 먼저 제안.
  한 설정에 한 번, 전체 3회 상한, 다른 안내에 양보
- **측정**: "알림이 실제로 울린 채로 끝까지 간 완주"(`alertedCompletions`)를 따로 세고,
  알림 개수 분포를 **결제 여부로 가른다**(`UsageInsights.PlanFilter`) — 무료 분포는 한도에
  눌린 값이라 그것만 보면 한도 판단이 통째로 틀어진다
- **라이브 액티비티 수정 둘**: ① 다이나믹 아일랜드 버튼이 **아무 일도 하지 않던 문제** —
  `LiveActivityIntent` 는 앱 프로세스에서 도는데 인텐트가 확장 타겟에만 있었다.
  ② 앱과 같은 색 체계(`SharedAccent` 로 테마 강조색 전달) + 카운트다운이 "8 minutes" 로
  뭉뚱그려지던 것을 `Text(timerInterval:countsDown:)` 로 교정
- **`LocalDay` 신설**: 날짜를 UTC 로 세면 한국에서는 **오전 9시에 하루가 바뀐다**
- 테스트 202 → 222개, 릴리즈 노트: `docs/release-notes-2.2.1.md` (ko/en/ja)

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

**최종 업데이트**: 2026-09-01
**문서 버전**: 2.2.2
**작성자**: Claude AI Assistant
