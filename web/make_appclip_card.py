#!/usr/bin/env python3
"""App Clip 카드 헤더 이미지(1800×1200) 생성.

App Store Connect 요구사항:
  - 1800 × 1200 px (3:2), PNG/JPG, 투명도 불가
  - 카드에는 제목·부제·액션 버튼이 이미지 아래에 따로 표시되므로
    이미지에는 글자를 넣지 않고 앱을 알아볼 수 있는 그림만 둔다.
    (글자를 넣으면 언어별로 다시 만들어야 하고, 카드에서 잘릴 수 있다)

앱 화면과 같은 시각 언어를 쓴다:
  배경 검정 / 트랙 회색 / 진행 호 액센트 블루 / 알림 지점 주황 종 / 핸들 흰 점

실행: python3 web/make_appclip_card.py
"""

from PIL import Image, ImageDraw
import math
import pathlib

W, H = 1800, 1200
SUPERSAMPLE = 3  # 안티에일리어싱: 3배로 그린 뒤 축소

BG_TOP = (10, 10, 12)
BG_BOTTOM = (0, 0, 0)
TRACK = (72, 72, 74)
ACCENT = (0, 122, 255)      # ThemeManager 기본 테마 Ocean
MARKER = (255, 149, 0)      # DSColor.marker
WHITE = (255, 255, 255)

# 30분 타이머 = 180° (앱과 동일하게 1° = 10초)
TOTAL_DEG = 180.0
# 10분·5분·1분 전 → 60°, 30°, 6°
ALERT_DEGS = [60.0, 30.0, 6.0]


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def polar(cx, cy, r, deg):
    """12시 방향을 0°로 두고 시계방향."""
    rad = math.radians(deg - 90)
    return cx + r * math.cos(rad), cy + r * math.sin(rad)


def draw_bell(d, cx, cy, r, scale):
    """종 아이콘 — SF Symbols bell.fill 을 단순화한 형태."""
    body_w = r * 1.05
    body_h = r * 1.05
    top = cy - body_h * 0.55
    # 종 몸통 (위가 둥글고 아래가 벌어진 형태)
    d.pieslice(
        [cx - body_w * 0.5, top, cx + body_w * 0.5, top + body_h * 0.95],
        180, 360, fill=WHITE,
    )
    d.polygon(
        [
            (cx - body_w * 0.5, top + body_h * 0.47),
            (cx + body_w * 0.5, top + body_h * 0.47),
            (cx + body_w * 0.62, top + body_h * 0.80),
            (cx - body_w * 0.62, top + body_h * 0.80),
        ],
        fill=WHITE,
    )
    # 아래 테두리
    d.rounded_rectangle(
        [cx - body_w * 0.66, top + body_h * 0.74,
         cx + body_w * 0.66, top + body_h * 0.86],
        radius=body_h * 0.06, fill=WHITE,
    )
    # 손잡이
    d.ellipse(
        [cx - body_w * 0.11, top - body_h * 0.12,
         cx + body_w * 0.11, top + body_h * 0.06],
        fill=WHITE,
    )
    # 추
    d.ellipse(
        [cx - body_w * 0.17, top + body_h * 0.88,
         cx + body_w * 0.17, top + body_h * 1.16],
        fill=WHITE,
    )


def render():
    w, h = W * SUPERSAMPLE, H * SUPERSAMPLE
    img = Image.new("RGB", (w, h), BG_BOTTOM)
    d = ImageDraw.Draw(img)

    # 은은한 세로 그라데이션 (완전 단색보다 카드에서 덜 밋밋하다)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(BG_TOP, BG_BOTTOM, y / h))

    cx, cy = w / 2, h / 2
    # 카드에서 작게 표시되므로 다이얼을 화면 높이의 40%까지 키운다.
    # (종 노브가 링 밖으로 나가므로 그만큼 여유를 남긴 값)
    radius = h * 0.37
    line_w = radius * 2 * 0.083          # 앱과 같은 비율 (지름의 8.3%)
    box = [cx - radius, cy - radius, cx + radius, cy + radius]

    # 트랙
    d.arc(box, 0, 360, fill=TRACK, width=round(line_w))

    # 진행 호 (12시부터 시계방향) — 끝을 둥글게 하려고 양 끝에 원을 덧그린다
    d.arc(box, -90, -90 + TOTAL_DEG, fill=ACCENT, width=round(line_w))
    for deg in (0.0, TOTAL_DEG):
        px, py = polar(cx, cy, radius, deg)
        d.ellipse([px - line_w / 2, py - line_w / 2,
                   px + line_w / 2, py + line_w / 2], fill=ACCENT)

    # 시간 설정 핸들 (흰 점)
    hx, hy = polar(cx, cy, radius, TOTAL_DEG)
    hr = line_w * 0.45
    d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=WHITE)

    # 알림 지점 (주황 원 + 종)
    knob_r = line_w * 0.80
    for deg in ALERT_DEGS:
        kx, ky = polar(cx, cy, radius, deg)
        d.ellipse([kx - knob_r, ky - knob_r, kx + knob_r, ky + knob_r], fill=MARKER)
        draw_bell(d, kx, ky, knob_r * 0.62, SUPERSAMPLE)

    return img.resize((W, H), Image.LANCZOS)


if __name__ == "__main__":
    out = pathlib.Path(__file__).parent / "appclip-card-1800x1200.png"
    im = render()
    im.save(out, "PNG", optimize=True)
    print(f"저장: {out}  ({im.size[0]}×{im.size[1]}, mode={im.mode})")
