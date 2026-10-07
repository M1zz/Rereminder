#!/usr/bin/env python3
"""docs/ 의 여러 언어 페이지(index·privacy·support)에서 언어마다 따로 된 페이지를 만든다.

원본은 docs/ 최상단의 세 파일이다. 여기에는 모든 언어가 한 파일에 들어 있고 브라우저 언어로 골라 보인다
(앱 안의 링크·x-default 가 이 주소다). 스토어의 언어별 칸은 docs/<lang>/ 를 가리키므로,
원본을 고친 뒤에는 이 스크립트를 다시 돌려 언어 폴더를 새로 만든다.

    python3 scripts/build-lang-pages.py

- privacy·support: 그 언어의 <div data-lang="…"> 블록만 남긴다.
- index: 글은 스크립트의 i18n 사전에 있다 — node 로 사전을 읽어 data-i18n 자리에 미리 채우고, 언어를 고정한다.
"""
import html, json, pathlib, re, subprocess

DOCS = pathlib.Path(__file__).resolve().parent.parent / 'docs'
BASE = 'https://m1zz.github.io/Rereminder/'
LANGS = ['ko', 'en', 'ja', 'zh-Hans', 'zh-Hant', 'de', 'fr', 'es', 'pt-BR', 'pt-PT', 'it']
NAMES = {'ko': '한국어', 'en': 'English', 'ja': '日本語', 'zh-Hans': '简体中文', 'zh-Hant': '繁體中文',
         'de': 'Deutsch', 'fr': 'Français', 'es': 'Español', 'pt-BR': 'Português (Brasil)',
         'pt-PT': 'Português (Portugal)', 'it': 'Italiano'}
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
}
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
    s = re.sub(r'<html lang="[^"]*"', f'<html lang="{lang}"', s, count=1)
    s = s.replace('</head>', head_links(page, lang) + '</head>', 1)
    s = re.sub(r'<nav class="lang-links".*?</nav>\n', lang_nav(page, lang), s, count=1, flags=re.S)
    s = s.replace('href="app-icon.jpeg"', 'href="../app-icon.jpeg"').replace('src="app-icon.jpeg"', 'src="../app-icon.jpeg"')
    s = s.replace(f'<option value="{lang}">', f'<option value="{lang}" selected>')
    return s


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
    blocks = {m.group(1): m.group(0) for m in re.finditer(r'^<div data-lang="([^"]+)">\n.*?^</div>\n', src, re.S | re.M)}
    missing = [l for l in LANGS if l not in blocks]
    assert not missing, f'{page}: 언어 블록 없음 {missing}'
    start = src.index('<div class="container">')
    end = src.index('\n<footer>')
    head, foot = src[:start], src[end:]
    foot = re.sub(r'<script>.*?</script>\n', '', foot, flags=re.S)
    for lang in LANGS:
        block = blocks[lang].replace(f'<div data-lang="{lang}">', '<div>', 1)
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


def js_object(src, start_pat):
    """스크립트 안의 객체 리터럴 하나를 node 로 평가해 JSON 으로 받는다."""
    i = src.index(start_pat)
    j = src.index('{', i)
    depth, k, quote = 0, j, None
    while True:
        c = src[k]
        if quote:
            if c == '\\':
                k += 1
            elif c == quote:
                quote = None
        elif c in '"\'`':
            quote = c
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                break
        k += 1
    lit = src[j:k + 1]
    res = subprocess.run(['node', '-e', f'process.stdout.write(JSON.stringify({lit}))'], capture_output=True, text=True, check=True)
    return json.loads(res.stdout)


def build_index():
    src = (DOCS / 'index.html').read_text()
    i18n = js_object(src, 'const i18n = {')
    titles = js_object(src, 'var titleMap = {')
    descs = js_object(src, 'var descMap = {')
    for lang in LANGS:
        assert lang in i18n and lang in titles and lang in descs, f'index.html: {lang} 없음'
        strings = {**i18n['en'], **i18n[lang]}
        out = src

        def fill(m, as_html):
            key = m.group(3)
            if key not in strings:
                return m.group(0)
            inner = strings[key] if as_html else html.escape(strings[key], quote=False)
            return m.group(1) + inner + m.group(4)

        for attr, as_html in (('data-i18n-html', True), ('data-i18n', False)):
            pat = re.compile(r'(<([a-zA-Z0-9]+)\b[^>]*\b' + attr + r'="([^"]+)"[^>]*>)(?:(?!<\2\b).)*?(</\2>)', re.S)
            out = pat.sub(lambda m: fill(m, as_html), out)
        out = set_meta(out, titles[lang], descs[lang])
        out = re.sub(r'(<meta property="og:url" content=")[^"]*', lambda m: m.group(1) + BASE + lang + '/', out, count=1)
        # 이 주소는 언어가 정해져 있다 — 저장된 선택이나 기기 언어를 보지 않는다
        out = out.replace('function detectLang() {\n', f"function detectLang() {{\n    return '{lang}';\n", 1)
        out = out.replace("location.href = e.target.value + '/';", "location.href = '../' + e.target.value + '/';")
        out = common(out, 'index.html', lang)
        write(lang, 'index.html', out)


def write(lang, page, text):
    d = DOCS / lang
    d.mkdir(exist_ok=True)
    (d / page).write_text(text)


if __name__ == '__main__':
    build_doc('privacy.html')
    build_doc('support.html')
    build_index()
    print('built:', ', '.join(LANGS))
