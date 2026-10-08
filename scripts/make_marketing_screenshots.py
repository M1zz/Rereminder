#!/usr/bin/env python3
"""마케팅 스크린샷 목업 생성: HTML 생성 → 헤드리스 Chrome 렌더링.

슬라이드마다 layout 이 달라 배치가 다양함:
  hero-bleed  : 헤드라인 상단 중앙 + 정면 대형 폰, 하단 블리드
  left-text   : 좌측 정렬 텍스트 + 오른쪽으로 기운 폰
  text-bottom : 폰 상단 + 텍스트 하단
  flat-rotate : 평면 회전(-5°) 폰, 하단 블리드
  dark        : 다크 배경 반전 + 정면 폰
"""
import subprocess, sys, pathlib

# 사용법: python3 scripts/make_marketing_screenshots.py [언어 ...]   (없으면 전부)
# 입력: docs/screenshots/raw/<언어>/  출력: docs/screenshots/marketing/<언어>/  (1242×2688)

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs/screenshots/raw"             # scripts/capture_screenshots.sh 가 찍은 원본
OUT = ROOT / "docs/screenshots/marketing"       # 제출본 — DeployBar 가 언어별 폴더를 읽어 올린다
WORK = ROOT / "build/marketing-html"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688                               # 이 앱의 ASC 제출 규격

# (원본 파일, 레이아웃) — 순서가 곧 스토어에 보이는 순서다
SLIDES = [
    ("01-dial.png",           "hero-bleed"),
    ("02-running.png",        "left-text"),
    ("03-session.png",        "text-bottom"),
    ("04-sessionRunning.png", "dark"),
]

# 언어별 (헤드라인, 서브카피) — 슬라이드 순서와 같다.
# 기능 이름이 아니라 "무엇이 좋아지나"를 쓴다. 세션 모드 이름은 앱 안 번역과 같은 말을 쓸 것.
COPY = {
    "ko": [
        ("끝나기 전에<br>여러 번 알려 줘요", "10분 전, 5분 전, 1분 전. 원하는 때마다"),
        ("다음 알림까지<br>한눈에", "구간마다 남은 시간이 따로 줄어요"),
        ("발표·수업을<br>구간으로 나눠요", "구간 이름과 대본까지 함께 적어 둬요"),
        ("지금 할 말이<br>화면에 떠요", "세션 모드로 흐름을 놓치지 않게"),
    ],
    "en": [
        ("Get warned<br>before time runs out", "10, 5 and 1 minute before. Whenever you like."),
        ("See the next<br>alert at a glance", "Each section counts down on its own"),
        ("Split your talk<br>into sections", "Name each part and add your notes"),
        ("Your notes,<br>right on time", "Session Mode keeps you on track"),
    ],
    "ja": [
        ("終わる前に<br>何度でもお知らせ", "10分前、5分前、1分前。好きなタイミングで"),
        ("次のアラートまで<br>ひと目でわかる", "区間ごとに残り時間をカウント"),
        ("発表も授業も<br>区間に分けて", "区間の名前と原稿もいっしょに"),
        ("いま話すことが<br>画面に出る", "セッションモードで流れを見失わない"),
    ],
    "zh-Hans": [
        ("结束之前<br>多次提醒你", "提前 10 分钟、5 分钟、1 分钟，随你设定"),
        ("离下次提醒还有多久<br>一眼看清", "每个分段单独倒计时"),
        ("把演讲和课程<br>分成几段", "为每段命名，还能写下讲稿"),
        ("该说什么<br>屏幕上就有", "分段模式让你不跑题"),
    ],
    "zh-Hant": [
        ("結束之前<br>多次提醒你", "提前 10 分鐘、5 分鐘、1 分鐘，隨你設定"),
        ("離下次提醒還有多久<br>一眼看清", "每個分段各自倒數"),
        ("把簡報和課程<br>分成幾段", "為每段命名，還能寫下講稿"),
        ("該說什麼<br>螢幕上就有", "分段模式讓你不離題"),
    ],
    "de": [
        ("Vorgewarnt,<br>bevor die Zeit abläuft", "10, 5 und 1 Minute vorher – wann du willst"),
        ("Die nächste Erinnerung<br>auf einen Blick", "Jeder Abschnitt zählt für sich herunter"),
        ("Vortrag und Unterricht<br>in Abschnitten", "Mit Namen und Skript für jeden Teil"),
        ("Dein Skript<br>zur rechten Zeit", "Der Session-Modus hält dich im Takt"),
    ],
    "fr": [
        ("Prévenu avant<br>la fin du temps", "10, 5 et 1 minute avant. Quand vous voulez."),
        ("La prochaine alerte<br>en un coup d'œil", "Chaque partie a son propre décompte"),
        ("Découpez votre exposé<br>en parties", "Nommez chaque partie et ajoutez vos notes"),
        ("Vos notes<br>au bon moment", "Le mode Séance garde le rythme"),
    ],
    "es": [
        ("Avisos antes<br>de que acabe el tiempo", "10, 5 y 1 minuto antes. Cuando quieras."),
        ("El próximo aviso<br>de un vistazo", "Cada sección tiene su propia cuenta"),
        ("Divide tu charla<br>en secciones", "Ponles nombre y añade tu guion"),
        ("Tu guion,<br>en el momento justo", "El modo sesión te mantiene a tiempo"),
    ],
    "pt-BR": [
        ("Avisos antes<br>do tempo acabar", "10, 5 e 1 minuto antes. Quando quiser."),
        ("O próximo aviso<br>num relance", "Cada etapa tem sua própria contagem"),
        ("Divida sua fala<br>em etapas", "Dê nome a cada uma e anote o roteiro"),
        ("Seu roteiro<br>na hora certa", "O Modo Sessão mantém você no ritmo"),
    ],
    "it": [
        ("Avvisi prima<br>che il tempo finisca", "10, 5 e 1 minuto prima. Quando vuoi."),
        ("Il prossimo avviso<br>a colpo d'occhio", "Ogni sezione ha il suo conto alla rovescia"),
        ("Dividi il discorso<br>in sezioni", "Dai un nome a ognuna e aggiungi il copione"),
        ("Il tuo copione<br>al momento giusto", "La modalità Sessione ti tiene in tempo"),
    ],
    "pt-PT": [
        ("Vários avisos<br>antes do fim", "10, 5 e 1 minuto antes. À sua escolha."),
        ("Veja o próximo<br>alerta de relance", "Cada etapa tem a sua contagem"),
        ("Divida a palestra<br>em etapas", "Dê nome a cada parte e junte as suas notas"),
        ("As suas notas,<br>no momento certo", "O Modo Sessão mantém-no no rumo certo"),
    ],
    "ru": [
        ("Сигнал до того,<br>как время выйдет", "За 10, 5 и 1 минуту. Как вам удобно."),
        ("Следующий сигнал<br>сразу на виду", "У каждого этапа свой отсчёт"),
        ("Разбейте речь<br>на этапы", "Назовите части и добавьте заметки"),
        ("Ваши заметки —<br>точно вовремя", "Режим этапов держит вас в графике"),
    ],
    "cs": [
        ("Upozornění dřív,<br>než čas vyprší", "10, 5 a 1 minutu předem. Kdykoli chcete."),
        ("Další upozornění<br>na první pohled", "Každý úsek odpočítává zvlášť"),
        ("Rozdělte prezentaci<br>na úseky", "Pojmenujte části a přidejte poznámky"),
        ("Vaše poznámky<br>přesně včas", "Režim sezení vás udrží v tempu"),
    ],
    "da": [
        ("Få besked, før<br>tiden løber ud", "10, 5 og 1 minut før. Når du vil."),
        ("Se næste påmindelse<br>med et blik", "Hvert afsnit tæller ned for sig"),
        ("Del dit oplæg<br>op i afsnit", "Navngiv hver del, og tilføj noter"),
        ("Dine noter,<br>lige til tiden", "Sessionstilstand holder dig på sporet"),
    ],
    "el": [
        ("Ειδοποίηση πριν<br>τελειώσει ο χρόνος", "10, 5 και 1 λεπτό πριν. Όποτε θέλετε."),
        ("Η επόμενη ειδοποίηση<br>με μια ματιά", "Κάθε ενότητα μετρά αντίστροφα μόνη της"),
        ("Χωρίστε την ομιλία<br>σε ενότητες", "Ονομάστε κάθε μέρος, κρατήστε σημειώσεις"),
        ("Οι σημειώσεις σας,<br>την ώρα που πρέπει", "Η Λειτουργία συνεδρίας σάς κρατά σε ρυθμό"),
    ],
    "fi": [
        ("Muistutus ennen<br>kuin aika loppuu", "10, 5 ja 1 minuutti ennen. Milloin haluat."),
        ("Seuraava muistutus<br>yhdellä silmäyksellä", "Jokainen osio laskee omaa aikaansa"),
        ("Jaa esityksesi<br>osioihin", "Nimeä osat ja lisää muistiinpanot"),
        ("Muistiinpanosi<br>oikealla hetkellä", "Sessiotila pitää sinut aikataulussa"),
    ],
    "id": [
        ("Diingatkan sebelum<br>waktu habis", "10, 5, dan 1 menit sebelumnya. Kapan pun Anda mau."),
        ("Lihat peringatan<br>berikutnya sekilas", "Setiap bagian menghitung mundur sendiri"),
        ("Bagi presentasi<br>jadi beberapa bagian", "Beri nama tiap bagian dan tambahkan catatan"),
        ("Catatan Anda,<br>tepat pada waktunya", "Mode Sesi menjaga Anda tetap di jalur"),
    ],
    "nb": [
        ("Bli varslet før<br>tiden er ute", "10, 5 og 1 minutt før. Når du vil."),
        ("Se neste varsel<br>med et blikk", "Hver del teller ned for seg"),
        ("Del foredraget<br>inn i deler", "Gi hver del et navn og legg til notater"),
        ("Notatene dine,<br>akkurat i tide", "Øktmodus holder deg på sporet"),
    ],
    "nl": [
        ("Gewaarschuwd vóór<br>de tijd om is", "10, 5 en 1 minuut van tevoren. Wanneer jij wilt."),
        ("Zie de volgende<br>melding meteen", "Elk onderdeel telt apart af"),
        ("Verdeel je verhaal<br>in onderdelen", "Geef elk deel een naam en notities"),
        ("Je notities,<br>precies op tijd", "Sessiemodus houdt je op koers"),
    ],
    "pl": [
        ("Ostrzeżenie, zanim<br>czas się skończy", "10, 5 i 1 minuta przed końcem. Kiedy chcesz."),
        ("Następny alert<br>na pierwszy rzut oka", "Każdy etap odlicza osobno"),
        ("Podziel wystąpienie<br>na etapy", "Nazwij każdą część i dodaj notatki"),
        ("Twoje notatki<br>w samą porę", "Tryb sesji trzyma Cię w planie"),
    ],
    "sv": [
        ("Förvarnad innan<br>tiden är ute", "10, 5 och 1 minut före. När du vill."),
        ("Se nästa påminnelse<br>med en blick", "Varje avsnitt räknar ner för sig"),
        ("Dela upp ditt tal<br>i avsnitt", "Namnge varje del och lägg till anteckningar"),
        ("Ditt manus,<br>precis i tid", "Sessionsläge håller dig på banan"),
    ],
    "th": [
        ("รู้ตัวก่อน<br>ที่เวลาจะหมด", "ก่อนจบ 10, 5 และ 1 นาที ตั้งได้ตามใจ"),
        ("เห็นการเตือนถัดไป<br>ได้ในแวบเดียว", "แต่ละช่วงนับถอยหลังแยกกัน"),
        ("แบ่งการพูด<br>ออกเป็นช่วงๆ", "ตั้งชื่อแต่ละช่วงและจดโน้ตไว้"),
        ("บทพูดของคุณ<br>มาตรงเวลา", "โหมดเซสชันช่วยให้พูดตามแผน"),
    ],
    "tr": [
        ("Süre dolmadan<br>önce haber al", "10, 5 ve 1 dakika kala. İstediğin zaman."),
        ("Sıradaki uyarıyı<br>bir bakışta gör", "Her bölüm kendi süresini sayar"),
        ("Konuşmanı<br>bölümlere ayır", "Her kısma ad ver, notlarını ekle"),
        ("Notların<br>tam zamanında", "Oturum Modu seni rotada tutar"),
    ],
    "vi": [
        ("Được báo trước<br>khi hết giờ", "Trước 10, 5 và 1 phút. Tùy bạn chọn."),
        ("Lần báo tiếp theo<br>chỉ trong nháy mắt", "Mỗi phần tự đếm ngược riêng"),
        ("Chia bài nói<br>thành từng phần", "Đặt tên từng phần và thêm ghi chú"),
        ("Ghi chú của bạn,<br>hiện đúng lúc", "Chế độ Phiên giúp bạn đi đúng nhịp"),
    ],
}

# 한자권은 글자가 빽빽해 같은 크기면 더 커 보이고, 라틴 문자는 단어가 길어 줄이 넘친다.
HEADLINE_PX = {"ko": 100, "ja": 92, "zh-Hans": 96, "zh-Hant": 96, "th": 92}
LATIN_HEADLINE_PX = 84

BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
body {{ background:#f4f4f5; font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", sans-serif; position:relative; }}
.headline {{ font-size:100px; font-weight:800; color:#141416; letter-spacing:-2px; line-height:1.25; }}
.sub {{ font-size:52px; font-weight:500; color:#9a9aa0; letter-spacing:-1px; }}
.phone {{ background:#17171a; border-radius:116px; border:3px solid #3a3a3e; padding:25px;
  box-shadow: 60px 90px 120px rgba(0,0,0,.28), 20px 30px 50px rgba(0,0,0,.18); }}
.phone img {{ width:100%; display:block; border-radius:92px; }}
"""

LAYOUTS = {
    # 1) 정면 대형, 하단 블리드
    "hero-bleed": """
.headline { text-align:center; margin-top:290px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:1000px; }
""",
    # 2) 좌측 정렬 텍스트 + 오른쪽 기울기, 오른쪽 블리드
    "left-text": """
.headline { text-align:left; margin:300px 0 0 110px; }
.sub { text-align:left; margin:48px 0 0 114px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:300px; top:990px; }
.phone { width:840px; transform:rotateY(16deg) rotateX(2deg); }
""",
    # 3) 폰 상단, 텍스트 하단
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:170px; }
.phone { width:880px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:120px; padding:0 70px; }
.sub { text-align:center; margin-top:48px; }
""",
    # 4) 평면 회전, 좌측 치우침 + 하단 블리드
    "flat-rotate": """
.headline { text-align:center; margin-top:270px; padding:0 70px; }
.sub { text-align:center; margin-top:52px; }
.wrap { position:absolute; left:120px; top:1010px; }
.phone { width:1010px; transform:rotate(-6deg); }
""",
    # 5) 다크 배경 반전 + 정면
    "dark": """
body { background:#131316; }
.headline { color:#f5f5f7; text-align:center; margin-top:290px; padding:0 70px; }
.sub { color:#77777d; text-align:center; margin-top:52px; }
.wrap { display:flex; justify-content:center; margin-top:150px; }
.phone { width:930px; border-color:#48484e;
  box-shadow: 0 0 160px rgba(80,140,255,.22), 40px 70px 110px rgba(0,0,0,.55); }
""",
}

# text-bottom 은 폰이 먼저 오는 DOM 순서
BODY_TEXT_FIRST = '<div class="headline">{headline}</div><div class="sub">{sub}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
BODY_PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{headline}</div><div class="sub">{sub}</div>'

HTML = """<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>
{base}{layout}
.headline {{ font-size:{headline_px}px; }}
:lang(zh-Hant) body {{ font-family:-apple-system, "PingFang TC", sans-serif; }}
:lang(zh-Hans) body {{ font-family:-apple-system, "PingFang SC", sans-serif; }}
:lang(ja) body {{ font-family:-apple-system, "Hiragino Sans", sans-serif; }}
:lang(th) body {{ font-family:-apple-system, "Thonburi", sans-serif; }}
</style></head><body>{body}</body></html>"""


def render(lang):
    out_dir = OUT / lang
    out_dir.mkdir(parents=True, exist_ok=True)
    WORK.mkdir(parents=True, exist_ok=True)
    for (fname, layout), (headline, sub) in zip(SLIDES, COPY[lang]):
        src = RAW / lang / fname
        if not src.exists():
            sys.exit(f"원본 없음: {src} — 먼저 scripts/capture_screenshots.sh {lang}")
        body_tpl = BODY_PHONE_FIRST if layout == "text-bottom" else BODY_TEXT_FIRST
        body = body_tpl.format(headline=headline, sub=sub, img=src.as_uri())
        html_path = WORK / f"{lang}-{fname.replace('.png', '.html')}"
        html_path.write_text(HTML.format(
            lang=lang, base=BASE_CSS, layout=LAYOUTS[layout], body=body,
            headline_px=HEADLINE_PX.get(lang, LATIN_HEADLINE_PX)), encoding="utf-8")
        out_png = out_dir / fname
        out_png.unlink(missing_ok=True)
        # ⚠️ 기계가 바쁘면 Chrome 이 그림을 다 쓴 뒤 정리 단계에서 죽어(Teardown watchdog) 0 이 아닌 값을 낸다.
        #    끝 코드가 아니라 그림이 실제로 써졌는지로 판정한다.
        subprocess.run([CHROME, "--headless=new", f"--screenshot={out_png}",
                        f"--window-size={W},{H}", "--force-device-scale-factor=1",
                        "--hide-scrollbars", "--disable-gpu", html_path.as_uri()],
                       capture_output=True)
        if not out_png.exists() or out_png.stat().st_size == 0:
            sys.exit(f"Chrome 이 그리지 못했다: {out_png}")
        print(f"rendered {out_png.relative_to(ROOT)}")


if __name__ == "__main__":
    for lang in (sys.argv[1:] or COPY):
        render(lang)
