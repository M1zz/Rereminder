#!/bin/sh
# 배포 전 게이트 — 다국어 검사 + 전체 테스트가 통과해야 아카이브를 만든다.
#
# 사용법:
#   sh scripts/predeploy.sh            # 검사 + 전체 테스트만 (게이트 확인)
#   sh scripts/predeploy.sh --archive  # 통과 시 App Store용 아카이브 생성 + Organizer 열기
#
# CI(ci.yml)와 fastlane(check/beta/ship)이 같은 스크립트를 호출한다 — 게이트 로직을 한 곳에 유지할 것.
# ⚠️ CODE_SIGNING_ALLOWED=NO 금지 — entitlements 가 빠지면 CloudKit(CKContainer) 초기화가 크래시한다.
set -e
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SCHEME="Rereminder"

echo "🌐 [1/2] 다국어 검사 (check_localization.py)"
python3 scripts/check_localization.py

# 사용 가능한 첫 iPhone 시뮬레이터를 자동 선택 (러너 이미지의 기기 이름 변화에 안전)
DEST_ID="$(xcrun simctl list devices available | grep "iPhone" | head -1 | grep -oE '[0-9A-F-]{36}')"
if [ -z "$DEST_ID" ]; then
  echo "❌ 사용 가능한 iPhone 시뮬레이터가 없습니다 (xcrun simctl list devices)"
  exit 1
fi

echo "🧪 [2/2] 전체 테스트 실행 (RereminderTests, 시뮬레이터 $DEST_ID)"
xcodebuild test \
  -project Rereminder.xcodeproj \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEST_ID" \
  -quiet

echo ""
echo "✅ 모든 검사·테스트 통과 — 배포 가능"

if [ "$1" = "--archive" ]; then
  STAMP="$(date +%Y%m%d-%H%M)"
  ARCHIVE="build/Rereminder-$STAMP.xcarchive"
  echo "📦 아카이브 생성 중: $ARCHIVE"
  xcodebuild archive \
    -project Rereminder.xcodeproj \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    -quiet
  echo "✅ 아카이브 완료 — Organizer에서 Distribute App으로 업로드하세요"
  open "$ARCHIVE"
fi
