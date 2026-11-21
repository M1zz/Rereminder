#!/usr/bin/env python3
"""docs/ 의 여러 언어 페이지(index·privacy·support)에서 언어마다 따로 된 페이지를 만든다.

원본은 docs/ 최상단의 세 파일이다. 여기에는 모든 언어가 한 파일에 들어 있고 브라우저 언어로 골라 보인다
(앱 안의 링크·x-default 가 이 주소다). 스토어의 언어별 칸은 docs/<lang>/ 를 가리키므로,
원본을 고친 뒤에는 이 스크립트를 다시 돌려 언어 폴더를 새로 만든다.

    python3 scripts/build-lang-pages.py

- privacy·support: 그 언어의 <div data-lang="…"> 블록만 남긴다.
- index: DeployBar 의 공용 생성기(sitegen.py)가 docs/site/<lang>.json 으로 언어마다 만든다.
  이 스크립트는 그 결과에 오른쪽→왼쪽 언어(RTL)의 dir 만 단다 — sitegen 을 돌린 뒤 이것을 돌린다.
- RTL 언어(ar)는 원본에서 <div data-lang="ar" dir="rtl"> 이고, 언어 페이지에서는 <html dir="rtl"> 이 된다.
"""
import html, pathlib, re

DOCS = pathlib.Path(__file__).resolve().parent.parent / 'docs'
BASE = 'https://m1zz.github.io/Rereminder/'
LANGS = ['ko', 'en', 'ja', 'zh-Hans', 'zh-Hant', 'de', 'fr', 'es', 'pt-BR', 'pt-PT', 'it', 'ru', 'cs', 'da', 'el', 'fi', 'id', 'nb', 'nl', 'pl', 'sv', 'th', 'tr', 'vi', 'ar']
NAMES = {'ko': '한국어', 'en': 'English', 'ja': '日本語', 'zh-Hans': '简体中文', 'zh-Hant': '繁體中文',
         'de': 'Deutsch', 'fr': 'Français', 'es': 'Español', 'pt-BR': 'Português (Brasil)',
         'pt-PT': 'Português (Portugal)', 'it': 'Italiano', 'ru': "Русский", 'cs': "Čeština", 'da': "Dansk", 'el': "Ελληνικά", 'fi': "Suomi", 'id': "Bahasa Indonesia", 'nb': "Norsk bokmål", 'nl': "Nederlands", 'pl': "Polski", 'sv': "Svenska", 'th': "ไทย", 'tr': "Türkçe", 'vi': "Tiếng Việt", 'ar': "العربية"}
# privacy·support 머리·꼬리의 메뉴 이름
NAV = {
    'en': ('Home', 'Support', 'Privacy'),
    'ko': ('홈', '지원', '개인정보처리방침'),
    'ja': ('ホーム', 'サポート', 'プライバシー'),
    'zh-Hans': ('首页', '支持', '隐私'),
    'zh-Hant': ('首頁', '支援', '隱私權'),
    'de': ('Startseite', 'Support', 'Datenschutz'),
    'fr': ('Accueil', 'Assistance', 'Confidentialité'),
    'es': ('Inicio', 'Soporte', 'Privacidad'),
    'pt-BR': ('Início', 'Suporte', 'Privacidade'),
    'pt-PT': ('Início', 'Suporte', 'Privacidade'),
    'it': ('Home', 'Assistenza', 'Privacy'),
    'ru': ("Главная", "Поддержка", "Конфиденциальность"),
    'cs': ("Domů", "Podpora", "Soukromí"),
    'da': ("Forside", "Support", "Privatliv"),
    'el': ("Αρχική", "Υποστήριξη", "Απόρρητο"),
    'fi': ("Etusivu", "Tuki", "Tietosuoja"),
    'id': ("Beranda", "Dukungan", "Privasi"),
    'nb': ("Hjem", "Brukerstøtte", "Personvern"),
    'nl': ("Home", "Support", "Privacy"),
    'pl': ("Start", "Pomoc", "Prywatność"),
    'sv': ("Start", "Support", "Integritet"),
    'th': ("หน้าแรก", "การสนับสนุน", "ความเป็นส่วนตัว"),
    'tr': ("Ana Sayfa", "Destek", "Gizlilik"),
    'vi': ("Trang chủ", "Hỗ trợ", "Quyền riêng tư"),
    'ar': ('الرئيسية', 'الدعم', 'الخصوصية'),
}
RTL = {'ar'}
APP_NAME = {'ko': '두번알림'}


def path_of(page):
    return '' if page == 'index.html' else page


def head_links(page, lang):
    p = path_of(page)
    out = [f'    <link rel="canonical" href="{BASE}{lang}/{p}">']
    out += [f'    <link rel="alternate" hreflang="{l}" href="{BASE}{l}/{p}">' for l in LANGS]
    out.append(f'    <link rel="alternate" hreflang="x-default" href="{BASE}{p}">')
    return '\n'.join(out) + '\n'


def lang_nav(page, lang):
    p = path_of(page)
    cur = ' aria-current="true"'
    links = ''.join(
        f'<a href="../{l}/{p}" hreflang="{l}" lang="{l}"{cur if l == lang else ""}>{NAMES[l]}</a>'
        for l in LANGS)
    return f'    <nav class="lang-links" aria-label="Language">{links}</nav>\n'


def strip_root_head(s):
    # 원본(루트)의 canonical·hreflang 줄은 버리고 언어 주소로 다시 단다
    return re.sub(r'    <link rel="(canonical|alternate)"[^>]*>\n', '', s)


def common(s, page, lang):
    s = strip_root_head(s)
    s = html_tag(s, lang)
    s = s.replace('</head>', head_links(page, lang) + '</head>', 1)
    s = re.sub(r'<nav class="lang-links".*?</nav>\n', lang_nav(page, lang), s, count=1, flags=re.S)
    s = s.replace('href="app-icon.jpeg"', 'href="../app-icon.jpeg"').replace('src="app-icon.jpeg"', 'src="../app-icon.jpeg"')
    s = s.replace(f'<option value="{lang}">', f'<option value="{lang}" selected>')
    return s


def html_tag(s, lang):
    dir_attr = ' dir="rtl"' if lang in RTL else ''
    return re.sub(r'<html lang="[^"]*"(?: dir="[^"]*")?', f'<html lang="{lang}"{dir_attr}', s, count=1)


def set_meta(s, title, desc):
    t, d = html.escape(title, quote=True), html.escape(desc, quote=True)
    s = re.sub(r'<title>.*?</title>', f'<title>{t}</title>', s, count=1)
    s = re.sub(r'(<meta name="description" content=")[^"]*', lambda m: m.group(1) + d, s, count=1)
    s = re.sub(r'(<meta property="og:title" content=")[^"]*', lambda m: m.group(1) + t, s, count=1)
    s = re.sub(r'(<meta property="og:description" content=")[^"]*', lambda m: m.group(1) + d, s, count=1)
    return s


def text_of(fragment):
    return html.unescape(re.sub(r'<[^>]+>', '', fragment)).strip()


def build_doc(page):
    src = (DOCS / page).read_text()
    blocks = {m.group(1): m.group(0) for m in re.finditer(r'^<div data-lang="([^"]+)"[^>]*>\n.*?^</div>\n', src, re.S | re.M)}
    missing = [l for l in LANGS if l not in blocks]
    assert not missing, f'{page}: 언어 블록 없음 {missing}'
    start = src.index('<div class="container">')
    end = src.index('\n<footer>')
    head, foot = src[:start], src[end:]
    foot = re.sub(r'<script>.*?</script>\n', '', foot, flags=re.S)
    for lang in LANGS:
        block = re.sub(r'^<div data-lang="[^"]+"[^>]*>', '<div>', blocks[lang], count=1)
        h1 = text_of(re.search(r'<h1>(.*?)</h1>', block, re.S).group(1))
        lede = text_of(re.search(r'<p class="lede">(.*?)</p>', block, re.S).group(1))
        out = head + '<div class="container">\n\n' + block + '\n</div>\n' + foot
        out = set_meta(out, f'{h1} – {APP_NAME.get(lang, "Rereminder")}', lede)
        home, support, privacy = NAV[lang]
        out = (out.replace('>Home</a>', f'>{home}</a>').replace('>Support</a>', f'>{support}</a>')
                  .replace('>Privacy</a>', f'>{privacy}</a>'))
        out = common(out, page, lang)
        nav_js = ('<script>\ndocument.getElementById(\'lang-select\').addEventListener(\'change\', function (e) {\n'
                  f"    location.href = '../' + e.target.value + '/{page}';\n}});\n</script>\n")
        out = out.replace('</body>', nav_js + '</body>', 1)
        write(lang, page, out)


def mark_index_rtl():
    """sitegen 이 만든 소개 페이지에 RTL 언어의 방향을 단다(sitegen 은 dir 을 모른다)."""
    for lang in RTL:
        p = DOCS / lang / 'index.html'
        assert p.exists(), f'{p} 없음 — 먼저 sitegen 으로 docs/site/{lang}.json 을 만든다'
        p.write_text(html_tag(p.read_text(), lang))


def write(lang, page, text):
    d = DOCS / lang
    d.mkdir(exist_ok=True)
    (d / page).write_text(text)


if __name__ == '__main__':
    build_doc('privacy.html')
    build_doc('support.html')
    mark_index_rtl()
    print('built:', ', '.join(LANGS))
