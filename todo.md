# Rereminder 작업 메모

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
- [ ] Apple CDN 반영 대기 후 재확인 (캐시라 수 시간 걸릴 수 있음):
      `curl https://app-site-association.cdn-apple.com/a/v1/m1zz.github.io`
      → `com.xa.toki.Clip` 이 나오면 완료
- [ ] **실기기**: 임시 알림 권한(8시간)으로 백그라운드 알림이 실제로 오는지
- [ ] 원 확대 후 다이얼·종 드래그 손으로 재확인 (시뮬레이터 자동 입력이 먹통이라 미검증)
- [x] **버전 2.0.5 + 중앙 관리 정상화** — 전 타겟이 `Config/Version.xcconfig` 하나만 읽음
      (아카이브 산출물 4종 모두 2.0.5 build 1 확인)
- [x] App Clip 카드 헤더 이미지 `web/appclip-card-1800x1200.png` (생성 스크립트 동봉)
- [ ] TestFlight 업로드 전 빌드 번호 올리기: `./scripts/update_version.sh --build-only`
- [ ] Distribution 인증서 발급 (현재 Apple Development 만 보유)
- [ ] App Store Connect: 빌드 업로드 → App Clip 경험 등록
      (헤더 이미지 1800×1200, 부제, 액션 버튼) → 심사 제출 시 App Clip URLs 최대 3개
- [ ] `SKOverlay` 전체 앱 유도 배너 동작 (시뮬레이터에서는 확인 불가)

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
- [x] **Mac Catalyst 활성화** — 기존 iOS 타겟에서 Catalyst on, iOS·Catalyst 양쪽 빌드 성공
- [x] Mac 창 크기 제약 + 타이틀바 정리 (`ContentView.configureMacWindowIfNeeded`)

## Mac 후속 (네이티브 레이어 — 추후)
- [ ] 메뉴바 타이머(`MenuBarExtra`) — Catalyst엔 없어 별도 native 처리 필요
- [ ] 다중 동시 타이머 / 외부 디스플레이 발표 모드 / 전역 단축키
- [ ] CloudKit 동기화(템플릿·히스토리·프리셋·테마)
- [ ] Mac 키보드 커맨드(`.commands`) — 시작/일시정지 ⌘ 단축키

## 확인 필요 (실기기/시뮬레이터)
- [ ] Mac 앱 실행 시 창 크기·동작, Live Activity 미동작은 정상(무시)
- [ ] 발표모드에서 버튼/인디케이터 겹침 해소 확인
- [ ] 페이지 인디케이터 점이 하단 바와 겹치지 않는지
- [ ] 빠른설정 길게 눌러 편집 동작 / 페이지 스와이프와 제스처 충돌 여부
- [ ] 예비알림 추가·삭제 후 영구 저장 확인
- [ ] 한국어/일본어 화면 텍스트 자연스러움 최종 점검

## 미정/논의
- [ ] 커밋 분리 방식 (접근성 / 레이아웃 / 프리셋 / 다국어)
