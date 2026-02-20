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

**설정 파일**: `Config/Version.xcconfig`

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

### Xcode 설정 (초기 1회)
자세한 설정 방법은 `Config/README.md` 참고

1. 각 타겟의 Build Settings에서:
   - MARKETING_VERSION = $(inherited)
   - CURRENT_PROJECT_VERSION = $(inherited)

2. 프로젝트 Info → Configurations에서 Version.xcconfig 연결

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

### UI Components
- **Clock** (`Rereminder/Views/Components/Clock.swift`): 타이머 시계 UI
- **TimePresetButtons** (`Rereminder/Views/Components/TimePresetButtons.swift`): 시간 프리셋 버튼
- **ToastViewModifier** (`Rereminder/Views/Components/ToastViewModifier.swift`): 토스트 메시지

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

## 빌드 환경
- **Xcode**: 15.0+
- **iOS Deployment Target**: iOS 16.0+
- **watchOS Deployment Target**: watchOS 9.0+
- **Swift Version**: Swift 5.9+

## 의존성
현재 외부 라이브러리 의존성 없음 (네이티브 프레임워크만 사용)

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
