#!/usr/bin/env node
// 페이지 안에서 도는 체험 다이얼(Live Demo)을 최소 DOM 셔임 위에서 그대로 돌려 본다.
//
//   node web/demo-test.js web/index.html          # App Clip 초대 페이지 (/rereminder/)
//   node web/demo-test.js docs/index.html         # 앱 소개 페이지 (/Rereminder/)
//   node web/demo-test.js web/index.html '?minutes=25'
//
// 두 페이지는 **같은 스크립트**를 쓴다(한쪽을 고치면 다른 쪽에도 복사해야 한다).
// 문구는 페이지 언어를 따라가므로 검사는 언어에 기대지 않는 값(시간·구간·링 조각·
// 알림이 울리는 순서)만 본다.
'use strict';

const fs = require('fs');

const HTML = process.argv[2] || 'web/index.html';
const SEARCH = process.argv[3] || '';

// ---- 최소 DOM -------------------------------------------------------------
class El {
    constructor(tag) {
        this.tag = tag;
        this.children = [];
        this.attrs = {};
        this.dataset = {};
        this.style = {};
        this.hidden = false;
        this.disabled = false;
        this._text = '';
        this.innerHTML = '';
        this._classes = new Set();
        this.listeners = {};
        this.classList = {
            add: (c) => this._classes.add(c),
            remove: (c) => this._classes.delete(c),
            contains: (c) => this._classes.has(c),
            toggle: (c, on) => {
                if (on === undefined) { return this._classes.has(c) ? this._classes.delete(c) : this._classes.add(c); }
                return on ? this._classes.add(c) : this._classes.delete(c);
            }
        };
    }
    get className() { return [...this._classes].join(' '); }
    set className(v) { this._classes = new Set(String(v).split(/\s+/).filter(Boolean)); }
    get textContent() { return this._text || this.children.map((c) => c.textContent).join(''); }
    set textContent(v) { this._text = String(v); this.children = []; }
    setAttribute(k, v) { this.attrs[k] = String(v); }
    getAttribute(k) { return this.attrs[k]; }
    appendChild(c) { this.children.push(c); return c; }
    addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
    fire(type, evt) { (this.listeners[type] || []).forEach((fn) => fn(evt || {})); }
    getBoundingClientRect() { return { left: 0, top: 0, width: 400, height: 400 }; }
    setPointerCapture() {}
    releasePointerCapture() {}
    hasPointerCapture() { return false; }
}

const byId = {};
[
    'demo-svg', 'demo-stage', 'demo-arcs', 'demo-knobs', 'demo-time', 'demo-start',
    'demo-pause', 'demo-stop', 'demo-badge', 'demo-banner', 'demo-banner-icon',
    'demo-banner-text', 'demo-banner-sub', 'demo-sections', 'demo-speed-fast',
    'demo-speed-real', 'demo-sound', 'demo-sound-icon'
].forEach((id) => { byId[id] = new El('div'); });

const html = fs.readFileSync(HTML, 'utf8');

function pillsFrom(attr) {
    const re = new RegExp('data-' + attr + '="(\\d+)"', 'g');
    const out = [];
    let m;
    while ((m = re.exec(html))) {
        const e = new El('button');
        e.dataset[attr === 'demo-preset' ? 'demoPreset' : 'demoAlert'] = m[1];
        out.push(e);
    }
    return out;
}
const presets = pillsFrom('demo-preset');
const alertPills = pillsFrom('demo-alert');
const i18nNodes = [...html.matchAll(/data-demo-i18n="([a-zA-Z]+)"/g)].map((m) => {
    const e = new El('p');
    e._key = m[1];
    e.attrs['data-demo-i18n'] = m[1];
    return e;
});

const pageLang = (/<html[^>]*\blang="([a-zA-Z-]+)"/.exec(html) || [, 'en'])[1];

global.document = {
    documentElement: { lang: pageLang },
    getElementById: (id) => byId[id] || null,
    createElement: (t) => new El(t),
    createElementNS: (ns, t) => new El(t),
    querySelectorAll: (sel) => {
        if (sel === '[data-demo-preset]') { return presets; }
        if (sel === '[data-demo-alert]') { return alertPills; }
        if (sel === '[data-demo-i18n]') { return i18nNodes; }
        throw new Error('unhandled selector ' + sel);
    },
    querySelector: (sel) => {
        const m = /^\[data-demo-i18n="(.+)"\]$/.exec(sel);
        if (m) { return i18nNodes.find((n) => n._key === m[1]) || null; }
        throw new Error('unhandled selector ' + sel);
    }
};
// node 24 의 global.navigator 는 getter 라 그냥 대입하면 strict 모드에서 던진다
Object.defineProperty(global, 'navigator', { value: {}, configurable: true, writable: true });
global.location = { search: SEARCH };
let rafQueue = [];
global.window = {
    addEventListener() {},
    AudioContext: undefined,
    requestAnimationFrame: (fn) => rafQueue.push(fn)
};
global.requestAnimationFrame = global.window.requestAnimationFrame;
global.cancelAnimationFrame = () => { rafQueue = []; };

// 페이지에 든 스크립트를 그대로 돌린다 (데모 IIFE 는 SEC_PER_DEG 로 알아본다)
const script = html.split(/<script>/).find((s) => s.includes('SEC_PER_DEG')).split('</script>')[0];
eval(script);   // eslint-disable-line no-eval

// ---- 검사 -----------------------------------------------------------------
const results = [];
function check(name, got, want) {
    const ok = JSON.stringify(got) === JSON.stringify(want);
    results.push({ ok, line: (ok ? 'ok   ' : 'FAIL ') + name + (ok ? '' : `  got=${JSON.stringify(got)} want=${JSON.stringify(want)}`) });
}
const time = () => byId['demo-time'].textContent;
const chips = () => byId['demo-sections'].children.map((c) => c.children[1].textContent);
const arcs = () => byId['demo-arcs'].children.map((p) => p.attrs.stroke);
const bells = () => byId['demo-knobs'].children.filter((g) => g.children.some((c) => c.attrs && c.attrs.fill === '#FF9F0A')).length;
const preset = (v) => presets.find((p) => p.dataset.demoPreset === String(v));
const alertPill = (v) => alertPills.find((p) => p.dataset.demoAlert === String(v));

if (SEARCH) {
    // 초대 URL 로 들어온 경우: 다이얼이 그 시간으로 올라와 있어야 한다
    const want = Math.min(60, Math.max(1, Math.round(Number(new URLSearchParams(SEARCH).get('minutes')) || 10)));
    check(`?minutes → ${want}분`, time(), String(want).padStart(2, '0') + ':00');
} else {
    // 1) 초기 상태 — 10분 + 종료 1분 전 알림 하나 (TimerScreenViewModel.DefaultSetup)
    check('초기 시간 10:00', time(), '10:00');
    check('초기 구간 9:00 / 1:00', chips(), ['9:00', '1:00']);
    check('링 조각 2개', arcs().length, 2);
    check('링 색이 경과 순서(green ← blue)', arcs(), ['#30D158', '#0A84FF']);
    check('종 1개', bells(), 1);
    check('페이지 언어가 문구에 반영', i18nNodes.find((n) => n._key === 'title').textContent.length > 0, true);

    // 2) 45분 + 5분 전 알림 추가
    preset(2700).fire('click');
    alertPill(300).fire('click');
    check('45분 표시', time(), '45:00');
    check('45분 구간 40:00 / 4:00 / 1:00', chips(), ['40:00', '4:00', '1:00']);
    check('링 조각 3개', arcs().length, 3);
    check('종 2개', bells(), 2);

    // 3) 10분 60배속 주행 — 5분 전 → 1분 전 → 종료 순서로 울린다
    preset(600).fire('click');
    check('10분 구간 5:00 / 4:00 / 1:00', chips(), ['5:00', '4:00', '1:00']);

    const rung = [];
    const banner = byId['demo-banner'];
    const add = banner.classList.add;
    banner.classList.add = function (c) {
        if (c === 'show') { rung.push(byId['demo-banner-icon'].textContent); }
        return add.call(banner.classList, c);
    };

    byId['demo-start'].fire('click');
    let ts = 0;
    for (let i = 0; i < 120; i++) {      // 60배속이면 10분이 10초 → 12초분(= +2분 오버타임)만 돈다
        const frames = rafQueue.splice(0);
        if (!frames.length) { break; }   // 오버타임 5분이면 데모가 스스로 멈춘다
        ts += 100;
        frames.forEach((fn) => fn(ts));
    }
    check('알림 세 번', rung.length, 3);
    check('종 두 번 뒤 종료', rung, ['🔔', '🔔', '⏰']);
    check('오버타임 표시', byId['demo-time']._classes.has('overtime'), true);

    // 4) 정지하면 설정이 그대로 돌아온다
    byId['demo-stop'].fire('click');
    check('정지 후 10:00', time(), '10:00');
    check('정지 후 구간 복원', chips(), ['5:00', '4:00', '1:00']);
    check('정지 후 종 2개', bells(), 2);
}

results.forEach((r) => console.log(r.line));
const failed = results.filter((r) => !r.ok);
console.log(`\n${HTML} (lang=${pageLang}${SEARCH ? ' ' + SEARCH : ''}) — ${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length ? 1 : 0);
