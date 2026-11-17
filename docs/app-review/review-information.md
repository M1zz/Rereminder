# App Review 정보 — 두번알림(Rereminder)

2026-11-17 visionOS 2.3.9 심사에서 "제출 이력이 적은 계정" 추가 정보 요청을 받았다.
아래 영어 글을 **App Store Connect 답장**과 **앱 심사 정보 ▸ 메모** 두 곳에 같이 넣는다(앞으로의 제출에도 남는다).
화면 녹화는 Apple Vision Pro 실기기에서 사람이 찍어 답장에 붙인다(아래 "녹화 순서").

## 녹화 순서 (Apple Vision Pro, 최신 visionOS)

제어 센터 ▸ 나의 화면 기록. 앱 아이콘을 눌러 **켜는 장면부터** 시작한다. 2~3분.

1. 홈에서 두번알림 실행
2. 흰 핸들을 끌어 시간을 정하고, 링을 두 번 눌러 알림 하나를 더한다
3. 시작 → 예비 알림이 울리는 것까지(짧게 1분 + 30초 전 알림이면 기다리기 쉽다) → 일시정지 → 정지
4. 가운데 시간 누르기 ▸ 구간 목록 ▸ 1:00, 0:30 ▸ 반복 × 3 ▸ 적용 → 시작해서 3 / 3 표시 보이기 → 정지
5. 아래 막대의 세션 모드 → 구간 이름·대본 적기 → 시작해서 대본이 넘어가는 것 보이기 → 정지
6. 🔖 → 지금 설정 저장 → 저장한 칩으로 시작 → 정지
7. 설정 ▸ 요금제 줄 → 페이월(무료 · 기억 · Pro, 연 구독·평생) 보이기 → (선택) 샌드박스로 구매 → 구매 복원

## 답장 · 메모 (영어, 그대로 붙여 넣기)

Hello App Review team,

Thank you for reviewing Rereminder. A screen recording made on Apple Vision Pro (latest visionOS) is attached. It starts at app launch and shows the main flow, the in-app purchase screen, and restoring purchases. The app has no accounts, no login, and no user-generated content shared with others.

1. Screen recording
Attached. It shows: launching the app, setting a timer on the dial, adding alerts, starting, a pre-alert firing, pause and stop, interval and repeat setup, Session mode with per-section scripts, saving a setup, and the paywall with Restore Purchases.

2. Purpose and audience
Rereminder is a timer that alerts you several times before time runs out, not only at the end. A normal timer rings when it is already too late. Rereminder lets people pace themselves with alerts such as 5 minutes and 1 minute before the end. It is made for presenters and speakers, teachers and instructors, workshop facilitators, and people who exercise or study in timed intervals.

3. How to use the main features (no login or sample files needed)
- Drag the white handle around the ring to set the total time. Tap the time in the center to type it in instead.
- Double-tap an empty spot on the ring to add an alert at that moment. Drag a bell to move it. Double-tap a bell to remove it.
- Tap Start. Each bell rings as a notification, then the timer finishes. Pause and Stop are under the time.
- Tap the time, open Intervals, list lengths such as 1:00 and 0:30, and set Repeat to run the whole ring several times.
- Session mode (button in the bottom bar) names each section and shows a script for it while the timer runs.
- The bookmark button saves the current setup and starts saved setups.
- Settings shows the plan, notification options, and Restore Purchases.
- Paid tiers: Plus (remembers setups, unlimited saved setups, full history) and Pro (Plus features plus Session mode and scripts). Each is offered as a yearly auto-renewable subscription or a one-time lifetime purchase. New users can use every feature for a free period before the paywall appears. The paywall can be opened anytime from Settings > the plan row at the top.

4. External services
Only Apple frameworks and services. No third-party SDKs, no analytics companies, no AI services, no external servers.
- StoreKit / In-App Purchase (payments and subscriptions)
- CloudKit / iCloud (optional sync of saved setups, the in-app feedback form, and anonymous usage counts)
- iCloud Key-Value Storage (keeps a running timer in sync between the user's own devices)
- User Notifications (the timer alerts)

5. Regional differences
None. The app works the same in every region. It is localized into 25 languages. Prices follow the standard App Store price tiers for each storefront.

6. Regulated industry or third-party material
Not applicable. The app is not in a regulated industry and contains no protected third-party material. All artwork, sounds, and text are our own.

Thank you.
