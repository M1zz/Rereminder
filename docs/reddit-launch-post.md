# Reddit 런칭 글 — r/apphunt

> 작성일: 2026-08-30 / 앱 버전 2.2.1 기준
>
> ⚠️ **r/apphunt 사이드바 규칙을 직접 확인하지 못했습니다.** 작성 환경에서 reddit.com 접근이
> 차단돼 있어(www·old·프록시 모두 403), 앱 헌팅 계열 서브(r/apphunt · r/iosapps · r/apps ·
> r/AppHookup)가 공통으로 요구하는 제목 규칙의 **교집합**으로 맞췄습니다.
> 올리기 전에 사이드바를 한 번 대조할 것.

## 제목 규칙 (적용한 것)

- **플랫폼 태그를 맨 앞 대괄호로** — `[iOS]`
- **앱 이름 → 대시 → 한 줄 설명** 순서
- **가격 모델 태그** — `[Free]` / `[Freemium]` / `[Paid]`.
  무료 다운로드 + 인앱결제면 `[Freemium]`이 정확하다. **태그를 틀리게 다는 것이 실제 제거 사유다.**
- 제목에 마크다운(`*`, `**`)을 쓰지 않는다 — 렌더되지 않고 그대로 보인다
- 느낌표·전면 대문자·"Check out my app!!" 금지, 링크 단축기 금지

## 제목 (추천)

```
[iOS] Rereminder — a countdown timer that warns you before it ends, not just when it's over [Freemium]
```

대안:

```
[iOS] Rereminder — set alerts at 10/5/1 min before your timer ends. No ads, no subscription [Freemium]
```

```
[iOS] Rereminder — I got cut off mid-talk one too many times, so I built a timer that taps you early [Freemium]
```

## 본문

**Disclosure: I'm the developer.**

Every timer I've used answers exactly one question — "is it over yet?" — and it answers it at the
worst possible moment: when it's already over. I got cut off in the middle of a talk because I found
out I had 5 minutes left when I had 0. So I built the timer I wanted.

**Rereminder** lets you put as many alerts as you want *inside* the countdown. Drag the bell knobs
around the dial: 10 min before, 5 min, 1 min, whatever the moment needs. The ring splits into colored
sections at each bell, so you can see the shape of your time before you start it — a 45-minute talk
as 20 + 20 + 5, not just "45:00."

**What it does**

- **Multiple pre-alerts, unlimited and free.** That's the whole reason the app exists, so it isn't the thing I charge for.
- **Section view.** Each segment shows its own length and its own countdown, so "how long is this part" is never mental arithmetic.
- **Overtime.** The clock doesn't die at 00:00 — it counts up (+01:23), which turns out to be the number you actually want after a talk.
- **Live Activity / Dynamic Island** with working pause, resume, stop.
- **Apple Watch.** Buzzes your wrist so you're not looking at a phone while people are looking at you. Free — I'm not paywalling the watch.
- **Session mode.** Name each section ("intro / demo / Q&A") and keep a script per section that unfolds on screen when that section starts.
- **Templates.** Save a setup, start it in one tap.

**Try it without installing.** There's an App Clip — open this on an iPhone and the timer runs
immediately, no App Store trip: https://m1zz.github.io/rereminder/

**Free vs Pro, plainly:** everything above about *alerting* is free and always will be. Pro is one
thing — the app remembers your setups (templates, session mode, your last configuration on relaunch)
plus overtime and history. **One-time purchase, no subscription, no ads, and no third-party analytics
SDKs** — the only numbers that leave your phone are anonymous counts to my own iCloud, never your
timer names, alert text, or scripts.

App Store: https://apps.apple.com/us/app/rereminder/id6752551268
Support: https://m1zz.github.io/Rereminder/support.html
Privacy: https://m1zz.github.io/Rereminder/privacy.html

I'd genuinely like to hear where it falls down. The thing I'm least sure about: if you run sessions
for other people — teaching, facilitating, coaching — does the section view actually read in one
glance from across a room, or is it too much? Happy to answer anything in the comments.

## 올리기 전 체크리스트

- [ ] **랜딩 페이지(`docs/index.html`)가 옛 모델 그대로다.** "Unlimited pre-alerts"가 Pro 혜택으로,
      Pomodoro·요리가 유스케이스로 남아 있다. 위 글은 현재 모델(예비 알림 무제한 무료,
      Pro = "앱이 설정을 기억한다") 기준이라 **먼저 페이지를 맞춰야** 링크 타고 온 사람이 모순을 보지 않는다
- [ ] 스크린샷 1~2장 첨부 — `docs/screenshots/01-main-timer.png`(종이 여러 개 꽂힌 다이얼)이
      "이게 왜 다른가"를 한 장으로 말해 준다. 이미지 없는 글은 앱 헌팅 서브에서 잘 안 읽힌다
- [ ] 올린 직후 **한 시간은 붙어서 댓글에 답할 수 있는 시간대**에 게시할 것 — 첫 30분이 전부다
- [ ] 서브 규칙 대조 (제목 태그·자기 홍보 요일 제한·플레어 필수 여부)
