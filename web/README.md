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

## ⚠️ 이 파일은 배포본과 어긋난 적이 있다

2026-08-30 에 확인했더니 **저장소의 `index.html` 은 128줄, 실제 배포본은 806줄**이었다.
블로그 저장소에서 페이지를 직접 고치면서(인페이지 데모 추가) 이쪽으로 되돌려 놓지 않은 것이다.
그 상태에서 저장소 사본을 복사해 올렸다면 **데모가 통째로 사라졌을 것이다.**

**고치기 전에 배포본과 같은지 먼저 확인할 것:**
```bash
curl -s https://m1zz.github.io/rereminder/ > /tmp/live.html
diff /tmp/live.html web/index.html   # 달라야 할 이유가 없다
```
지금은 배포본을 가져와 맞춰 두었다(라이트/다크 + 이중언어는 그 위에 얹었다).

## 언어 — 기기 언어를 보고 ko/en 을 고른다

이 저장소의 웹 페이지 넷(`web/index.html`, `docs/index.html`, `docs/support.html`,
`docs/privacy.html`)은 모두 **브라우저 언어를 감지해 한국어·영어 중 하나를 그리고**,
오른쪽 위 전환 버튼으로 바꿀 수 있습니다.

- 감지: `navigator.languages` 를 앞에서부터 훑어 `ko` 로 시작하는 태그가 있으면 한국어.
  ⚠️ `navigator.language` **하나만 보면** "영어를 1순위로 두고 한국어도 쓰는" 기기를 놓칩니다.
- ⚠️ **저장 키는 네 페이지가 모두 `rereminder-lang` 으로 같아야 합니다.** 다르면 소개
  페이지에서 고른 언어가 지원·개인정보 페이지로 이어지지 않습니다(예전에 `docs/index.html`
  만 `lang` 을 써서 실제로 끊겨 있었습니다 — 옛 키는 지금도 읽어서 선택을 잇습니다).
- ⚠️ **자동 감지 결과는 저장하지 않습니다.** 저장해 버리면 기기 언어를 바꿔도 첫 방문에
  감지한 언어가 계속 따라옵니다. 저장은 사용자가 버튼을 눌렀을 때만.
- 글을 넣는 방식은 페이지마다 다릅니다 — `docs/index.html` 은 `data-i18n` 키 + 사전(80개),
  나머지 셋은 두 언어를 **둘 다 마크업에 두고** `data-lang` 으로 한쪽만 보여줍니다.
  후자는 첫 그림부터 맞는 언어가 나오도록 `<head>`(클립 랜딩) 또는 body 클래스로 가릅니다.
- `?lang=en` / `?lang=ko` 로 특정 언어 링크를 만들 수 있습니다(클립 랜딩만).
  영어 페이지를 그대로 공유할 때 상대의 기기 언어에 휘둘리지 않습니다.
- ⚠️ **클립 랜딩의 인페이지 데모는 자기 사전(`STR`)을 따로 가집니다.** 페이지가 언어를 바꾸면
  `langchange` 이벤트로 알려 주는 구조라, 전환 코드를 건드릴 때 이 이벤트를 빼먹지 마세요.
  데모의 알약 라벨(5분 / 1분 전)은 **값에서 만들어 냅니다** — 마크업에 박아 두면 언어를 못 따라갑니다.

## 라이트/다크

클립 랜딩도 `docs/support.html`·`privacy.html` 과 같은 규칙입니다 — **라이트가 기본이고
다크는 기기 설정을 따릅니다**(토글 없음). 색은 `:root` 토큰 한 벌 + `prefers-color-scheme`
한 벌이고, 하드코딩된 값은 두지 않습니다.

⚠️ 데모에서 주의할 두 가지:
- **흰 핸들은 밝은 바탕에서 묻힙니다.** `.demo-handle` 에 `--handle-edge` 테두리를 줘서
  라이트에서만 윤곽이 생기게 했습니다.
- **종 주황은 흰 바탕에서 `#FF9F0A` 로는 대비가 모자랍니다.** 라이트에서는 `#B45309` 를 씁니다.

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
