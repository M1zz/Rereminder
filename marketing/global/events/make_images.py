"""인앱 이벤트 그림을 docs/screenshots/raw 에서 잘라 만든다 (글자·로고·테두리·그라데이션 없음, 앱 화면만).
사용: python3 marketing/global/events/make_images.py docs/screenshots/raw marketing/global/events
스크린샷을 다시 찍으면 이것을 다시 돌린다. 자르는 좌표는 1320×2868 원본 기준."""
import sys
from PIL import Image
raw, out = sys.argv[1], sys.argv[2]
import os
LOCS="ko en ja zh-Hans zh-Hant de fr es pt-BR pt-PT it ru cs da el fi id nb nl pl sv th tr vi".split()
BLACK=(0,0,0)
def load(loc,name): return Image.open(f"{raw}/{loc}/{name}").convert("RGB")
def fit(im, w, h):
    s=min(w/im.width, h/im.height); return im.resize((round(im.width*s), round(im.height*s)), Image.LANCZOS)
def details(src, box, path):
    c=src.crop(box)
    canvas=Image.new("RGB",(1320,2347),BLACK)
    canvas.paste(c,(0,(2347-c.height)//2))
    canvas.resize((1080,1920),Image.LANCZOS).save(path, optimize=True)
def card(parts, path):
    W,H=1920,1080; canvas=Image.new("RGB",(W,H),BLACK)
    slot=W//len(parts)
    for i,(im,maxw,maxh) in enumerate(parts):
        f=fit(im,maxw,maxh)
        canvas.paste(f,(i*slot+(slot-f.width)//2,(H-f.height)//2))
    canvas.save(path, optimize=True)
os.makedirs(f"{out}/common",exist_ok=True)
idle=load("en","01-dial.png").crop((60,740,1260,1960))
run=load("en","02-running.png").crop((60,610,1260,1810))
card([(idle,860,900),(run,860,900)], f"{out}/common/card-1920x1080.png")
details(load("en","02-running.png"),(0,560,1320,2440), f"{out}/common/details-1080x1920.png")
for loc in LOCS:
    d=f"{out}/talk-season/{loc}"; os.makedirs(d,exist_ok=True)
    s4=load(loc,"04-sessionRunning.png")
    card([(s4.crop((180,590,1140,1560)),860,900),(s4.crop((93,1715,1227,2535)),880,900)], f"{d}/card-1920x1080.png")
    details(load(loc,"03-session.png"),(0,560,1320,2460), f"{d}/details-1080x1920.png")
print("ok")
