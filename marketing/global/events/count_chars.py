#!/usr/bin/env python3
"""인앱 이벤트 문구 글자 수 검사. 한도: 이름 30 · 짧은 설명 50 · 긴 설명 120 (Apple 공식).
사용: python3 -I marketing/global/events/count_chars.py [--md]
--md 를 주면 IN_APP_EVENTS.md 에 붙일 표를 찍는다. 넘친 칸이 있으면 종료 코드 1."""
import json, sys, unicodedata, pathlib
LIMITS = (30, 50, 120)
ORDER = "ko en ja zh-Hans zh-Hant de fr es pt-BR pt-PT it ru cs da el fi id nb nl pl sv th tr vi".split()
data = json.loads((pathlib.Path(__file__).parent / "copy.json").read_text(encoding="utf-8"))
bad = 0
md = "--md" in sys.argv
for ev, locs in data.items():
    assert sorted(locs) == sorted(ORDER), (ev, set(ORDER) ^ set(locs))
    if md:
        print(f"\n#### `{ev}`\n\n| 로케일 | 이벤트 이름 | 자 | 짧은 설명 | 자 | 긴 설명 | 자 |\n|---|---|---|---|---|---|---|")
    for loc in ORDER:
        vals = [unicodedata.normalize("NFC", v) for v in locs[loc]]
        n = [len(v) for v in vals]
        for v, k, lim in zip(vals, n, LIMITS):
            if k > lim:
                bad += 1
                print(f"OVER {ev} {loc} {k}/{lim}: {v}", file=sys.stderr)
            if any("가" <= c <= "힣" for c in v) and loc != "ko":
                bad += 1
                print(f"HANGUL {ev} {loc}: {v}", file=sys.stderr)
        if md:
            print(f"| {loc} | {vals[0]} | {n[0]} | {vals[1]} | {n[1]} | {vals[2]} | {n[2]} |")
        else:
            print(f"{ev:12} {loc:8} {n[0]:3} {n[1]:3} {n[2]:4}")
sys.exit(1 if bad else 0)
