# 버전 관리 가이드

## 개요

Rereminder 앱의 버전을 중앙에서 관리하기 위한 설정 파일입니다.

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

## 동작 방식 (설정 완료 — 더 손댈 것 없음)

`Config/Version.xcconfig` 가 **프로젝트 레벨 base configuration** 으로 연결되어 있고,
어떤 타겟도 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 을 자기 빌드 설정에
따로 갖고 있지 않습니다. 그래서 이 파일 하나만 고치면 전 타겟에 반영됩니다.

적용 대상: `Rereminder`, `RereminderWatch`, `RereminderAlarmExtension`,
`RereminderClip`, `RereminderMenuBar`, `RereminderTests`

### ⚠️ 깨뜨리지 않으려면

1. **타겟 Build Settings 에 `MARKETING_VERSION` 을 다시 넣지 마세요.**
   타겟 값이 xcconfig 를 덮어써서 중앙 관리가 무력화됩니다.
   (실제로 이 문제가 있었고 2026-07-27 에 정리했습니다 — 아래 이력 참고)
2. **`Version.xcconfig` 를 저장소 루트에 다시 만들지 마세요.**
   예전에 루트와 `Config/` 두 곳에 같은 이름 파일이 있었고,
   프로젝트는 루트 쪽을, 스크립트·문서는 `Config/` 쪽을 보고 있어 값이 어긋났습니다.

### 확인 방법

```bash
# 한 곳만 보면 됨
./scripts/update_version.sh --show

# 타겟별 실제 해석값이 모두 같은지 검증
for s in Rereminder RereminderClip RereminderWatch RereminderAlarmExtension; do
  echo -n "$s: "
  xcodebuild -scheme "$s" -showBuildSettings -configuration Release 2>/dev/null \
    | grep -E "^\s+MARKETING_VERSION " | sed 's/^ *//' | sort -u
done
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
