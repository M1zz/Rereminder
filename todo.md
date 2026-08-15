# Rereminder 작업 메모

## 완료 (이번 라운드)
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

## 확인 필요 (실기기/시뮬레이터)
- [ ] Mac 앱 실행 시 창 크기·동작, Live Activity 미동작은 정상(무시)
- [ ] 발표모드에서 버튼/인디케이터 겹침 해소 확인
- [ ] 페이지 인디케이터 점이 하단 바와 겹치지 않는지
- [ ] 빠른설정 길게 눌러 편집 동작 / 페이지 스와이프와 제스처 충돌 여부
- [ ] 예비알림 추가·삭제 후 영구 저장 확인
- [ ] 한국어/일본어 화면 텍스트 자연스러움 최종 점검

## 미정/논의
- [ ] 커밋 분리 방식 (접근성 / 레이아웃 / 프리셋 / 다국어)
