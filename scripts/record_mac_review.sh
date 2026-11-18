#!/bin/bash
# App Review 가 요구하는 화면 녹화를 **이 맥에서** 찍는다(Mac 앱 심사용).
# 앱을 켜는 순간부터: 1분 타이머(30초 전 알림·일시정지·재개·끝) → 구간·반복 → 세션 모드와 대본 → 설정 ▸ 요금제 화면.
#   → ~/Desktop/두번알림-심사/Rereminder-macOS-review.mp4 (창 영역만, 약 2분 20초)
#
# 사용법:  scripts/record_mac_review.sh        (도는 2분 30초 동안 마우스·키보드를 건드리지 말 것)
#
# ⚠️ UI 테스트(`testReviewDemo`)는 맥에서 쓸 수 없었다 — XCUITest 가 보낸 클릭이 Catalyst 창에 먹지 않았다.
#    그래서 클릭을 직접 보낸다(창 기준 좌표, 창 460×620pt 기준). 화면 배치를 바꾸면 아래 좌표도 고칠 것.
# ⚠️ 빌드 결과물은 문서 폴더 밖(/tmp)에 둔다. 터미널에 화면 기록·손쉬운 사용 권한이 있어야 한다.
# ⚠️ 진짜 앱과 같은 컨테이너로 뜬다. 장면 실행(`isScreenshotRun`)이라 저장소·클라우드·알림 예약은 건드리지 않지만
#    **이 맥의 앱 설정(마지막 다이얼 등)은 데모 값으로 바뀐다.** 터미널은 다른 앱의 컨테이너를 읽지 못해
#    `capture_mac_screenshots.sh` 의 떠 두고 되돌리기가 실제로는 빈 값을 다룬다(2026-11-18 확인).
# `-dev.forceFree YES`: 이 맥에 구매 기록이 있어도 화면만 무료 사용자로 본다(DEBUG 전용) — 가격과 구매 버튼이 보이게.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
W="${TMPDIR:-/tmp}/rereminder-mac-review"; mkdir -p "$W"
APP="$W/dd/Build/Products/Debug-maccatalyst/Rereminder.app"
OUT_DIR="$HOME/Desktop/두번알림-심사"; OUT="$OUT_DIR/Rereminder-macOS-review.mp4"; mkdir -p "$OUT_DIR"

echo "🔨 DEBUG Catalyst 빌드"
xcodebuild build -scheme Rereminder -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath "$W/dd" -quiet 2>&1 | grep -E ' error|BUILD FAILED' || true
[[ -d "$APP" ]] || { echo "❌ 빌드 실패"; exit 1; }
for t in click scroll front trim; do swiftc -O "scripts/app_review/$t.swift" -o "$W/$t" 2>/dev/null; done

launch() {
  pkill -f Debug-maccatalyst/Rereminder.app 2>/dev/null || true; sleep 1
  open -n "$APP" --args -screenshotScene reviewDemo -hasSeenOnboarding YES -blankStart.completions 9 \
    -blankStart.complexityAsked YES -dev.testPaywall YES -dev.forceFree YES -AppleLanguages "(en)" -AppleLocale en_US
}
# 맨 앞 창이 이 앱일 때만 누른다 — 아니면 다른 앱을 누르게 된다.
front() {
  local f; f="$("$W/front")"
  if [[ "$f" != Rereminder* ]]; then open "$APP"; sleep 0.8; f="$("$W/front")"; fi
  [[ "$f" == Rereminder* ]] || { echo "❌ 앱이 맨 앞이 아니다: $f"; exit 1; }
  IFS=, read -r X Y _ _ <<<"${f#Rereminder }"
}
c()  { front; "$W/click"  $((X+$1)) $((Y+$2)) ${3:-} >/dev/null; }
sc() { front; "$W/scroll" $((X+$1)) $((Y+$2)) "$3"; }

# 창이 뜨는 자리를 먼저 알아낸다(맥은 창 자리를 기억한다)
launch; sleep 5; front; RECT="$("$W/front")"; RECT="${RECT#Rereminder }"
pkill -f Debug-maccatalyst/Rereminder.app; sleep 1

echo "🎬 녹화 시작 — 손을 떼고 기다릴 것 ($RECT)"
rm -f "$W/raw.mov"
screencapture -x -v -V 152 -R "$RECT" "$W/raw.mov" & SP=$!
sleep 2
launch; sleep 7
c 230 295; sleep 3            # 시작
c 267 319; sleep 2.5          # 일시정지
c 267 319; sleep 59           # 재개 → 30초 전 알림 → 끝
c 382 500; sleep 2            # 시간이 다 됐어요 · 확인
c 192 319; sleep 2.5          # 정지(넘긴 시간 세기 끝)
c 230 223; sleep 2.5          # 가운데 시간 → 시간 입력
c 339 198; sleep 2.5          # 구간
sc 230 330 -240; sleep 2
c 407 369; sleep 1; c 407 369; sleep 2   # 반복 ×3
c 230 468; sleep 3            # 적용
c 230 295; sleep 4            # 시작
c 192 319; sleep 2            # 정지
c 35 592; sleep 3.5           # 세션 모드
c 230 235; sleep 6            # 세션 시작 — 대본이 펴진다
c 212 170; sleep 2            # 정지
c 35 592; sleep 2             # 세션 모드 끔
c 431 592; sleep 3            # 설정
c 230 102; sleep 5            # 요금제 → 페이월
c 126 84; sleep 3.5           # 기억
c 335 84; sleep 2.5           # Pro
sc 230 350 -330; sleep 4
wait $SP; pkill -f Debug-maccatalyst/Rereminder.app || true

# 앞의 3.5초는 창이 뜨기 전이라 뒤에 있던 다른 앱이 찍힌다 — 반드시 잘라 낸다.
"$W/trim" "$W/raw.mov" "$OUT" 3.5 146
echo "✅ $OUT — 올리기 전에 처음 몇 초에 다른 창이 비치지 않는지 눈으로 확인할 것"
