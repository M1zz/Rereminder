# 글로벌 마케팅 1단계 키트

SNS 없이 외국 사용자에게 닿는 길만 쓴다: App Store 피처링 추천, 인앱 이벤트, 영어권 디렉터리·뉴스레터 등록.
DeployBar 는 이것들을 올리지 못하므로, 사람이 App Store Connect 와 각 사이트에 **그대로 붙여 넣을 글**로 만들었다.
작성일 2026-10-21. 이 폴더의 어떤 것도 아직 제출하지 않았다.

## 들어 있는 것

| 파일 | 내용 |
|---|---|
| `FEATURING_NOMINATIONS.md` | 피처링 추천 3건(영어 본문 + 한국어 요약, 게시 희망일, 지역, 근거 커밋) |
| `IN_APP_EVENTS.md` | 인앱 이벤트 3개, 24개 언어 이름·짧은 설명·긴 설명과 글자 수, 그림 목록 |
| `DIRECTORIES.md` | Apptisan · AlternativeTo · Product Hunt 양식 초안, 발표자·강사 대상 메일 초안 |
| `events/copy.json` | 인앱 이벤트 문구 원본(표는 여기서 만든다) |
| `events/count_chars.py` | 글자 수·한글 섞임 검사. `python3 -I marketing/global/events/count_chars.py` (`--md` 면 표 출력) |
| `events/make_images.py` | `docs/screenshots/raw` 에서 이벤트 그림을 다시 만든다 |
| `events/common/` | 선물 이벤트 둘이 쓰는 카드(1920×1080)·상세(1080×1920) 그림, 언어 공통 |
| `events/talk-season/<로케일>/` | 발표 시즌 이벤트 그림, 24개 언어 각각 |

## 사람이 할 일 (순서대로)

1. **2026-10-28 까지** — 피처링 추천 3건을 App Store Connect ▸ 앱 ▸ Featuring ▸ Nominations 에 넣는다
   (`FEATURING_NOMINATIONS.md`). 1번은 게시 희망 11-18 의 3주 전이 10-28 이다. 2·3번도 지금 함께 내 두면 된다.
   ⚠️ 제출하면 유형·관련 앱은 못 바꾼다 — Draft 로 저장해 한 번 읽고 낸다.
2. **같은 주** — App Store Connect 에서 `com.xa.toki.gift.pro`, `com.xa.toki.tip.small/medium/large` 상품을 만들고
   현지화·심사 제출(소모성 4개. `docs/OPERATIONS_CHECKLIST.md` 8번은 기억·업그레이드 상품만 다루고 이 넷은 아직 적혀 있지 않다 — `Config/RereminderProducts.storekit` 이 기준). 상품이 없으면 앱에 선물·응원 줄이 안 보이고 1·2번 이벤트가 성립하지 않는다.
3. **2026-11-14 무렵까지** — 2.3.4 를 DeployBar 로 내보낸다(`76021b0` 의 선물·팁이 그 빌드에 들어가는지 확인).
   ⚠️ 지금 `RELEASE_NOTES.md` 의 2.3.4 절에는 선물·응원 줄이 없다. 같은 빌드로 나가면 노트에 한 줄 더하는 것을 검토한다.
4. **2.3.4 승인 직후** — 인앱 이벤트 `gift-update` 를 만들어 심사에 낸다(`IN_APP_EVENTS.md`, 그림은 `events/common/`).
   승인되면 피처링 추천 1번에 붙인다.
5. **2026-11-24 무렵** — `holiday-gift` 를 만들어 낸다(12-15 시작, 홍보는 12-01부터). 승인되면 추천 2번에 붙인다.
   거절되면 `gift-update` 를 31일(11-18 ~ 12-18)로 늘려 하나로 합친다.
6. **바로** — Apptisan 양식, AlternativeTo 등록(이메일 인증 먼저). `DIRECTORIES.md` 1·2절.
7. **Mac 확인 뒤** — App Store Connect 에서 macOS 플랫폼(Mac Catalyst 앱)이 나가 있는지 본다. 그 결과로 Product Hunt 글의 메뉴 막대 줄을 정하고,
   2.3.4 출시 뒤 첫 화·수요일에 올린다. 갤러리 그림(1270×760) 2장 이상을 먼저 만든다.
8. **12월 중순까지 결정** — `talk-season` 이벤트는 거절 위험이 높다. 기간 한정 새 콘텐츠(예: 발표용 기본 세션 템플릿 묶음)를 앱에 넣을지 정한다.
   넣지 않으면 이벤트는 내지 않고 피처링 추천 3번만 둔다.
9. **언제든** — 발표자·강사 대상 블로그를 찾아 `DIRECTORIES.md` 5절 메일을 보낸다(Pro 코드는 App Store Connect 에서 만든다).

## 사람이 직접 판단·신고해야 하는 것

- 인앱 이벤트의 "인앱 구입 필요" 표시(`IN_APP_EVENTS.md` 표의 값은 제안이다)
- 이벤트 시간대(지역별 현지 시각으로 둘지)
- AlternativeTo 빠른 검토(유료) 여부
- Product Hunt 가격 태그의 정확한 선택지

## 쓰지 않은 것

App Clip(지금 임베드 끊김), 접히는 iPhone 화면(Xcode 27.1 빌드·실기기 확인 전), 할인 행사(지금 걸린 할인이 없다),
MacMenuBar.com(대상 아님). 자세한 이유는 각 문서 끝에 있다.
