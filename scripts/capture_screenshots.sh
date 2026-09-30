#!/bin/bash
# 앱스토어 스크린샷 원본을 언어별로 찍는다 — 다음 릴리즈에도 똑같이 다시 찍을 수 있게.
#
# 사용법:
#   scripts/capture_screenshots.sh                 # 10개 언어 전부
#   scripts/capture_screenshots.sh de fr           # 일부 언어만
#
# 결과: docs/screenshots/raw/<언어>/<번호>-<장면>.png  (1320×2868, 6.9" 원본)
# 다음 단계: python3 scripts/make_marketing_screenshots.py  → docs/screenshots/marketing/<언어>/
#
# 화면 상태는 DEBUG 빌드의 `ScreenshotScene`(Rereminder/Modules/ScreenshotScene.swift)이 세운다.
# 장면을 늘리려면 그 파일의 case 와 아래 SCENES 를 함께 고칠 것.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

BUNDLE_ID="com.xa.toki"
DEVICE_NAME="${DEVICE_NAME:-iPhone 17 Pro Max}"
DERIVED="${DERIVED:-$ROOT/build/screenshots}"
OUT="$ROOT/docs/screenshots/raw"

# 번호-장면 (파일 이름 순서가 스토어에 보이는 순서다)
SCENES=("01:dial" "02:running" "03:session" "04:sessionRunning")

# 언어 코드 → 로케일 (시간·숫자 표기가 그 나라 것으로 나오게)
locale_for() {
  case "$1" in
    ko) echo ko_KR ;; en) echo en_US ;; ja) echo ja_JP ;;
    zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;;
    de) echo de_DE ;; fr) echo fr_FR ;; es) echo es_ES ;;
    pt-BR) echo pt_BR ;; it) echo it_IT ;;
  esac
}

LANGS=("$@")
[[ ${#LANGS[@]} -eq 0 ]] && LANGS=(ko en ja zh-Hans zh-Hant de fr es pt-BR it)

UDID="$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['name'] == name and d['isAvailable']:
            print(d['udid']); sys.exit()
" "$DEVICE_NAME")"
[[ -z "$UDID" ]] && { echo "❌ 시뮬레이터 '$DEVICE_NAME' 없음"; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true

echo "🔨 DEBUG 빌드 (스크린샷 장면은 DEBUG 에만 있다)"
xcodebuild -scheme Rereminder -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" build -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Rereminder.app"

# 새로 깔아야 이전 실행의 안내·기록이 끼지 않는다.
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularBars 4 --dataNetwork wifi

# 한 번 먼저 띄워 둔다 — 첫 실행은 상태 막대에 "◀ 이전 앱" 돌아가기 표시가 붙는다.
xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshotScene dial -hasSeenOnboarding YES >/dev/null
sleep 3

for lang in "${LANGS[@]}"; do
  mkdir -p "$OUT/$lang"
  for entry in "${SCENES[@]}"; do
    num="${entry%%:*}"; scene="${entry#*:}"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
      -screenshotScene "$scene" \
      -AppleLanguages "($lang)" -AppleLocale "$(locale_for "$lang")" \
      -hasSeenOnboarding YES >/dev/null
    # 실행 중 장면은 몇 초 흘러야 "도는 중"으로 보인다.
    sleep 6
    xcrun simctl io "$UDID" screenshot "$OUT/$lang/$num-$scene.png" >/dev/null 2>&1
    echo "📸 $lang/$num-$scene.png"
  done
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear
echo "✅ $OUT"
