#!/bin/bash
# 워치 앱스토어 스크린샷을 언어별로 찍는다 (416×496, Apple Watch Series 11 46mm).
#
# 사용법:
#   scripts/capture_watch_screenshots.sh              # 10개 언어 전부
#   scripts/capture_watch_screenshots.sh de fr        # 일부 언어만
#
# 결과: docs/screenshots/watch/<언어>/01-duration.png … 04-finished.png
# 화면 상태는 DEBUG 빌드의 `WatchScreenshotScene`(RereminderWatch/WatchScreenshotScene.swift)이 세운다.
#
# ⚠️ 워치 시뮬레이터가 아이폰 시뮬레이터와 **페어링돼 있어야** 한다. 안 그러면 상태 표시줄에
#    빨간 "폰 연결 끊김" 아이콘이 붙는다. 짝이 되는 아이폰도 부팅해 둔다.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

BUNDLE_ID="com.xa.toki.watchkitapp"
WATCH_NAME="${WATCH_NAME:-Apple Watch Series 11 (46mm)}"   # ASC 규격 416×496 을 내는 기기
DERIVED="${DERIVED:-$ROOT/build/watch-screenshots}"
OUT="$ROOT/docs/screenshots/watch"

# 번호-장면-기다릴 초
SCENES=("01:duration:4" "02:prealerts:5" "03:running:8" "04:finished:10")

LANGS=("$@")
[[ ${#LANGS[@]} -eq 0 ]] && LANGS=(ko en ja zh-Hans zh-Hant de fr es pt-BR it)

# 페어링된(active) 워치 중 이름이 맞는 것 + 그 짝 아이폰
read -r UDID PHONE < <(xcrun simctl list pairs -j | python3 -c "
import json, sys
name = sys.argv[1]
pairs = [p for p in json.load(sys.stdin)['pairs'].values()
         if p['watch']['name'] == name and 'unavailable' not in p['state']]
# 이미 켜져 있는 워치를 먼저 쓴다 — 같은 이름이 여럿이면 매번 다른 기기를 고르게 된다.
pairs.sort(key=lambda p: p['watch']['state'] != 'Booted')
if pairs:
    print(pairs[0]['watch']['udid'], pairs[0]['phone']['udid'])
" "$WATCH_NAME")
[[ -z "${UDID:-}" ]] && { echo "❌ 페어링된 '$WATCH_NAME' 없음 — xcrun simctl pair <워치> <아이폰>"; exit 1; }
xcrun simctl boot "$PHONE" 2>/dev/null || true
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

echo "🔨 DEBUG 빌드 (스크린샷 장면은 DEBUG 에만 있다)"
xcodebuild -project Rereminder.xcodeproj -scheme RereminderWatch -configuration Debug \
  -destination "platform=watchOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" build -quiet
APP="$DERIVED/Build/Products/Debug-watchsimulator/RereminderWatch.app"

xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time 9:41 2>/dev/null || true

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

for lang in "${LANGS[@]}"; do
  mkdir -p "$OUT/$lang"
  for entry in "${SCENES[@]}"; do
    IFS=: read -r num scene wait <<< "$entry"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshotScene "$scene" \
      -AppleLanguages "($lang)" -AppleLocale "$lang" >/dev/null
    sleep "$wait"
    # 설치 직후 첫 장은 화면이 덜 떠서 실패할 때가 있다 — 세 번까지 다시 찍는다.
    for try in 1 2 3; do
      # 기존 파일을 simctl 이 바로 덮어쓰지 못하는 경우가 있어(권한 오류) 임시 파일에 찍고 옮긴다.
      xcrun simctl io "$UDID" screenshot "$TMP/shot.png" >/dev/null 2>&1 \
        && mv -f "$TMP/shot.png" "$OUT/$lang/$num-$scene.png" && break
      [[ $try -eq 3 ]] && { echo "❌ $lang/$num-$scene 캡처 실패"; exit 1; }
      sleep 3
    done
    echo "📸 watch/$lang/$num-$scene.png"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
echo "✅ $OUT"
