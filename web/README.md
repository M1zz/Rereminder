# web/ — App Clip 배포 자산

App Clip 도메인 연결과 랜딩 페이지는 **블로그 저장소**에 있습니다:
`M1zz/m1zz.github.io` (GitHub Pages)

| 실제 위치 | 내용 |
|---|---|
| `m1zz.github.io/.well-known/apple-app-site-association` | `appclips.apps` 에 `QGAQ3AY3R3.com.xa.toki.Clip` — **FindMe 클립과 공유하므로 기존 항목을 지우지 말 것** |
| `m1zz.github.io/rereminder/index.html` | 랜딩 페이지 (`index.html` 이 원본) |

초대 URL: `https://m1zz.github.io/rereminder/` (`?minutes=N` 으로 시작 시간 지정 가능, 1~120)

## 소개 페이지에서 들어오는 길

앱 소개 페이지(`docs/index.html` → `m1zz.github.io/Rereminder/`, **대문자 R**)에서
위 초대 URL(**소문자 r**)로 가는 링크가 세 군데 있습니다:

| 위치 | 문구 (en / ko) |
|---|---|
| 상단 내비 + 모바일 메뉴 | `nav.tryClip` — Try Now / 바로 써보기 |
| 히어로 보조 CTA | `hero.ctaClip` — Try without installing / 설치 없이 바로 써보기 |
| 푸터 | `footer.tryClip` — Try without installing / 설치 없이 써보기 |

⚠️ **경로 대소문자가 다릅니다.** 소개 페이지는 이 저장소의 `docs/`(`/Rereminder/`),
클립 랜딩은 블로그 저장소(`/rereminder/`)라 서로 다른 배포처입니다. 링크를 고칠 때 헷갈리지 마세요.

## 이 폴더의 파일

- `index.html` — 랜딩 페이지 원본. 고치면 블로그 저장소의 `rereminder/index.html` 로 복사해 푸시.
- `make_appclip_card.py` — App Clip 카드 헤더 이미지 생성 (`python3 web/make_appclip_card.py`)
- `appclip-card-1800x1200.png` — App Store Connect 에 올릴 헤더 이미지

## 검증

```bash
# GitHub Pages 가 파일을 주는지
curl -sI https://m1zz.github.io/.well-known/apple-app-site-association

# Apple 이 실제로 읽어갔는지 (이쪽이 결정적)
curl -s https://app-site-association.cdn-apple.com/a/v1/m1zz.github.io
```

> 참고: GitHub Pages 는 이 파일을 `application/octet-stream` 으로 서빙하지만
> Apple 은 문제없이 파싱합니다 (FindMe 클립으로 이미 검증됨).
> 루트에 `.nojekyll` 이 있어야 `.well-known` 폴더가 서빙됩니다.
