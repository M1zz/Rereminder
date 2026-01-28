#!/bin/bash

#
# update_version.sh
# Toki 버전 업데이트 스크립트
#
# 사용법:
#   ./scripts/update_version.sh 1.0.7        # 버전만 업데이트
#   ./scripts/update_version.sh 1.0.7 2      # 버전과 빌드 번호 업데이트
#   ./scripts/update_version.sh --build-only # 빌드 번호만 증가
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/Config/Version.xcconfig"
PROJECT_FILE="$PROJECT_ROOT/Toki.xcodeproj/project.pbxproj"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 현재 버전 읽기
get_current_version() {
    grep "MARKETING_VERSION" "$VERSION_FILE" | sed 's/.*= //'
}

get_current_build() {
    grep "CURRENT_PROJECT_VERSION" "$VERSION_FILE" | sed 's/.*= //'
}

# 사용법 출력
usage() {
    echo "사용법:"
    echo "  $0 <버전>                  예: $0 1.0.7"
    echo "  $0 <버전> <빌드>           예: $0 1.0.7 2"
    echo "  $0 --build-only            빌드 번호만 증가"
    echo "  $0 --show                  현재 버전 표시"
    exit 1
}

# 현재 버전 표시
show_version() {
    CURRENT_VERSION=$(get_current_version)
    CURRENT_BUILD=$(get_current_build)
    echo ""
    echo "📱 Toki 현재 버전 정보"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "버전:      $CURRENT_VERSION"
    echo "빌드 번호: $CURRENT_BUILD"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 빌드 번호만 증가
increment_build() {
    CURRENT_BUILD=$(get_current_build)
    NEW_BUILD=$((CURRENT_BUILD + 1))

    # Version.xcconfig 업데이트
    sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" "$VERSION_FILE"

    echo -e "${GREEN}✅ 빌드 번호 업데이트: $CURRENT_BUILD → $NEW_BUILD${NC}"
}

# 버전 업데이트
update_version() {
    NEW_VERSION="$1"
    NEW_BUILD="${2:-1}"

    # 버전 형식 검증 (x.y.z)
    if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}❌ 오류: 잘못된 버전 형식입니다. (예: 1.0.7)${NC}"
        exit 1
    fi

    CURRENT_VERSION=$(get_current_version)
    CURRENT_BUILD=$(get_current_build)

    echo ""
    echo "📱 Toki 버전 업데이트"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "현재 버전:  $CURRENT_VERSION (빌드 $CURRENT_BUILD)"
    echo "새 버전:    $NEW_VERSION (빌드 $NEW_BUILD)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    read -p "업데이트하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⚠️  취소되었습니다.${NC}"
        exit 0
    fi

    # Version.xcconfig 업데이트
    sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION/" "$VERSION_FILE"
    sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" "$VERSION_FILE"

    echo ""
    echo -e "${GREEN}✅ 버전 업데이트 완료!${NC}"
    echo ""
    echo "다음 단계:"
    echo "1. git add Config/Version.xcconfig"
    echo "2. git commit -m \"chore: 버전 $NEW_VERSION으로 업데이트\""
    echo "3. git tag v$NEW_VERSION"
    echo ""
}

# 메인 로직
case "${1:-}" in
    --show)
        show_version
        ;;
    --build-only)
        increment_build
        show_version
        ;;
    --help|-h|"")
        show_version
        usage
        ;;
    *)
        update_version "$1" "${2:-1}"
        show_version
        ;;
esac
