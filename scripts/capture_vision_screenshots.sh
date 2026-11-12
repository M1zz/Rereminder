#!/bin/sh
# Apple Vision Pro 스토어 스크린샷을 언어마다 시뮬레이터로 찍는다 → docs/screenshots/marketing/<언어>/vision-NN-*.jpg
# 시뮬레이터가 뱉는 3840×2160 이 그대로 제출 규격이라 합성하지 않는다(창이 방 안에 뜬 모습 그대로).
# PNG 는 한 장에 6MB 라 JPEG(품질 92)로 둔다 — 사진 같은 방 장면이라 차이가 보이지 않고 레포가 가볍다.
#
# 사용법:
#   sh scripts/capture_vision_screenshots.sh <Vision Pro 시뮬레이터 UDID> <앱(.app, Debug, xrsimulator)> [언어 ...]
#   - 시뮬레이터는 미리 켜 둔다. 앱은 Debug 빌드여야 한다(-screenshotScene 은 DEBUG 에만 있다).
#   - 화면 상태는 DEBUG 빌드의 ScreenshotScene(Rereminder/Modules/ScreenshotScene.swift)이 세운다.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEV="$1"; APP="$2"; shift 2
LANGS="$*"
[ -n "$LANGS" ] || LANGS="ko en en-GB zh-Hans zh-Hant ja ru es de fr it pt-BR pt-PT th vi cs da el fi id nb nl pl sv tr"
BID=com.xa.toki
WAIT="${WAIT:-8}"
locale_of() {
  case "$1" in
    ko) echo ko_KR ;; en) echo en_US ;; en-GB) echo en_GB ;; zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;;
    ja) echo ja_JP ;; ru) echo ru_RU ;; es) echo es_ES ;; de) echo de_DE ;; fr) echo fr_FR ;; it) echo it_IT ;;
    pt-BR) echo pt_BR ;; pt-PT) echo pt_PT ;; th) echo th_TH ;; vi) echo vi_VN ;; cs) echo cs_CZ ;; da) echo da_DK ;; el) echo el_GR ;;
    fi) echo fi_FI ;; id) echo id_ID ;; nb) echo nb_NO ;; nl) echo nl_NL ;; pl) echo pl_PL ;; sv) echo sv_SE ;;
    tr) echo tr_TR ;; *) echo "$1" ;;
  esac
}
t() { perl -e 'alarm shift; exec @ARGV' "$@"; }
launch() { t 60 xcrun simctl launch "$DEV" $BID -screenshotScene "$2" -hasSeenOnboarding YES -AppleLanguages "($1)" -AppleLocale "$(locale_of "$1")" >/dev/null; }
shot() { # 언어 출력파일 장면
  lang="$1"; out="$2"; scene="$3"
  t 30 xcrun simctl terminate "$DEV" $BID >/dev/null 2>&1 || true
  # 가끔 launch 가 응답하지 않는다 — 한 번 더 시도한다.
  launch "$lang" "$scene" || { t 30 xcrun simctl terminate "$DEV" $BID >/dev/null 2>&1 || true; sleep 3; launch "$lang" "$scene"; }
  sleep "$WAIT"
  mkdir -p "$(dirname "$out")"
  t 60 xcrun simctl io "$DEV" screenshot "$out.png" >/dev/null 2>&1
  python3 -c "from PIL import Image; import sys; Image.open(sys.argv[1]).convert('RGB').save(sys.argv[2], quality=92, optimize=True)" "$out.png" "$out"
  rm -f "$out.png"
  echo "  $out"
}
t 120 xcrun simctl install "$DEV" "$APP"
# 부팅 뒤 첫 실행은 시뮬레이터가 Apple 계정 로그인 창을 띄운다(계정이 없어서). 한 번 띄웠다 끄면 그 뒤로는 뜨지 않는다.
launch ko dial || true
sleep "$WAIT"
t 30 xcrun simctl terminate "$DEV" $BID >/dev/null 2>&1 || true
for lang in $LANGS; do
  echo "▸ $lang"
  OUT="$ROOT/docs/screenshots/marketing/$lang"
  shot "$lang" "$OUT/vision-01-dial.jpg"            dial
  shot "$lang" "$OUT/vision-02-running.jpg"         running
  shot "$lang" "$OUT/vision-03-session.jpg"         session
  shot "$lang" "$OUT/vision-04-session-running.jpg" sessionRunning
done
