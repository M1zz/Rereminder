# Rereminder (두번알림)

**iOS & Apple Watch용 스마트 타이머**

Rereminder(두번알림)는 원하는 시점마다 알림을 받을 수 있는 타이머 앱입니다.
종료 "10분 전", "5분 전" 같은 사전 알림을 설정할 수 있어, 운동·발표·스터디 등 시간을 세밀하게 관리해야 하는 순간에 유용합니다.

[![App Store](https://img.shields.io/badge/App%20Store-Download-blue?logo=apple&logoColor=white)](https://apps.apple.com/app/id6752551268)

> **랜딩 페이지**: [https://m1zz.github.io/Rereminder](https://m1zz.github.io/Rereminder)

---

## 주요 기능

- **사전 알림(Pre-alerts)** — 타이머 종료 전 원하는 시점에 미리 알림
- **Apple Watch 지원** — Watch 앱에서 독립 실행 및 iOS와 실시간 동기화
- **Live Activity** — 잠금 화면 & Dynamic Island에서 타이머 실시간 확인
- **위젯** — 홈 화면 · 잠금 화면 위젯으로 빠른 타이머 확인
- **Siri & 단축어** — App Intents를 통한 음성 제어
- **Pro 기능** — 테마 커스터마이징, 타이머 히스토리 등

## 기술 스택

- **SwiftUI** + **MVVM** 아키텍처
- **WidgetKit** (홈 화면 / 잠금 화면 위젯)
- **ActivityKit** (Live Activity / Dynamic Island)
- **WatchConnectivity** (iOS ↔ Watch 동기화)
- **StoreKit 2** (인앱 결제)
- **App Intents** (Siri / Shortcuts)
- 외부 라이브러리 없이 네이티브 프레임워크만 사용

## 프로젝트 구조

```
Rereminder/
├── Rereminder/              # iOS 메인 앱 (Views, ViewModels)
├── RereminderWatch/         # Apple Watch 앱
├── RereminderAlarm/         # 위젯 & Live Activity
├── Shared/                  # 공유 모듈 (Models, Modules, Intents)
├── Config/                  # 버전 관리 (Version.xcconfig)
├── scripts/                 # 빌드 스크립트
└── docs/                    # 랜딩 페이지 (GitHub Pages)
```

## 빌드 환경

| 항목 | 요구 사항 |
|------|----------|
| Xcode | 15.0+ |
| iOS | 16.0+ |
| watchOS | 9.0+ |
| Swift | 5.9+ |

## 로컬 빌드

```bash
git clone https://github.com/M1zz/Rereminder.git
cd Rereminder
open Rereminder.xcodeproj
```

외부 의존성이 없으므로 `Xcode`에서 바로 빌드 가능합니다.

---

## 컨트리뷰션 가이드

Rereminder에 기여해주셔서 감사합니다! 아래 순서를 참고해주세요.

### 이슈 작성
- [Issues 탭](https://github.com/M1zz/Rereminder/issues)에서 버그 리포트, 기능 요청, 개선 제안을 자유롭게 작성할 수 있습니다.

### 기여 프로세스

1. 관심 있는 이슈에 댓글로 참여 의사를 표시합니다.
2. 저장소를 **Fork** 합니다.
3. `dev` 브랜치에서 작업 브랜치를 생성합니다.
   ```bash
   git checkout dev && git pull upstream dev
   git checkout -b feature/이슈번호
   ```
4. 개발 후 커밋 & Push 합니다.
5. `dev` 브랜치를 대상으로 **Pull Request**를 생성합니다.

### 브랜치 전략

| 브랜치 | 용도 |
|--------|------|
| `main` | 프로덕션 릴리즈 |
| `dev` | 개발 통합 (PR 대상) |
| `feature/이슈번호` | 새 기능 |
| `fix/이슈번호` | 버그 수정 |
| `refactor/설명` | 리팩토링 |

### 커밋 컨벤션

```
<type>: <한글 설명>
```

| Type | 설명 |
|------|------|
| feat | 새로운 기능 추가 |
| fix | 버그 수정 |
| docs | 문서 수정 |
| style | 코드 포맷팅 (기능 변화 없음) |
| refactor | 코드 구조 개선 |
| test | 테스트 추가/수정 |
| chore | 빌드, 설정 등 유지보수 |

### 코드 스타일

[Apple Developer Academy Swift Style Guide](https://github.com/DeveloperAcademy-POSTECH/swift-style-guide)를 따릅니다.

---

## 라이선스

이 프로젝트의 라이선스는 저장소 내 LICENSE 파일을 확인해주세요.
