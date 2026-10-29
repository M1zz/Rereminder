// 두번알림 웹 체험: 끝나기 전에 미리 울리는 타이머를 브라우저에서 그대로 돌려 본다.
// 규칙은 앱과 같다. 다이얼 한 바퀴 = 60분(TimeMapper: 1° = 10초), 알림은 "끝나기 N분 전",
// 타이머보다 긴 알림은 울리지 않는다. 문구는 앱의 Localizable 값을 data-text 로 받는다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const SPEED = 60;                       // 체험은 1분이 1초로 흐른다
  const LAP = 3600, R = 80, C = 2 * Math.PI * R;
  const fill = (s, o) => s.replace(/\{(\w)\}/g, (_, k) => o[k]);
  const label = s => s >= 60 ? fill(T.min, { n: s / 60 }) : fill(T.sec, { n: s });
  const mmss = s => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
  const icon = document.querySelector(".brand img")?.getAttribute("src") || "";

  const state = { total: 600, alerts: new Set([180, 60]), left: 600, running: false, fired: new Set() };

  root.innerHTML = `
    <div class="rr-stage">
      <svg viewBox="0 0 200 200" aria-hidden="true">
        <circle class="rr-track" cx="100" cy="100" r="${R}"/>
        <circle class="rr-arc" cx="100" cy="100" r="${R}" transform="rotate(-90 100 100)"/>
        <g class="rr-bells"></g>
        <circle class="rr-knob" r="7"/>
      </svg>
      <div class="rr-center">
        <div class="rr-time" role="timer">10:00</div>
        <button type="button" class="rr-go" aria-label="${T.start}"></button>
      </div>
      <div class="rr-toast" role="status" aria-live="assertive">
        <img src="${icon}" alt="" width="36" height="36"><div><b>${T.app}</b><span></span></div>
      </div>
    </div>
    <div class="rr-controls">
      <p class="rr-label">${T.length}</p>
      <div class="rr-chips" data-group="length">
        ${[5, 10, 20, 30, 45, 60].map(m => `<button type="button" class="chip" data-len="${m * 60}">${label(m * 60)}</button>`).join("")}
      </div>
      <p class="rr-label">${T.alerts}</p>
      <div class="rr-chips" data-group="alerts">
        ${[600, 300, 180, 60, 30].map(s => `<button type="button" class="chip" data-alert="${s}">${label(s)}</button>`).join("")}
      </div>
      <p class="rr-next" aria-live="polite"></p>
      <p class="muted small">${T.note}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const timeEl = $(".rr-time"), arc = $(".rr-arc"), bells = $(".rr-bells"), knob = $(".rr-knob");
  const go = $(".rr-go"), next = $(".rr-next"), toast = $(".rr-toast"), toastText = toast.querySelector("span");
  const BELL = "M0-5.2c-2.4 0-3.8 1.9-3.8 4.2v2.1L-5 2.9h10L3.8 1.1V-1c0-2.3-1.4-4.2-3.8-4.2ZM-1.5 3.8a1.5 1.5 0 0 0 3 0Z";
  const point = s => { const a = (s / LAP) * 2 * Math.PI; return [100 + R * Math.sin(a), 100 - R * Math.cos(a)]; };

  // 앱의 "다음: 3분 알림 (6분 58초 남음)" 줄. 남은 시간은 그 알림까지다.
  function nextLine(left) {
    const up = [...state.alerts].filter(o => o < left && o < state.total).sort((a, b) => b - a)[0];
    const until = Math.max(0, Math.ceil(up === undefined ? left : left - up));
    const t = { a: up === undefined ? "" : label(up), m: Math.floor(until / 60), s: until % 60 };
    const key = (up === undefined ? "end" : "next") + (t.m ? "Min" : "Sec");
    return fill(T[key], t);
  }

  function render() {
    const left = Math.max(0, state.left), shown = Math.ceil(left);
    timeEl.textContent = mmss(shown);
    arc.style.strokeDasharray = `${(Math.min(left, LAP) / LAP) * C} ${C}`;
    const [kx, ky] = point(Math.min(left, LAP));
    knob.setAttribute("cx", kx); knob.setAttribute("cy", ky);
    bells.innerHTML = [...state.alerts].filter(o => o < state.total).map(o => {
      const [x, y] = point(o);
      return `<g class="rr-bell${state.fired.has(o) ? " done" : ""}" transform="translate(${x} ${y})"><circle r="9"/><path d="${BELL}"/></g>`;
    }).join("");
    root.querySelectorAll("[data-len]").forEach(b => b.setAttribute("aria-pressed", +b.dataset.len === state.total));
    root.querySelectorAll("[data-alert]").forEach(b => {
      b.setAttribute("aria-pressed", state.alerts.has(+b.dataset.alert));
      b.disabled = +b.dataset.alert >= state.total;      // 타이머보다 긴 알림은 울릴 수 없다
    });
    go.classList.toggle("stop", state.running);
    go.setAttribute("aria-label", state.running ? T.stop : T.start);
    next.textContent = nextLine(left);
  }

  // 알림 소리: 두 음 차임. 소리를 못 내는 환경이면 조용히 넘어간다.
  let ctx;
  function chime(final) {
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      [0, 0.18].forEach((d, i) => {
        const o = ctx.createOscillator(), g = ctx.createGain(), t = ctx.currentTime + d;
        o.frequency.value = (final ? [880, 660] : [660, 990])[i];
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(0.25, t + 0.02);
        g.gain.exponentialRampToValueAtTime(0.0001, t + 0.5);
        o.connect(g).connect(ctx.destination); o.start(t); o.stop(t + 0.55);
      });
    } catch (e) {}
    navigator.vibrate?.(final ? [200, 100, 200] : 200);
  }

  let toastTimer;
  function notify(text, final) {
    toastText.textContent = text;
    toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("show"), 2600);
    chime(final);
  }

  let startedAt, raf;
  function tick() {
    const left = state.total - ((performance.now() - startedAt) / 1000) * SPEED;
    for (const o of state.alerts) {
      if (o < state.total && left <= o && !state.fired.has(o)) {
        state.fired.add(o);
        notify(o >= 60 ? fill(T.msgMin, { n: o / 60 }) : fill(T.msgSec, { n: o }));
      }
    }
    if (left <= 0) { stop(); notify(T.done, true); return; }
    state.left = left; render();
    raf = requestAnimationFrame(tick);
  }
  function start() {
    ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
    ctx.resume?.();
    state.running = true; state.fired.clear(); state.left = state.total;
    startedAt = performance.now(); root.dataset.used = "1";
    raf = requestAnimationFrame(tick);
  }
  function stop() {
    cancelAnimationFrame(raf);
    state.running = false; state.left = state.total; state.fired.clear(); render();
  }

  root.addEventListener("click", e => {
    const b = e.target.closest("button");
    if (!b) return;
    if (b === go) { state.running ? stop() : start(); return; }
    if (b.dataset.len) { stop(); state.total = +b.dataset.len; state.left = state.total; }
    if (b.dataset.alert) {
      const s = +b.dataset.alert;
      state.alerts.has(s) ? state.alerts.delete(s) : state.alerts.add(s);
      if (state.left <= s) state.fired.add(s);
    }
    render();
  });

  render();
})();
