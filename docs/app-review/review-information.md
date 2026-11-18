# App Review 정보 — 두번알림(Rereminder)

2026-11-17 visionOS 2.3.9 심사에서 "제출 이력이 적은 계정" 추가 정보 요청을 받았다.
아래 영어 글을 **App Store Connect 답장**과 **앱 심사 정보 ▸ 메모** 두 곳에 같이 넣는다(앞으로의 제출에도 남는다).
화면 녹화는 실기기가 없어 visionOS 시뮬레이터에서 `RereminderUITests.testReviewDemo` 로 자동으로 찍었다(아래 "녹화 순서").

## 녹화 순서 (시뮬레이터 자동)

실기기가 없어 visionOS 시뮬레이터에서 UI 테스트가 앱을 조작하고 그 화면을 녹화한다.
테스트는 `REVIEW_DEMO=1` 일 때만 돈다(배포 전 검사에서는 건너뛴다). 단위 테스트 묶음이 visionOS 를 지원하지 않아,
UI 테스트만 든 개인 스킴(`xcuserdata/…/ReviewDemo.xcscheme`)으로 돌린다.

    V=<Apple Vision Pro 시뮬레이터 UDID>
    O=(SUPPORTED_PLATFORMS="iphoneos iphonesimulator xros xrsimulator" XROS_DEPLOYMENT_TARGET=26.0)
    xcodebuild build-for-testing -scheme ReviewDemo -destination "id=$V" "${O[@]}"
    xcrun simctl io $V recordVideo --codec h264 review.mov &      # "Recording started" 뒤
    TEST_RUNNER_REVIEW_DEMO=1 xcodebuild test-without-building -scheme ReviewDemo -destination "id=$V" "${O[@]}" \
        -only-testing:RereminderUITests/RereminderUITests/testReviewDemo
    pkill -INT -f 'simctl io.*recordVideo'

앞의 첫 실행(설정용)과 끝의 홈 화면을 잘라 내고 창 둘레로 확대한다(1920×1080, 2분 23초).
2026-11-17 본: `~/Desktop/두번알림-심사/Rereminder-visionOS-review.mp4`.
반복 횟수 + 버튼은 자동 탭이 닿지 않아 영상에서는 반복 칸이 보이기만 한다.

## 답장 · 메모 (영어, 그대로 붙여 넣기)

Hello App Review team,

Thank you for reviewing Rereminder. A screen recording of the visionOS app is attached. It starts at app launch and shows the main flow and the in-app purchase screen. The app has no accounts, no login, and no user-generated content shared with others.

1. Screen recording
Attached. It was recorded in the visionOS simulator (Xcode, visionOS 26.2) because we do not have an Apple Vision Pro device. The visionOS app is the same SwiftUI app that runs on iPhone and iPad. It shows: launching the app, a 1 minute timer with a pre-alert 30 seconds before the end, pause and resume, the end of the timer, the interval and repeat settings, Session mode with a script for each section, and the paywall with the Plus and Pro plans.

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


---

# Mac 앱 (2026-11-18)

Mac 앱 첫 제출(2.3.12 빌드 42)에도 같은 추가 정보 요청이 왔다. 답장과 심사 메모는 아래 글을 쓴다.

## 먼저 할 일: 고친 빌드를 올린다

⚠️ **빌드 42 는 맥에서 가운데 시간을 누르면 죽는다.** 시간 입력 시트의 휠(`UIPickerView`)이 "Mac에 최적화" 모드에서
지원되지 않아 예외를 던진다(이 맥에서 두 번 중 두 번). 심사에서 그대로 걸릴 문제라 `numberWheelStyle()`(맥에서는 메뉴)로 고쳤다.
**새 빌드를 올려 제출의 빌드를 바꾼 뒤에** 답장한다. 녹화는 고친 코드로 찍었다.

## 녹화 (이 맥에서 자동)

    scripts/record_mac_review.sh     # → ~/Desktop/두번알림-심사/Rereminder-macOS-review.mp4

MacBook Pro, macOS 27.0.1. 창 영역만 920×1240, 2분 22초. 앱이 뜨는 순간부터 요금제 화면까지.
UI 테스트(`testReviewDemo`)는 맥에서 클릭이 먹지 않아 쓰지 못했고, 스크립트가 클릭을 직접 보낸다.
이 맥에는 구매 기록이 있어 `-dev.forceFree YES`(DEBUG 전용)로 무료 사용자 화면을 띄웠다 — 가격과 구매 버튼이 보인다.

## 답장 · 메모 (영어, 그대로 붙여 넣기)

Hello App Review team,

Thank you for reviewing Rereminder for Mac. A screen recording is attached. It was captured on a physical Mac (MacBook Pro, macOS 27.0.1). It begins with launching the app and shows the typical flow and the in-app purchase screen. The app has no accounts, no login, and no user-generated content shared with other people, so there are no registration, deletion, reporting, or blocking flows.

1. Screen recording
Attached (2 min 22 s). It shows, in order: launching the app, starting a 1 minute timer with a pre-alert 30 seconds before the end, pause and resume, the pre-alert, the end of the timer and the "Time is up" confirmation, typing the time and the interval list with Repeat set to 3 rounds, Session mode with a script for each section, and Settings > Upgrade, which opens the purchase screen with the Remember and Pro plans, their yearly and lifetime prices, Restore Purchases, Redeem Code, Terms of Use, and Privacy Policy.

2. Purpose and audience
Rereminder is a timer that alerts you several times before time runs out, not only at the end. A normal timer rings when it is already too late. Rereminder lets people pace themselves with alerts such as 5 minutes and 1 minute before the end. It is made for presenters and speakers, teachers and instructors, workshop facilitators, and people who exercise or study in timed intervals. On the Mac it sits next to slides or notes while presenting or teaching.

3. How to use the main features (no login or sample files needed)
- Drag the white handle around the ring to set the total time, or click the time in the center to enter it.
- Double-click an empty spot on the ring to add an alert at that moment. Drag a bell to move it. Double-click a bell to remove it.
- Click Start. Each bell rings as a notification, then the timer finishes. Stop and Pause are under the time. Space also starts and pauses.
- Click the time, open Intervals, list lengths such as 0:30 and 0:30, and set Repeat to run the whole ring several times.
- Session mode (button at the bottom left) names each section and shows a script for it while the timer runs.
- The bookmark button saves the current setup and starts saved setups.
- Settings (gear button) shows the plan, notification options, and Restore Purchases.
- Paid tiers: Remember (remembers setups, unlimited saved setups, full history) and Pro (everything in Remember plus Session mode and scripts). Each is offered as a yearly auto-renewable subscription or a one-time lifetime purchase. New users can use every feature during a free period before the app asks. The purchase screen can be opened at any time from Settings > Upgrade, the first row.

4. External services
Only Apple frameworks and services. No third-party SDKs, no analytics companies, no AI services, no servers of our own.
- StoreKit / In-App Purchase (payments and subscriptions)
- CloudKit / iCloud (optional sync of saved setups, the in-app feedback form, and anonymous usage counts)
- iCloud Key-Value Storage (keeps a running timer in sync between the user's own devices)
- User Notifications (the timer alerts)

5. Regional differences
None. The app works the same in every region. It is localized into 25 languages. Prices follow the App Store pricing for each storefront.

6. Regulated industry or third-party material
Not applicable. The app is not in a regulated industry and contains no protected third-party material. All artwork, sounds, and text are our own.

Thank you.
