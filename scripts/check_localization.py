#!/usr/bin/env python3
"""Localizable.xcstrings 위생 검사 — predeploy/CI 게이트.

소스 언어가 en 인 카탈로그 기준으로:
  1. ko/ja 번역이 비었거나 state=new 로 방치된 키 → 실패
  2. extractionState=stale 키 (코드에서 제거됐는데 카탈로그에 남은 것) → 실패
  3. 키(=영어 소스)에 한글이 섞인 것 (소스 문자열 하드코딩 실수) → 실패

의도적으로 번역하지 않는 키는 ALLOW_UNTRANSLATED 에 추가한다.
"""
import json
import pathlib
import re
import sys

CATALOGS = [
    "Rereminder/Localizable.xcstrings",
]
LANGS = ("ko", "ja")

# 번역 없이 두는 게 맞는 키 (고유명사·포맷 전용 등)
ALLOW_UNTRANSLATED: set[str] = {
    "Instagram DM (@lee25_ios)",  # 계정 핸들 — 고유명사라 번역하지 않는다
}

HANGUL = re.compile(r"[가-힣]")


def check(path: str) -> list[str]:
    errors: list[str] = []
    data = json.loads(pathlib.Path(path).read_text())
    for key, entry in data.get("strings", {}).items():
        if key in ALLOW_UNTRANSLATED or entry.get("shouldTranslate") is False:
            continue
        if entry.get("extractionState") == "stale":
            errors.append(f"[stale] {key!r} — 코드에서 사라진 키, 카탈로그에서 제거할 것")
            continue
        if HANGUL.search(key):
            errors.append(f"[source-ko] {key!r} — 소스(en) 키에 한글 포함, 영어 키로 바꿀 것")
        locs = entry.get("localizations", {})
        if not locs:
            # localizations 자체가 없으면 전체 미번역 (소스 문자열 그대로 노출)
            errors.append(f"[untranslated] {key!r} — ko/ja 번역 없음")
            continue
        for lang in LANGS:
            unit = locs.get(lang, {}).get("stringUnit", {})
            if not unit.get("value"):
                errors.append(f"[untranslated:{lang}] {key!r}")
            elif unit.get("state") == "new":
                errors.append(f"[needs-review:{lang}] {key!r} — state=new, 검수 후 translated 로 승격할 것")
    return errors


def main() -> int:
    all_errors: list[str] = []
    for catalog in CATALOGS:
        all_errors += [f"{catalog}: {e}" for e in check(catalog)]
    if all_errors:
        print(f"❌ 다국어 검사 실패 — {len(all_errors)}건")
        for err in all_errors:
            print("  " + err)
        return 1
    print("✅ 다국어 검사 통과")
    return 0


if __name__ == "__main__":
    sys.exit(main())
