#!/bin/bash
# 맥(Mac Catalyst) 앱스토어 스크린샷 원본을 언어마다 찍는다 → docs/screenshots/raw-mac/<언어>/<번호>-<장면>.png
# 다음 단계: python3 scripts/make_marketing_screenshots.py --mac  → docs/screenshots/marketing/<언어>/mac-*.png (2880×1800)
#
# 사용법:  scripts/capture_mac_screenshots.sh [언어 ...]      (없으면 25개 언어 전부)
#
# ⚠️ 시뮬레이터가 아니라 **이 맥에서** 진짜 앱(com.xa.toki)과 같은 컨테이너로 띄운다.
#    번들 ID 를 바꾼 권한 없는 복사본은 LeeoKit 이 CloudKit 을 여는 순간 죽어서 쓸 수 없었다.
#    그래서 장면이 남기는 흔적을 두 겹으로 막는다:
#    ① 앱(DEBUG): 장면 실행이면 저장소는 메모리만, 클라우드 서비스·iCloud 타이머 동기화·
#       기기 표시·알림 예약을 하지 않는다(`RereminderApp.isScreenshotRun`).
#    ② 여기: 진짜 앱의 설정(앱·앱 그룹)을 먼저 떠 두고, 끝나면(중간에 실패해도) 되돌린다.
#    진짜 맥 앱이 떠 있으면 시작하지 않는다.
# 창이 화면에 잠깐씩 뜨고 닫힌다. 화면 기록 권한이 있는 터미널에서 돌릴 것.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT"
DERIVED="$ROOT/build/mac-shots"
APP="$DERIVED/Build/Products/Debug-maccatalyst/Rereminder.app"
BIN="$APP/Contents/MacOS/Rereminder"
OUT="$ROOT/docs/screenshots/raw-mac"
WORK="$ROOT/build/mac-shots/work"
WAIT="${WAIT:-4}"
SCENES=("01:dial" "02:running" "03:session" "04:sessionRunning")
LANGS=("$@")
[[ ${#LANGS[@]} -eq 0 ]] && LANGS=(ko en en-GB ja zh-Hans zh-Hant de fr es pt-BR pt-PT it ru cs da el fi id nb nl pl sv th tr vi)
locale_for() {
  case "$1" in
    ko) echo ko_KR ;; en) echo en_US ;; en-GB) echo en_GB ;; ja) echo ja_JP ;;
    zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;; de) echo de_DE ;; fr) echo fr_FR ;; es) echo es_ES ;;
    pt-BR) echo pt_BR ;; pt-PT) echo pt_PT ;; it) echo it_IT ;; ru) echo ru_RU ;; cs) echo cs_CZ ;;
    da) echo da_DK ;; el) echo el_GR ;; fi) echo fi_FI ;; id) echo id_ID ;; nb) echo nb_NO ;;
    nl) echo nl_NL ;; pl) echo pl_PL ;; sv) echo sv_SE ;; th) echo th_TH ;; tr) echo tr_TR ;; vi) echo vi_VN ;;
  esac
}

if pgrep -f "/Applications/.*Rereminder.app/Contents/MacOS" >/dev/null; then
  echo "❌ 진짜 두번알림 맥 앱이 떠 있다 — 끄고 다시 돌릴 것"; exit 1
fi

echo "🔨 DEBUG Catalyst 빌드 (스크린샷 장면은 DEBUG 에만 있다)"
xcodebuild -scheme Rereminder -configuration Debug -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath "$DERIVED" build -quiet 2>&1 | grep -v "ld: warning" || true
[[ -x "$BIN" ]] || { echo "❌ 빌드 실패"; exit 1; }

# ② 진짜 앱의 설정을 떠 둔다 — 장면 실행이 마지막 설정·실행 횟수 등을 덮어쓴다.
mkdir -p "$WORK"
PREFS=(
  "$HOME/Library/Containers/com.xa.toki/Data/Library/Preferences/com.xa.toki"
  "$HOME/Library/Group Containers/group.leeo.toki/Library/Preferences/group.leeo.toki"
)
for i in "${!PREFS[@]}"; do
  if [[ -f "${PREFS[$i]}.plist" ]]; then defaults export "${PREFS[$i]}" "$WORK/prefs-$i.plist"; else rm -f "$WORK/prefs-$i.plist"; fi
done
restore() {
  pkill -f "$BIN" 2>/dev/null || true
  sleep 1
  for i in "${!PREFS[@]}"; do
    # import 는 덮지 않고 합친다 — 장면이 더한 키가 남지 않게 먼저 지운다.
    defaults delete "${PREFS[$i]}" 2>/dev/null || true
    if [[ -f "$WORK/prefs-$i.plist" ]]; then defaults import "${PREFS[$i]}" "$WORK/prefs-$i.plist"; fi
  done
  echo "↩︎  진짜 앱 설정을 되돌렸다"
}
trap restore EXIT

# 창 번호 찾기 — 그 프로세스의 화면 위 첫 일반 창
cat > "$WORK/winid.swift" <<'SWIFT'
import CoreGraphics
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
if let w = list.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }) {
    print(w[kCGWindowNumber as String]!)
}
SWIFT
swiftc -O "$WORK/winid.swift" -o "$WORK/winid"

for lang in "${LANGS[@]}"; do
  echo "▸ $lang"
  mkdir -p "$OUT/$lang"
  for item in "${SCENES[@]}"; do
    num="${item%%:*}"; scene="${item#*:}"
    pkill -f "$BIN" 2>/dev/null || true; sleep 1
    open -n "$APP" --args -screenshotScene "$scene" -hasSeenOnboarding YES \
      -AppleLanguages "($lang)" -AppleLocale "$(locale_for "$lang")"
    sleep "$WAIT"
    # 숫자는 초가 바뀔 때 0.3초쯤 넘어가는 애니메이션이 있다 — 초가 막 바뀐 뒤 0.6초에 찍는다.
    perl -MTime::HiRes=time,sleep -e '$f = time - int(time); sleep((1 - $f) + 0.6)'
    pid="$(pgrep -f "$BIN" | head -1 || true)"
    [[ -z "$pid" ]] && { echo "  ❌ 앱이 뜨지 않음 ($scene)"; exit 1; }
    wid="$("$WORK/winid" "$pid" || true)"
    [[ -z "$wid" ]] && { echo "  ❌ 창을 못 찾음 ($scene)"; exit 1; }
    screencapture -x -o -l "$wid" "$OUT/$lang/$num-$scene.png"
    echo "  $OUT/$lang/$num-$scene.png"
  done
done
