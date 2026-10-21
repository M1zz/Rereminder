# 피처링 추천 (Featuring Nominations)

App Store Connect ▸ 앱 ▸ **Featuring** ▸ **Nominations** ▸ (+) 에 넣는 글이다.
DeployBar 는 이 칸을 올리지 못하므로 사람이 아래 영어 블록을 칸마다 그대로 붙여 넣는다.

작성일 2026-10-21 · 기준 버전: 스토어 2.3.3(2026-10-17 출시), 다음 출시분 = 2.3.4 노트 + `76021b0`(선물·팁·무료 한도 안내)

## 확인한 규칙 (공식 문서)

- 출처: https://developer.apple.com/app-store/getting-featured/ ,
  App Store Connect 도움말 "Nominate your app for featuring"
  (https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring)
- 추천 유형: **New Content** (새 콘텐츠·제안·이벤트) / **App Enhancements** (새 기능·큰 업데이트) /
  **App Launch** (새 앱 출시·사전 주문). 하나 이상 고를 수 있고, **제출한 뒤에는 유형과 관련 앱을 바꿀 수 없다.**
- 칸: Nomination name, Type, Description, Publish date(하루 또는 기간), Platforms, Relevant Countries or Regions,
  Localizations, In-App Events(승인됐거나 게시된 이벤트만 붙일 수 있음), Supplemental Materials(URL 최대 5개),
  Helpful Details. **글자 수 한도는 공식 문서에 없다.** 그래도 에디터가 읽기 쉽게 짧게 썼다.
- 시기: getting-featured 페이지는 "최소 2주 전, 넓게 보려면 최대 3개월 전". 도움말은
  **"최소 3주 전"**을 권한다. 더 엄격한 쪽(3주)에 맞췄다. 오늘(2026-10-21) 기준 3개월 끝 = 2027-01-21.
- 플랫폼: 인앱 이벤트는 iPhone·iPad 에서만 보인다.
- 날짜는 넣는 사람 기기의 시간대 기준이다.
- 에디터가 보는 점: 사용자 경험, UI 디자인, 혁신, 독창성, **접근성**, **현지화**, 제품 페이지 품질(평점 포함).
- 넣는 권한: Account Holder, Admin, App Manager, Marketing.

## 한눈에

| # | 유형 | 이름 | 게시 희망 | 늦어도 낼 날 | 붙일 인앱 이벤트 |
|---|---|---|---|---|---|
| 1 | App Enhancements | Rereminder 2.3.4: Gift Pro, My Benefits and Voice Control | 2026-11-18 ~ 2026-11-30 | **2026-10-28** | `gift-update` |
| 2 | New Content | Rereminder: Holiday Gift Season | 2026-12-15 ~ 2027-01-10 | 2026-11-24 | `holiday-gift` |
| 3 | App Enhancements | Rereminder: Now in 24 Languages, Built for Speakers and Instructors | 2027-01-06 ~ 2027-01-20 | 2026-12-16 | `talk-season` |

⚠️ 1번은 **2.3.4 가 2026-11-14 무렵까지 스토어에 나가 있어야** 성립한다(선물·팁 상품도 App Store Connect 에서 승인돼야
줄이 보인다 — `GiftAndTipSection.swift` 는 상품을 못 불러오면 줄을 숨긴다). 출시가 밀리면 게시 희망일을 같이 민다.

---

## 1. App Enhancements — 2.3.4 업데이트

**한국어 요약**: 다음 업데이트에 들어가는 Pro 선물하기, 코드 사용, 내 혜택 화면, 음성 제어·색 없이 구분·투명도 줄이기
같은 접근성 개선, 설정의 '앞으로 만들 기능'을 묶어 알린다. 무료로 쓰는 핵심(끝나기 전 여러 번 알림, Apple Watch, Mac)은
그대로 무료라는 점을 함께 말한다.

**근거(코드·커밋)**
- Pro 선물: `76021b0` — `RereminderSpec.giftConfig`, `Rereminder/Views/Components/GiftAndTipSection.swift` (설정에 보내기·받기 줄, 코드로 받음)
- 팁(응원): `76021b0` — `RereminderSpec.tipJarConfig`, `TipAskLine.swift`
- 내 혜택·코드 사용: `581d541` — `ProBenefitsView.swift`, `.offerCodeRedemption`
- 접근성: `0782f0c` — 음성 제어 입력 이름(`accessibilityInputLabels`), 색 없이 구분 시 체크 표시, 투명도 줄이기, 동작 줄이기 존중, 대비 수정
- 앞으로 만들 기능·업데이트 후 새 기능 안내: `52d2a1a`, `6fa5ff1` — `RereminderRoadmap.swift`, `WhatsNewView`
- UI 시험(핵심 흐름 + 접근성 감사): `3ffbdcb`

**Nomination name**
```
Rereminder 2.3.4: Gift Pro, My Benefits and Voice Control
```

**Nomination type**: App Enhancements

**Description**
```
Rereminder is a countdown timer for people who cannot afford to run over: speakers, teachers, meeting hosts and fitness instructors. Instead of one alarm at zero, it warns you several times before the end (for example 10, 5 and 1 minute left), so you can wrap up on time instead of being cut off.

Version 2.3.4 focuses on making the app easier to share and easier to use for everyone:

- Gift Pro: buy Pro for a colleague and send them a code. They redeem it in Settings and keep Pro permanently. Speakers and instructors tend to find this app through other speakers, so we built the gift around that.
- My Benefits: people who bought Remember or Pro now see exactly what their purchase unlocks and how much they have used it.
- Redeem codes inside the app, without leaving for the App Store.
- Accessibility: every main button has Voice Control names, active alerts are marked with a checkmark when Differentiate Without Color is on, translucent backgrounds turn solid with Reduce Transparency, and the rolling time digits respect Reduce Motion. We also added an automated accessibility audit to our UI tests.
- A "Coming next" page in Settings shows what we are building, and a short What's New screen appears once after each update.

What stays free: unlimited pre-alerts, the full Apple Watch app with Smart Stack widgets, Live Activities and the Dynamic Island, and the Mac app. Pro is a one-time purchase, never a subscription, and the app has no ads.

Priority: this is our most important update this quarter.
```

**Publish date**: Range — 2026-11-18 ~ 2026-11-30

**Platforms**: iOS (iPhone). (watchOS 앱도 함께 있으나 이 업데이트의 새 기능은 iPhone 쪽이다)

**Relevant Countries or Regions**: 기본값(앱이 나가는 모든 나라)을 그대로 둔다.
특히 중요한 곳으로 Helpful Details 에 United States, United Kingdom, Canada, Australia, Germany, Japan, Korea 를 적는다.

**Localizations**: 기본값(24개 전부) 그대로.

**In-App Events**: `gift-update` (IN_APP_EVENTS.md) — 승인되면 바로 붙인다.

**Supplemental Materials** (최대 5개)
```
https://apps.apple.com/us/app/rereminder/id6752551268
https://m1zz.github.io/Rereminder/en/
https://m1zz.github.io/Rereminder/en/support.html
```
(TestFlight 공개 링크가 있으면 넷째 칸에 넣는다 — 레포에서 확인하지 못했다)

**Helpful Details**
```
Made by Leeo, an independent developer in Korea. The app is fully localized in 24 languages, including store pages, release notes and support pages. Accessibility work in this release: Voice Control input labels on all main controls, Differentiate Without Color, Reduce Transparency and Reduce Motion support, and contrast fixes found by an automated accessibility audit. Key regions: United States, United Kingdom, Canada, Australia, Germany, Japan, Korea.
```

---

## 2. New Content — 연말 선물 시즌

**한국어 요약**: 연말(12/15~1/10)에 동료 발표자·강사에게 Pro 를 선물하는 흐름을 알린다. 인앱 이벤트 `holiday-gift` 와 짝이다.
가격 할인이 아니라 **선물이라는 새 상품**이 알맹이다(Apple 은 내용 없는 가격 행사를 받지 않는다).

**근거**: `76021b0` — 소모성 상품 `com.xa.toki.gift.pro` 가 받는 사람에게 `com.xa.toki.pro` 를 연다. 받은 코드는 설정 ▸ 받기 줄에서 넣는다.

**Nomination name**
```
Rereminder: Holiday Gift Season
```

**Nomination type**: New Content

**Description**
```
From December 15 to January 10, Rereminder is running a Holiday Gift Season in-app event built around a new way to share the app: Gift Pro.

Rereminder is a countdown timer that warns you several times before time runs out, used by speakers, teachers, workshop hosts and fitness instructors. It spreads the way good tools do among teachers and speakers: someone notices a colleague's wrist tap quietly five minutes before the end of a class and asks what app that is.

With Gift Pro, anyone can buy Pro for a fellow speaker or teacher and send it as a code. The recipient redeems it in Settings and keeps Pro permanently: saved setups, Session Mode with per-part notes that open on cue, overtime tracking and history. The year-end season, when talks, recitals, school terms and team reviews pile up, is when this gift is most useful.

The event card and details page show the real app: the dial with alert bells and the running countdown. Pro is a one-time purchase, never a subscription, and the app has no ads.
```

**Publish date**: Range — 2026-12-15 ~ 2027-01-10

**Platforms**: iOS (iPhone)

**Relevant Countries or Regions**: 전체. Helpful Details 에 연말 선물 문화가 강한 United States, United Kingdom, Germany, France, Japan 을 적는다.

**Localizations**: 24개 전부.

**In-App Events**: `holiday-gift`

**Supplemental Materials**
```
https://apps.apple.com/us/app/rereminder/id6752551268
https://m1zz.github.io/Rereminder/en/
```

**Helpful Details**
```
Independent developer (Leeo, Korea). The gift flow and its event copy are localized in all 24 of the app's languages. The sender gets a code and the recipient enters it in Settings. Key regions: United States, United Kingdom, Germany, France, Japan.
```

---

## 3. App Enhancements — 24개 언어 + 발표자·강사를 위한 세션 모드

**한국어 요약**: 2.3.2(2026-10)에서 11개 → 24개 언어로 늘린 것과, 발표·수업을 구간으로 나눠 구간마다 메모가 차례에 맞춰
펼쳐지는 세션 모드, AlarmKit 알람, Apple Watch 스마트 스택을 묶어 "새해 발표·학회 시즌" 기사 거리로 낸다.
에디터가 보는 '현지화'·'독창성' 항목을 노린다. 인앱 이벤트 `talk-season` 과 짝.

**근거**: `3281024`(13개 언어 추가 → 24개), `1546e29`(새 로케일 스크린샷·워치·헤더 그림), 세션 모드·구간 대본(`PresentationScriptPanel`, CLAUDE.md "발표 구간 대본"),
AlarmKit(`RereminderAlarmManager.swift`), 확인할 때까지 알림(`EscalatingAlert.swift`), 워치 스마트 스택(`RereminderWatchWidget/`).

**Nomination name**
```
Rereminder: Now in 24 Languages, Built for Speakers and Instructors
```

**Nomination type**: App Enhancements

**Description**
```
Rereminder now speaks 24 languages, from Thai and Vietnamese to Polish, Greek and Turkish. Every language has its own store page, screenshots, Apple Watch screenshots, release notes and support pages, written to read naturally in each language.

The app solves one problem that ordinary timers do not: a timer that only rings at zero is too late for a speaker. Rereminder warns you several times before the end, on the alerts you place yourself by dragging bells around the dial.

Features we would love to show to people preparing for the new year of talks, classes and conferences:
- Session Mode: split a talk or class into named parts (intro, main talk, Q&A) and write what to say in each. When a part begins, its notes open on screen by themselves.
- A real alarm at the end: with AlarmKit, the final alert can ring like an alarm, even in Silent Mode or a Focus, until you stop it.
- Alerts that repeat until you acknowledge them, starting on Apple Watch and joining on iPhone 30 seconds later.
- A full Apple Watch app with Smart Stack widgets and complications that show the time left and the time until the next alert.
- Live Activities and the Dynamic Island, Siri and Shortcuts, and a Mac app.

Pre-alerts are unlimited and free. Pro is a one-time purchase that remembers your setups.
```

**Publish date**: Range — 2027-01-06 ~ 2027-01-20 (3개월 창 끝 2027-01-21 안)

**Platforms**: iOS (iPhone), watchOS

**Relevant Countries or Regions**: 전체. Helpful Details 에 새로 늘린 언어권(체코·덴마크·그리스·핀란드·인도네시아·노르웨이·네덜란드·폴란드·러시아·스웨덴·태국·튀르키예·베트남)과 일본·독일을 적는다.

**Localizations**: 24개 전부.

**In-App Events**: `talk-season`

**Supplemental Materials**
```
https://apps.apple.com/us/app/rereminder/id6752551268
https://m1zz.github.io/Rereminder/en/
https://m1zz.github.io/Rereminder/ja/
https://m1zz.github.io/Rereminder/de/
```

**Helpful Details**
```
Independent developer (Leeo, Korea). Languages: Korean, English, Japanese, Simplified and Traditional Chinese, German, French, Spanish, Brazilian and European Portuguese, Italian, Russian, Czech, Danish, Greek, Finnish, Indonesian, Norwegian, Dutch, Polish, Swedish, Thai, Turkish and Vietnamese. Accessibility: Voice Control labels, Differentiate Without Color, Reduce Transparency and Reduce Motion support.
```

---

## 쓰지 않은 것과 그 이유

- **App Clip**: 스토어 옛 릴리즈 노트에는 나오지만 2026-09-05 부터 앱에 임베드하지 않는 상태다(CLAUDE.md "App Clip" 절). 되살리기 전에는 쓰지 않는다.
- **접히는 iPhone(듀오) 화면**: `b1a9b10` 에 있으나 Xcode 27.1 로 빌드해야 켜지고 실기기 확인 전이다. 출시 빌드에서 켜진 것을 확인한 뒤 4번째 추천 거리로 쓴다.
- **Mac 메뉴 막대**: 스토어 페이지에는 "Mac: macOS 26.0 이상, Apple M1 이상"이 보이지만, 메뉴 막대는 Mac Catalyst 빌드에서만 들어간다.
  지금 맥에 나가는 것이 Catalyst 앱인지 아이폰 앱 호환 실행인지 App Store Connect 에서 확인하기 전에는 "메뉴 막대"를 추천 글에 넣지 않았다(본문의 "a Mac app" 까지만).
- **가격 할인**: 지금 앱 안에 걸린 할인이 없다. 없는 할인을 이벤트나 추천으로 만들지 않는다.
