# 워치 앱스토어 스크린샷

App Store Connect 의 watchOS 스크린샷 슬롯에 올리는 원본. 언어별로 한 벌씩이다.

- **규격**: 416 × 496 px — Apple Watch Series 10/11 (46mm). ASC 가 문서화한 워치 규격이라
  다른 크기로 자동 축소된다.
  ⚠️ Ultra 3(49mm) 시뮬레이터는 **422 × 514** 를 뱉는데 이건 ASC 규격 표에 없다. 쓰지 말 것.
- **기기**: Apple Watch Series 11 (46mm), watchOS 26.2 시뮬레이터
- **언어**: 10개 — `ko` `en` `ja` `zh-Hans` `zh-Hant` `de` `fr` `es` `pt-BR` `it`.
  같은 화면 같은 순서. 새 언어를 늘리면 폴더도 는다(`deploy.env` 의 `LOCALES` 참고).

| 파일 | 화면 | 파는 것 |
|---|---|---|
| `01-duration.png` | 시간 설정 다이얼 | 손목에서 바로 건다 |
| `02-prealerts.png` | 예비 알림 3개(1·3·10분) 선택 | **이 앱의 이유** — 끝나기 전에 여러 번 |
| `03-running.png` | 실행 중 둥근 사각 링 (구간 4개) | 기본 시계 앱과 다른 화면 |
| `04-finished.png` | 종료 + 확인 버튼 | 확인할 때까지 알린다 |

## 다시 찍는 법

```bash
scripts/capture_watch_screenshots.sh            # 10개 언어 전부
scripts/capture_watch_screenshots.sh de fr      # 일부만
```

화면 상태는 DEBUG 빌드의 `WatchScreenshotScene`(`RereminderWatch/WatchScreenshotScene.swift`)이
실행 인자 `-screenshotScene <duration|prealerts|running|finished>` 로 세운다. 장면이 걸리면 알림 권한을
요청하지 않아 권한 창·종료 배너가 끼지 않는다. 끝난 화면은 4초 타이머라 기다릴 필요가 없다.

- ⚠️ **워치 시뮬레이터를 아이폰과 페어링해 둘 것**(`xcrun simctl pair <워치> <아이폰>`).
  안 하면 상태 표시줄에 **빨간 "폰 연결 끊김" 아이콘**이 붙어 그대로 스토어에 올라간다.
  스크립트는 페어링된 기기만 고르고 짝 아이폰도 부팅한다.
- ⚠️ 워치 화면은 좁다. 첫 화면 제목이 길면 **시계와 겹친다**(프랑스어·스페인어·포르투갈어·이탈리아어
  "타이머 시간"이 그랬다 — 지금은 "Durée" 처럼 한 단어). 번역을 고치면 이 스크립트로 확인할 것.
