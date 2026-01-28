# 버전 관리 가이드

## 개요

Toki 앱의 버전을 중앙에서 관리하기 위한 설정 파일입니다.

## 파일 구조

```
Config/
└── Version.xcconfig    # 버전 정보 (MARKETING_VERSION, CURRENT_PROJECT_VERSION)
```

## 버전 업데이트 방법

### 1. 스크립트 사용 (권장)

```bash
# 현재 버전 확인
./scripts/update_version.sh --show

# 버전 업데이트 (빌드 번호는 1로 초기화)
./scripts/update_version.sh 1.0.7

# 버전과 빌드 번호 함께 업데이트
./scripts/update_version.sh 1.0.7 2

# 빌드 번호만 증가
./scripts/update_version.sh --build-only
```

### 2. 수동 편집

`Config/Version.xcconfig` 파일을 직접 수정:

```xcconfig
MARKETING_VERSION = 1.0.7
CURRENT_PROJECT_VERSION = 2
```

## Xcode 프로젝트 설정 (초기 설정 필요)

### ⚠️ 중요: 처음 한 번만 설정하면 됩니다

1. **Xcode에서 프로젝트 열기**
   - `Toki.xcodeproj` 더블클릭

2. **모든 타겟에 xcconfig 적용**

   각 타겟(Toki, WatchToki Watch App, TokiAlarm)에 대해:

   a. 프로젝트 네비게이터에서 프로젝트 파일 선택

   b. 타겟 선택 (Toki, WatchToki Watch App, TokiAlarm)

   c. "Build Settings" 탭 선택

   d. "+" 버튼 클릭 → "Add User-Defined Setting"

   e. 또는 상단 검색창에서 "MARKETING_VERSION" 검색

   f. 각 설정의 값을 다음과 같이 변경:
      ```
      MARKETING_VERSION = $(inherited)
      CURRENT_PROJECT_VERSION = $(inherited)
      ```

3. **프로젝트 레벨에서 xcconfig 파일 연결**

   a. 프로젝트 파일 선택 (타겟이 아닌 프로젝트)

   b. "Info" 탭 선택

   c. "Configurations" 섹션에서 각 Configuration(Debug, Release)에 대해:
      - Configuration 옆 화살표 클릭
      - 각 타겟의 드롭다운에서 "Version" 선택

4. **빌드하여 확인**
   ```bash
   xcodebuild -project Toki.xcodeproj -showBuildSettings | grep VERSION
   ```

## 버전 관리 워크플로우

### 새 버전 릴리즈

```bash
# 1. 버전 업데이트
./scripts/update_version.sh 1.0.7

# 2. 커밋
git add Config/Version.xcconfig
git commit -m "chore: 버전 1.0.7로 업데이트"

# 3. 태그 생성
git tag v1.0.7
git push origin dev --tags
```

### 빌드 번호 증가 (같은 버전 내)

```bash
# TestFlight 업로드 전마다 실행
./scripts/update_version.sh --build-only

git add Config/Version.xcconfig
git commit -m "chore: 빌드 번호 증가"
```

## 버전 번호 규칙

### MARKETING_VERSION (앱 버전)
- 형식: `X.Y.Z` (예: 1.0.7)
- **X (Major)**: 대규모 변경, 호환성 깨짐
- **Y (Minor)**: 새로운 기능 추가
- **Z (Patch)**: 버그 수정, 작은 개선

### CURRENT_PROJECT_VERSION (빌드 번호)
- 형식: 정수 (예: 1, 2, 3...)
- 같은 버전을 여러 번 빌드할 때마다 증가
- TestFlight 업로드 시 반드시 이전보다 커야 함

## 트러블슈팅

### 버전이 업데이트되지 않을 때

1. Xcode를 닫고 다시 열기
2. Clean Build Folder (Cmd+Shift+K)
3. 파생 데이터 삭제:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

### 스크립트 실행 권한 오류

```bash
chmod +x scripts/update_version.sh
```

## 참고

- 모든 타겟(iOS, Watch, Widget)이 동일한 버전을 공유합니다
- 버전 변경 시 Xcode 프로젝트 파일은 수정하지 마세요
- `Version.xcconfig`만 수정하면 자동으로 모든 타겟에 반영됩니다
