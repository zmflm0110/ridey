// RIDEY. 소개 사이트 — 첫 화면 실시간 지도, 한 대의 12일(선과 점), 원리 띠, 검증 막대, 하루 재생, 실시간 채점, 번호 확인.
// 기능마다 제 자리가 있을 때만 돈다(진행 기록 쪽도 같은 파일을 씀). 클라우드 DB 는 공개 키로 읽기만.
// 움직임(docs/brand.md 5): 빠르게 출발해 부드럽게 앉는 곡선, 점·막대만 스프링, 숫자는 칸 너비가 같은 글꼴로 올라감. '움직임 줄이기' 면 모두 끔.
(() => {
  const $ = (s) => document.querySelector(s), $$ = (s) => [...document.querySelectorAll(s)];
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const SB = "https://iqvquwvoljzuvdgtbpnu.supabase.co/rest/v1/", KEY = "sb_publishable_YFBKlBvyPFAhBpLdS3o8_A_xIeUmTVE";
  const sb = (q) => fetch(SB + q, { headers: { apikey: KEY } }).then((r) => { if (!r.ok) throw new Error(r.status); return r.json(); });
  const esc = (x) => String(x).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const ko = (n) => Number(n).toLocaleString("ko-KR");
  const seen = (el, fn, threshold = 0.25) => el && new IntersectionObserver((es, o) => { if (es[0].isIntersecting) { fn(); o.disconnect(); } }, { threshold }).observe(el);
  const expo = (x) => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * x));
  let liveP = null;   // 지금 경보 목록 — 첫 화면 지도와 실시간 전광판이 같이 씀(한 번만 받음)
  const liveSnap = () => (liveP ||= sb("live_snapshot?select=at,bikes:body->bikes").then((r) => r[0] || null).catch(() => null));

  // ── 경보 순간: 점에서 충격파 고리가 퍼지고 불꽃 점들이 튀어 나감 (원리 띠·직접 찍어 보기·12일 표). 카드 밖으로는 안 나감
  const burst = (host, at, big = 1) => {
    if (reduce || !host || !at || !host.animate) return;
    let fx = [...host.children].find((c) => c.classList.contains("fx"));
    if (!fx) { fx = document.createElement("div"); fx.className = "fx"; fx.setAttribute("aria-hidden", "true"); host.appendChild(fx); }
    const h = host.getBoundingClientRect(), a = at.getBoundingClientRect(), x = a.left + a.width / 2 - h.left, y = a.top + a.height / 2 - h.top;
    const R = Math.round(Math.min(460, Math.max(h.width, h.height) * 0.55) * big);
    const el = (c) => { const e = document.createElement("i"); e.className = c; e.style.left = x + "px"; e.style.top = y + "px"; fx.appendChild(e); return e; };
    for (const [d, k] of [[0, 1], [140, 0.6]]) {   // 고리 둘 — 큰 것 뒤에 작은 것
      const ring = el("sw"), r = Math.round(R * k);
      ring.animate([{ width: "8px", height: "8px", margin: "-4px 0 0 -4px", opacity: 1 }, { width: `${2 * r}px`, height: `${2 * r}px`, margin: `-${r}px 0 0 -${r}px`, opacity: 0 }],
        { duration: 1150, delay: d, easing: "cubic-bezier(.16, 1, .3, 1)", fill: "both" }).finished.then(() => ring.remove());
    }
    const n = Math.round(14 * big);
    for (let i = 0; i < n; i++) {
      const sp = el("spark"), ang = (i / n) * Math.PI * 2 + Math.random() * 0.45, dist = (36 + Math.random() * 80) * big, sz = 2.5 + Math.random() * 4.5;
      sp.style.width = sp.style.height = sz.toFixed(1) + "px";
      sp.animate([{ transform: "translate(-50%, -50%) scale(1)", opacity: 1 }, { transform: `translate(calc(-50% + ${(Math.cos(ang) * dist).toFixed(1)}px), calc(-50% + ${(Math.sin(ang) * dist).toFixed(1)}px)) scale(.15)`, opacity: 0 }],
        { duration: 650 + Math.random() * 450, easing: "cubic-bezier(.16, 1, .3, 1)", fill: "both" }).finished.then(() => sp.remove());
    }
  };

  // ── 번호판 글자가 무작위 글자를 거쳐 왼쪽부터 풀려 나옴 (SPB-69683 · 지도 꼬리표의 자전거 번호)
  const decode = (el, dur = 850) => {
    if (!el || reduce) return;
    const final = el.textContent, D = "0123456789", A = "ABCDEFGHJKLMNPRSTUVWXYZ";
    let t0 = 0, last = 0;
    const tick = (now) => {
      t0 = t0 || now;
      const k = Math.min(1, (now - t0) / dur);
      if (now - last > 45 || k >= 1) {
        last = now; const done = Math.floor(k * final.length);
        el.textContent = k >= 1 ? final : [...final].map((ch, i) => (i < done || !/[0-9A-Z]/.test(ch) ? ch : /\d/.test(ch) ? D[(Math.random() * 10) | 0] : A[(Math.random() * A.length) | 0])).join("");
      }
      if (k < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };

  // ── 숫자 올리기: 글자 속 숫자 덩어리(1,234 · 2.5 · 20~25 의 양 끝)를 0 에서 제 값까지. <small> 단위는 그대로
  function countUp(el, dur = 1500) {
    if (!el || reduce || el.dataset.counted) return;
    el.dataset.counted = 1;
    const nodes = []; (function walk(n) { for (const c of n.childNodes) { if (c.nodeType === 3) nodes.push(c); else if (c.nodeName !== "SMALL") walk(c); } })(el);
    const parts = nodes.map((t) => {
      const src = t.nodeValue, toks = [];
      src.replace(/\d[\d,]*(\.\d+)?/g, (m, dec, off) => { toks.push({ m, off, v: parseFloat(m.replace(/,/g, "")), d: dec ? dec.length - 1 : 0, comma: m.includes(",") }); return m; });
      return { t, src, toks };
    }).filter((p) => p.toks.length);
    if (!parts.length) return;
    const fmt = (v, k) => (k.comma ? v.toLocaleString("en-US", { minimumFractionDigits: k.d, maximumFractionDigits: k.d }) : v.toFixed(k.d));
    const t0 = performance.now();
    const step = (now) => {
      const e = expo(Math.min(1, (now - t0) / dur));
      for (const p of parts) { let out = "", last = 0; for (const k of p.toks) { out += p.src.slice(last, k.off) + fmt(k.v * e, k); last = k.off + k.m.length; } p.t.nodeValue = out + p.src.slice(last); }
      if (e < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  }

  // ── 제목을 줄로 나눠 가림막 뒤에서 올라오게 (스크립트가 없으면 그냥 보임)
  //    마지막 마침표는 로고 'RIDEY.' 의 점처럼 — 신호색 점이 바닥선에 앉는다(글자 '.' 는 복사·화면 읽기용으로 숨겨 둠). 마지막 낱말과 붙여 혼자 줄바꿈되지 않게
  for (const h of $$(".hero h1, .head h2")) {
    const html = h.innerHTML.replace(/([^\s>]+)\.((?:\s*<\/[a-z]+>)*)\s*$/i, '<span class="nw">$1<span class="pd"><span class="sr">.</span></span></span>$2');
    h.innerHTML = html.split(/<br\s*\/?>/i).map((l, i) => `<span class="ln" style="--i:${i}"><span>${l}</span></span>`).join("");
    const pd = h.querySelector(".pd");
    if (pd && !reduce) h.addEventListener("pointerenter", () => pd.animate([{ transform: "none" }, { transform: "translateY(-70%) scale(1.15)", offset: 0.4 }, { transform: "none" }],
      { duration: 700, easing: CSS.supports("transition-timing-function", "linear(0, 1)") ? getComputedStyle(document.documentElement).getPropertyValue("--spring").trim() : "cubic-bezier(.34, 1.56, .64, 1)" }));
  }
  $$(".stagger").forEach((g) => [...g.children].forEach((c, i) => c.style.setProperty("--i", i)));

  // ── 첫 화면 차례: 글꼴이 오면(또는 0.8초 뒤) 머리 → 제목 줄 → 글 → 단추 → 숫자
  const start = () => { if (document.body.classList.contains("ready")) return; document.body.classList.add("ready"); $(".hero h1")?.classList.add("lines-in"); };
  Promise.race([document.fonts ? document.fonts.ready : Promise.resolve(), new Promise((r) => setTimeout(r, 800))]).then(() => requestAnimationFrame(start));

  // ── 밝은·어두운 화면 (고른 것만 이 기기에 기억) — 단추에서 원이 퍼지며 바뀜
  const root = document.documentElement;
  $("#theme")?.addEventListener("click", (ev) => {
    const go = () => {
      const dark = root.dataset.theme ? root.dataset.theme === "dark" : matchMedia("(prefers-color-scheme: dark)").matches;
      root.dataset.theme = dark ? "light" : "dark";
      try { localStorage.setItem("hz-theme", root.dataset.theme); } catch {}
    };
    if (!document.startViewTransition || reduce) return go();
    const r = ev.currentTarget.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2;
    const end = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
    root.classList.add("vt-theme");
    const vt = document.startViewTransition(go);
    vt.ready.then(() => root.animate({ clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${end}px at ${x}px ${y}px)`] },
      { duration: 700, easing: "cubic-bezier(.16, 1, .3, 1)", pseudoElement: "::view-transition-new(root)" }));
    vt.finished.finally(() => root.classList.remove("vt-theme"));
  });

  // ── 머리: 어두운 첫 화면을 지나면 종이색 바탕 · 지금 보는 구역 아래 신호 점
  const nav = $("#top"), hero = $("#hero");
  if (nav && hero) new IntersectionObserver(([e]) => nav.classList.toggle("solid", !e.isIntersecting), { rootMargin: "-90px 0px 0px 0px" }).observe(hero);
  if (nav) { const sc = () => nav.classList.toggle("scrolled", scrollY > 8); sc(); addEventListener("scroll", sc, { passive: true }); }   // 첫 화면 안에서도 내리면 어두운 유리 바탕
  else { nav?.classList.add("solid"); start(); }
  const links = $$(".nav nav > a[href^='#']"), ndot = $(".navdot");
  const placeDot = () => {
    const a = $(".nav nav > a.on:not(.btn)");
    if (!ndot) return;
    if (!a || !a.offsetParent) { ndot.classList.remove("on"); return; }
    ndot.style.setProperty("--x", `${a.offsetLeft + a.offsetWidth / 2}px`);
    ndot.style.setProperty("--y", `${a.offsetTop + a.offsetHeight - 3}px`);
    ndot.classList.add("on");
  };
  if (links.length) {
    const sio = new IntersectionObserver((es) => es.forEach((e) => {
      if (!e.isIntersecting) return;
      links.forEach((a) => a.classList.toggle("on", a.getAttribute("href") === "#" + e.target.id)); placeDot();
    }), { rootMargin: "-45% 0px -50% 0px" });
    links.forEach((a) => { const s = $(a.getAttribute("href")); if (s) sio.observe(s); });
    $("#hero") && new IntersectionObserver(([e]) => { if (e.isIntersecting) { links.forEach((a) => a.classList.remove("on")); placeDot(); } }, { rootMargin: "-45% 0px -50% 0px" }).observe($("#hero"));
  } else $$(".nav nav > a:not(.btn)").forEach((a) => { if (location.pathname.endsWith(a.getAttribute("href"))) a.classList.add("on"); });
  placeDot(); addEventListener("resize", placeDot); document.fonts?.ready.then(placeDot);
  // 위쪽 진행 막대 — CSS 스크롤 타임라인이 없는 브라우저만 스크립트로
  const prog = $(".progress");
  if (prog && !CSS.supports("animation-timeline: scroll()")) {
    let q = 0; addEventListener("scroll", () => { if (q) return; q = requestAnimationFrame(() => { q = 0; const h = document.documentElement.scrollHeight - innerHeight; prog.style.setProperty("--sp", h > 0 ? Math.min(1, scrollY / h) : 0); }); }, { passive: true });
  }

  // ── 나타나기 (+ 제목 줄, 숫자)
  const io = new IntersectionObserver((es) => es.forEach((e) => { if (!e.isIntersecting) return; e.target.classList.add("in"); io.unobserve(e.target); }), { threshold: 0.12 });
  $$(".reveal, .foot, #days").forEach((el) => io.observe(el));
  const heads = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("lines-in"); heads.unobserve(e.target); } }), { threshold: 0.3 });
  // 원리(03)는 위에서 신호 점이 커져 어두운 구역이 된 뒤에 제목이 올라옴(점이 화면을 다 덮기 전엔 밝은 바탕) — 화면 위쪽 58% 에 들어올 때
  const iris = !reduce && CSS.supports("animation-timeline: view()");
  const headsLate = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add("lines-in"); headsLate.unobserve(e.target); } }), { rootMargin: "0px 0px -42% 0px" });
  $$(".head").forEach((h) => (iris && h.closest("#how") ? headsLate : heads).observe(h));
  const nums = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { setTimeout(() => countUp(e.target), 250); nums.unobserve(e.target); } }), { threshold: 0.6 });
  $$(".fact .num, .stat .num, .grid3 .num, .why-card .big-p, .proof-strip .num").forEach((el) => nums.observe(el));

  // ── 대여소 (지도 둘이 같이 씀) — [번호, 이름, 구, 위도, 경도]
  const stationsP = $("#livemap") || $("#replay") ? fetch("data/stations.json").then((r) => r.json()).then((a) => {
    const m = {}; for (const [id, name, gu, lat, lon] of a) m[id] = { id, name, gu, lat, lon }; return m;
  }) : Promise.resolve({});
  function box(st) {
    let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
    for (const s of Object.values(st)) { x0 = Math.min(x0, s.lon); x1 = Math.max(x1, s.lon); y0 = Math.min(y0, s.lat); y1 = Math.max(y1, s.lat); }
    return { x0, x1, y0, y1, c: Math.cos(37.55 * Math.PI / 180) };
  }
  const aspect = (b) => ((b.x1 - b.x0) * b.c) / (b.y1 - b.y0);
  const fit = (b, ox, oy, w) => { const k = w / ((b.x1 - b.x0) * b.c); return (s) => [ox + (s.lon - b.x0) * b.c * k, oy + (b.y1 - s.lat) * k]; };
  function sizeCanvas(cv) {
    const r = cv.getBoundingClientRect(), dpr = Math.min(2, devicePixelRatio || 1);
    cv.width = Math.round(r.width * dpr); cv.height = Math.round(r.height * dpr);
    return { W: r.width, H: r.height, dpr };
  }

  // ── 첫 화면: 지금 서울의 경보 대여소 (못 받으면 6월 15일 아침 시연 목록)
  //     점 하나(신호)가 지도 가운데 떠서 숨을 쉬다가 터지며 서울 2,789곳 대여소로 흩어져 앉고, 경보 대여소가 가까운 곳부터 차례로 켜진다(WebGL).
  //     큰 숫자는 경보 점이 켜질 때마다 그 대여소의 자전거 수만큼 올라간다. 커서를 가져가면 점들이 비켜나고 가장 가까운 경보 점에 꼬리표.
  //     스크롤하면 도시의 점들이 소용돌이치며 제목 '먼저.' 의 마침표로 빨려 들어간다 — 점 하나 → 서울 → 다시 점 하나.
  //     WebGL 이 없거나 '움직임 줄이기' 면 2D 로(레이더처럼 퍼짐 · 움직임 줄이기면 멈춘 그림).
  (async () => {
    let cv = $("#livemap"); if (!cv) return;
    const hero = $("#hero"), blips = $("#blips");
    const tSeed = performance.now();
    const intro = !reduce && window.WebGLRenderingContext ? seedIntro() : null;   // 씨앗 점은 대여소 자료를 받기 전에 먼저
    const st = await stationsP, B = box(st);
    const L = {}; let pts = [];
    const layout = () => {
      Object.assign(L, sizeCanvas(cv));
      const mobile = L.W < 760, a = aspect(B);
      const mw = mobile ? L.W * 1.08 : Math.min(L.W * 0.62, (L.H * 0.84) * a), mh = mw / a;
      const ox = mobile ? (L.W - mw) / 2 : Math.min(L.W - mw - 12, L.W * 0.66 - mw / 2), oy = mobile ? L.H - mh - 40 : Math.max(70, (L.H - mh) / 2 - 20);
      L.mobile = mobile; L.P = fit(B, ox, oy, mw); L.cx = ox + mw / 2; L.cy = oy + mh / 2; L.maxR = Math.hypot(mw, mh) / 2 + 30;
      pts.forEach((p) => { p.xy = L.P(p.s); p.d = Math.hypot(p.xy[0] - L.cx, p.xy[1] - L.cy); });
    };
    layout();
    const T0 = performance.now();
    const ptr = { x: -1e4, y: -1e4, on: false };
    const eng = (intro && glHero()) || canvasHero();
    if (!eng.tb) intro?.cancel();
    let running = true;
    const loop = (t) => { if (running) eng.frame(t); requestAnimationFrame(loop); };
    requestAnimationFrame(loop);
    new IntersectionObserver(([e]) => (running = e.isIntersecting)).observe(hero);
    let rt; addEventListener("resize", () => { clearTimeout(rt); rt = setTimeout(() => { layout(); eng.resize(); }, 150); });

    // 경보 목록 — 지도는 먼저 그려 두고, 받는 대로 켬
    let marks = [], live = false;
    {
      const row = await liveSnap();
      if (row && row.bikes && row.bikes.length) {
        live = true; marks = row.bikes.map((b) => [b.station, b.chain, b.bike]);
        const at = new Date(row.at + "+09:00"), hh = String(at.getHours()).padStart(2, "0"), mm = String(at.getMinutes()).padStart(2, "0");
        $("#live-n").textContent = row.bikes.length;
        $("#live-d").textContent = `${at.getMonth() + 1}월 ${at.getDate()}일 ${hh}:${mm} 기준 · 클라우드가 5분마다 다시 셉니다`;
      }
    }
    if (!live) {
      try {
        const m = await (await fetch("data/morning.json")).json();
        marks = m.bikes.map((b) => [b[1], b[3], b[0]]);
        $("#live-k").textContent = "6월 15일 아침, 고장 의심 따릉이"; $("#live-n").textContent = m.bikes.length;
        $("#live-d").textContent = "시연 자료 — 지금은 실시간 목록을 받지 못했어요"; $("#hero-src").textContent = "서울 따릉이 · 2026년 6월 15일 실제 기록";
      } catch {}
    }
    if (!eng.tb) setTimeout(() => countUp($("#live-n"), 1800), reduce ? 0 : Math.max(0, T0 + 1100 - performance.now()));
    const by = {};
    for (const [id, chain, bike] of marks) { const s = st[id]; if (!s) continue; const p = (by[id] = by[id] || { s, n: 0, top: 0, bike }); p.n++; if (chain > p.top) { p.top = chain; p.bike = bike; } }
    pts = Object.values(by); layout(); eng.alarms(Number($("#live-n").textContent) || 0);

    // 커서: 지도 위 어디서든(글자 위여도) — 점들이 비켜나고, 가장 가까운 경보 점에 꼬리표
    let tagHover = null, hoverP = null;
    const tag = (p, cls) => {
      const el = document.createElement("div"); el.className = "blip" + (cls ? " " + cls : "");
      el.style.left = p.xy[0] + "px"; el.style.top = p.xy[1] + "px";
      el.innerHTML = `<b>${p.top}명 연속</b>${esc(p.s.gu)} · <span class="id">${esc(p.bike || p.s.name)}</span>`;
      blips.appendChild(el); requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add("on")));
      if (p.bike) decode(el.querySelector(".id"), 600);
      return el;
    };
    const drop = (el, ms = 800) => { if (!el) return; el.classList.remove("on"); setTimeout(() => el.remove(), ms); };
    if (!reduce && matchMedia("(hover: hover)").matches) {
      hero.addEventListener("pointermove", (e) => {
        const r = cv.getBoundingClientRect(); ptr.x = e.clientX - r.left; ptr.y = e.clientY - r.top; ptr.on = true;
        if (scrollY > 40 || !pts.length) return;
        let best = null, bd = 34;
        for (const p of pts) { const d = Math.hypot(p.xy[0] - ptr.x, p.xy[1] - ptr.y); if (d < bd) { bd = d; best = p; } }
        if (best !== hoverP) { drop(tagHover); tagHover = best ? tag(best, "hover") : null; hoverP = best; }
      }, { passive: true });
      hero.addEventListener("pointerleave", () => { ptr.on = false; drop(tagHover); tagHover = null; hoverP = null; });
    }
    // 내리기 시작하면 꼬리표는 모두 거둠(점들이 마침표로 모이는 중)
    addEventListener("scroll", () => { if (scrollY > 40 && blips.childElementCount) { [...blips.children].forEach((el) => drop(el, 500)); tagHover = null; hoverP = null; } }, { passive: true });
    // 꼬리표: 몇 초마다 경보 점 하나 옆에 '몇 명 연속 · 어디' (넓은 화면, 글·숫자와 안 겹치는 자리만, 커서가 지도 위에 없을 때)
    if (blips && !reduce) {
      let last = null;
      setInterval(() => {
        if (!running || L.W < 760 || ptr.on || scrollY > 40) return;
        const ok = pts.filter((p) => p !== last && p.xy[0] > L.W * 0.47 && p.xy[0] < L.W - 230 && p.xy[1] > 110 && p.xy[1] < L.H - 360);
        if (!ok.length) return;
        const p = (last = ok[Math.floor(Math.random() * ok.length)]);
        const el = tag(p); setTimeout(() => drop(el), 2600);
      }, 3200);
    }

    // ── WebGL: 점 하나 → 서울
    function glHero() {
      let gl = null;
      try { gl = cv.getContext("webgl", { alpha: true, antialias: false, premultipliedAlpha: true, depth: false, stencil: false }); } catch {}
      if (!gl) return null;
      const VS = `
        attribute vec2 aT; attribute vec4 aD;
        uniform vec2 uRes, uO, uM, uF; uniform float uDpr, uT, uI, uMk, uC, uSy;
        varying vec4 vA; varying vec4 vB; varying float vF;
        float eo(float x) { return x >= 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * x); }
        void main() {
          float seed = aD.x, kind = aD.y, ord = aD.z, n = aD.w;
          float k = clamp((uT - ord * 0.55 - seed * 0.25) / 1.2, 0.0, 1.0), e = eo(k);
          vec2 d = aT - uO;
          vec2 p = uO + d * e + vec2(-d.y, d.x) * sin(e * 3.14159) * (seed - 0.5) * 0.5;
          // 스크롤: 모든 점이 소용돌이치며 제목의 마침표(uF)로 — 가까운 점부터
          float g = clamp(uC * 1.8 - (ord * 0.45 + seed * 0.35), 0.0, 1.0);
          float ge = g * g * (3.0 - 2.0 * g);
          vec2 q = p - uF;
          p = mix(p, uF, ge) + vec2(-q.y, q.x) * sin(ge * 3.14159) * (seed - 0.5) * 0.6;
          p.y += uSy;
          vec2 m = p - uM; float dist = length(m);
          float f = uMk * (1.0 - smoothstep(0.0, 150.0, dist));
          p += (dist > 0.5 ? m / dist : vec2(0.0)) * f * f * (kind < 0.5 ? 36.0 : 5.0);
          vec2 c = p / uRes * 2.0 - 1.0;
          gl_Position = vec4(c.x, -c.y, 0.0, 1.0);
          float on = step(0.0001, k), fade = 1.0 - ge * 0.92;
          if (kind < 0.5) {
            vA = vec4(0.0, on * (mix(0.9, 0.26, e) + f * 0.6 + ge * 0.6) * fade, 0.95, 6.0); vB = vec4(ge, 0.0, 0.0, 0.0); vF = 0.0;
          } else {
            float ign = clamp((uI - ord * 1.2) / 0.6, 0.0, 1.0), strong = step(1.5, kind);
            float rr = mix(0.95, (2.6 + min(n, 4.0) * 1.1 + strong) * (0.6 + 0.4 * eo(ign)), ign) * (1.0 + f * 0.4);
            float ph = fract(uT / 2.2 + seed);
            vA = vec4(1.0 + strong, on * fade, rr, (rr + 30.0) * 2.0);
            vB = vec4(ign, rr + ph * 18.0, (1.0 - ph) * mix(0.32, 0.5, strong) * ign, rr + 26.0 * ign);
            vF = (1.0 - ign) * step(0.001, ign) * 0.85;
          }
          gl_PointSize = vA.w * uDpr;
        }`;
      const FS = `
        precision mediump float;
        varying vec4 vA; varying vec4 vB; varying float vF;
        void main() {
          float r = length(gl_PointCoord - 0.5) * vA.w, R = vA.z, alpha = vA.y;
          if (vA.x < 0.5) { float a = (1.0 - smoothstep(R - 0.45, R + 0.55, r)) * alpha; gl_FragColor = vec4(mix(vec3(0.953, 0.945, 0.925), vec3(1.0, 0.42, 0.25), vB.x) * a, a); return; }
          vec3 sig = vec3(1.0, 0.361, 0.18);
          float ign = vB.x;
          float core = 1.0 - smoothstep(R - 0.7, R + 0.7, r);
          float glow = exp(-(r * r) / (R * R * 4.5)) * 0.55 * ign;
          float ring = (1.0 - smoothstep(0.0, 1.3, abs(r - vB.y))) * vB.z;
          float fl = (1.0 - smoothstep(0.0, 1.8, abs(r - vB.w))) * vF;
          vec3 coreCol = mix(vec3(0.953, 0.945, 0.925), mix(sig, vec3(1.0, 0.71, 0.6), vF), ign);
          float ca = core * mix(0.3, 1.0, ign);
          vec3 col = coreCol * ca + sig * (glow + ring) * (1.0 - ca) + vec3(1.0, 0.75, 0.65) * fl;
          float a = clamp(ca + (glow + ring) * (1.0 - ca) + fl, 0.0, 1.0);
          gl_FragColor = vec4(col, a) * alpha;
        }`;
      const sh = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s)); return s; };
      let prog;
      try {
        prog = gl.createProgram(); gl.attachShader(prog, sh(gl.VERTEX_SHADER, VS)); gl.attachShader(prog, sh(gl.FRAGMENT_SHADER, FS)); gl.linkProgram(prog);
        if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
      } catch (err) { console.warn("WebGL 지도 대신 2D", err); const c = cv.cloneNode(); cv.replaceWith(c); cv = c; return null; }
      gl.useProgram(prog);
      const U = {}; for (const n of ["uRes", "uO", "uM", "uF", "uDpr", "uT", "uI", "uMk", "uC", "uSy"]) U[n] = gl.getUniformLocation(prog, n);
      const aT = gl.getAttribLocation(prog, "aT"), aD = gl.getAttribLocation(prog, "aD");
      const bT = gl.createBuffer(), bD = gl.createBuffer();
      gl.enable(gl.BLEND); gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
      const hash = (i) => { const x = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x); };
      const tb = Math.max(tSeed + 1050, performance.now() + 80);   // 씨앗 점이 터지는 때
      intro.place(L.cx, L.cy); intro.burst(tb, L.maxR);
      let N = 0, tIgn = tb + 650;
      const fill = () => {
        const alarmIds = new Set(pts.map((p) => p.s.id));
        const ranked = [...pts].sort((a, b) => a.d - b.d), rank = new Map(ranked.map((p, i) => [p.s.id, i / Math.max(1, ranked.length - 1)]));
        const list = Object.values(st).filter((s) => !alarmIds.has(s.id)).map((s) => [s, 0, 0]);
        for (const p of pts) list.push([p.s, p.top >= 3 ? 2 : 1, p.n]);
        N = list.length;
        const T = new Float32Array(N * 2), D = new Float32Array(N * 4);
        list.forEach(([s, kind, n], i) => {
          const [x, y] = L.P(s); T[i * 2] = x; T[i * 2 + 1] = y;
          D[i * 4] = hash(i + 1); D[i * 4 + 1] = kind; D[i * 4 + 2] = kind === 1 || kind === 2 ? rank.get(s.id) : Math.min(1, Math.hypot(x - L.cx, y - L.cy) / L.maxR); D[i * 4 + 3] = n;
        });
        gl.bindBuffer(gl.ARRAY_BUFFER, bT); gl.bufferData(gl.ARRAY_BUFFER, T, gl.STATIC_DRAW); gl.enableVertexAttribArray(aT); gl.vertexAttribPointer(aT, 2, gl.FLOAT, false, 0, 0);
        gl.bindBuffer(gl.ARRAY_BUFFER, bD); gl.bufferData(gl.ARRAY_BUFFER, D, gl.STATIC_DRAW); gl.enableVertexAttribArray(aD); gl.vertexAttribPointer(aD, 4, gl.FLOAT, false, 0, 0);
      };
      fill();
      const pd = $(".hero h1 .pd");   // 스크롤하면 점들이 모일 곳 — 제목 '먼저.' 의 마침표
      let total = 0, counted = -1;
      const ign = () => [...pts].sort((a, b) => a.d - b.d);   // 켜지는 차례(가까운 곳부터) — 셰이더의 순서와 같게
      let mx = -1e4, my = -1e4, mk = 0;
      return {
        frame(now) {
          gl.viewport(0, 0, cv.width, cv.height); gl.clearColor(0, 0, 0, 0); gl.clear(gl.COLOR_BUFFER_BIT);
          if (ptr.on) { if (mk < 0.02) { mx = ptr.x; my = ptr.y; } mx += (ptr.x - mx) * 0.22; my += (ptr.y - my) * 0.22; }
          mk += ((ptr.on && scrollY < 60 ? 1 : 0) - mk) * 0.07;
          const c = Math.min(1, Math.max(0, scrollY / (L.H * 0.45))), sy = Math.min(scrollY, L.H) * 0.35;
          let fx = L.cx, fy = L.cy;
          if (pd && c > 0) { const a = pd.getBoundingClientRect(), b = cv.getBoundingClientRect(); fx = a.left + a.width / 2 - b.left; fy = a.top + a.height / 2 - b.top; }
          gl.uniform2f(U.uRes, L.W, L.H); gl.uniform1f(U.uDpr, L.dpr); gl.uniform2f(U.uO, L.cx, L.cy);
          gl.uniform1f(U.uT, (now - tb) / 1000); gl.uniform1f(U.uI, (now - tIgn) / 1000);
          gl.uniform2f(U.uM, mx, my); gl.uniform1f(U.uMk, mk);
          gl.uniform2f(U.uF, fx, fy - sy); gl.uniform1f(U.uC, c); gl.uniform1f(U.uSy, sy);
          gl.drawArrays(gl.POINTS, 0, N);
          // 마침표가 빨아들임: 다 모일수록 커지고 빛남
          if (pd) { const k = Math.max(0, (c - 0.55) / 0.45); pd.style.scale = (1 + k * 0.45).toFixed(3); pd.style.boxShadow = k > 0 ? `0 0 ${(k * 26).toFixed(1)}px ${(k * 5).toFixed(1)}px rgba(255, 92, 46, ${(k * 0.55).toFixed(2)})` : ""; }
          hero.style.setProperty("--veil", (1 - Math.min(1, c * 1.4) * 0.85).toFixed(3));   // 글 보호 그늘을 걷어 점들이 마침표까지 보이게
          // 큰 숫자: 켜진 경보 대여소의 자전거 수만 — 다 켜지면 실제 대수
          if (counted < total && pts.length) {
            const e = (now - tIgn) / 1000; let n = 0;
            const order = ign(); order.forEach((p, i) => { if (e >= (i / Math.max(1, order.length - 1)) * 1.2) n += p.n; });
            n = e >= 1.3 ? total : Math.min(n, total);
            if (n !== counted) { counted = n; const el = $("#live-n"); if (el) el.textContent = ko(n); }
          }
        },
        resize() { intro.place(L.cx, L.cy); fill(); },
        alarms(n) { tIgn = Math.max(tb + 650, performance.now() + 120); total = n; counted = -1; const el = $("#live-n"); if (el) { el.dataset.counted = 1; el.textContent = "0"; } fill(); },
        tb,
      };
    }

    // ── 씨앗 점(CSS): 지도 가운데 떠서 숨 쉬다가, 움츠렸다 터짐 + 얇게 퍼지는 고리. 자료 전엔 서울 모양 비율(1.23)로 자리를 어림
    function seedIntro() {
      const mk = (c) => { const el = document.createElement("i"); el.className = c; el.setAttribute("aria-hidden", "true"); hero.append(el); return el; };
      const seed = mk("seed"), shock = mk("shock");
      const place = (x, y) => { for (const el of [seed, shock]) { el.style.left = x + "px"; el.style.top = y + "px"; } };
      const r = hero.getBoundingClientRect(), W = r.width, H = r.height, a = 1.23, mobile = W < 760;
      const mw = mobile ? W * 1.08 : Math.min(W * 0.62, (H * 0.84) * a), mh = mw / a;
      place((mobile ? (W - mw) / 2 : Math.min(W - mw - 12, W * 0.66 - mw / 2)) + mw / 2, (mobile ? H - mh - 40 : Math.max(70, (H - mh) / 2 - 20)) + mh / 2);
      const SP = CSS.supports("transition-timing-function", "linear(0, 1)") ? getComputedStyle(document.documentElement).getPropertyValue("--spring").trim() : "cubic-bezier(.34, 1.56, .64, 1)";
      seed.animate([{ transform: "scale(0)", opacity: 0 }, { transform: "scale(1)", opacity: 1 }], { duration: 750, delay: 120, easing: SP, fill: "both" });
      seed.animate([{ boxShadow: "0 0 0 0 rgba(255, 92, 46, .7), 0 0 26px 3px rgba(255, 92, 46, .55)" }, { boxShadow: "0 0 0 28px rgba(255, 92, 46, 0), 0 0 26px 3px rgba(255, 92, 46, .55)" }],
        { duration: 1100, delay: 260, easing: "cubic-bezier(.16, 1, .3, 1)", fill: "forwards" });
      return {
        place,
        burst(tb, maxR) {   // tb 에 터짐: 0.43초 전부터 움츠렸다가 크게 번쩍
          const d = Math.max(0, tb - performance.now());
          seed.animate([{ transform: "scale(1)", opacity: 1 }, { transform: "scale(.62)", opacity: 1, offset: .55 }, { transform: "scale(2.6)", opacity: 1, offset: .8 }, { transform: "scale(3.2)", opacity: 0 }],
            { duration: 640, delay: Math.max(0, d - 430), easing: "cubic-bezier(.3, 0, .2, 1)", fill: "forwards" });
          const R = Math.round(maxR * 1.05);
          shock.animate([{ width: "16px", height: "16px", margin: "-8px 0 0 -8px", opacity: 1 }, { width: `${R * 2}px`, height: `${R * 2}px`, margin: `-${R}px 0 0 -${R}px`, opacity: 0 }],
            { duration: 1600, delay: Math.max(0, d - 30), easing: "cubic-bezier(.16, 1, .3, 1)", fill: "forwards" });
          setTimeout(() => { seed.remove(); shock.remove(); }, d + 1800);
        },
        cancel() { seed.remove(); shock.remove(); },
      };
    }

    // ── 2D: WebGL 이 없거나 '움직임 줄이기' 일 때 — 레이더처럼 가운데서 퍼짐(움직임 줄이기면 다 그려진 그림)
    function canvasHero() {
      layout();
      const ctx = cv.getContext("2d");
      let base, t0 = null;
      const resize = () => {
        base = document.createElement("canvas"); base.width = cv.width; base.height = cv.height;
        const b = base.getContext("2d"); b.scale(L.dpr, L.dpr); b.fillStyle = "rgba(243, 241, 236, .26)";
        for (const s of Object.values(st)) { const [x, y] = L.P(s); b.fillRect(x - .85, y - .85, 1.7, 1.7); }
      };
      resize();
      return {
        resize,
        alarms() { const since = t0 === null ? 0 : performance.now() - t0; [...pts].sort((a, b) => a.d - b.d).forEach((p, i) => (p.on = Math.max(650, since + 150) + i * 26)); },
        frame(t) {
          if (t0 === null) t0 = t;
          const since = reduce ? 1e9 : t - t0, rev = expo(Math.min(1, since / 1500)), { dpr, cx, cy, maxR } = L;
          ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height);
          if (rev < 1) {
            ctx.save(); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.beginPath(); ctx.arc(cx, cy, maxR * rev, 0, 7); ctx.clip();
            ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(base, 0, 0); ctx.restore();
            ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.beginPath(); ctx.arc(cx, cy, maxR * rev, 0, 7); ctx.strokeStyle = `rgba(255, 92, 46, ${0.35 * (1 - rev)})`; ctx.lineWidth = 1.5; ctx.stroke();
          } else ctx.drawImage(base, 0, 0);
          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
          for (const p of pts) {
            const age = since - (p.on ?? 0); if (age < 0) continue;
            const [x, y] = p.xy, strong = p.top >= 3, r = 2.6 + Math.min(p.n, 4) * 1.1 + (strong ? 1 : 0);
            const ign = Math.min(1, age / 700), flash = 1 - ign;
            const ph = reduce ? 0.35 : ((t / 2200) + ((x * 0.37 + y * 0.61) % 1)) % 1;
            if (flash > 0) { ctx.beginPath(); ctx.arc(x, y, r + 26 * ign, 0, 7); ctx.strokeStyle = `rgba(255, 140, 100, ${flash * .8})`; ctx.lineWidth = 2; ctx.stroke(); }
            ctx.beginPath(); ctx.arc(x, y, r + ph * 18, 0, 7); ctx.strokeStyle = `rgba(255, 92, 46, ${(1 - ph) * (strong ? .5 : .32) * ign})`; ctx.lineWidth = 1.4; ctx.stroke();
            ctx.shadowColor = "rgba(255, 92, 46, .9)"; ctx.shadowBlur = (strong ? 14 : 8) + flash * 18;
            ctx.beginPath(); ctx.arc(x, y, r * (0.6 + 0.4 * expo(ign)) + flash * 2, 0, 7); ctx.fillStyle = flash > .3 ? "#FFB59A" : strong ? "#FF5C2E" : "rgba(255, 128, 92, .85)"; ctx.fill();
            ctx.shadowBlur = 0;
          }
        },
      };
    }
  })();

  // ── 맨 아래 로고 'RIDEY.' 의 점: 잡아서 던지면 바닥·벽에 튀고(닿을 때 찌그러짐), 멈추면 스프링으로 제자리. 그냥 누르면 통 튀어 오름.
  //    보일 때 가끔 혼자 살짝 뛰어 '잡아 보라' 고 알림. 움직임 줄이기면 없음
  (() => {
    const foot = $("#foot"), dot = foot?.querySelector(".wordmark .dot"), link = dot?.closest("a"); if (!dot || reduce) return;
    const SPR = CSS.supports("transition-timing-function", "linear(0, 1)") ? getComputedStyle(document.documentElement).getPropertyValue("--spring").trim() : "cubic-bezier(.34, 1.56, .64, 1)";
    dot.classList.add("grab");
    let ball = null, st = null, raf = 0, played = 0, seenFoot = false, touched = false;
    const home = () => { const r = dot.getBoundingClientRect(), f = foot.getBoundingClientRect(); return { x: r.left + r.width / 2 - f.left, y: r.top + r.height / 2 - f.top, d: r.width }; };
    const draw = () => { ball.style.transform = `translate(${(st.x - st.r).toFixed(1)}px, ${(st.y - st.r).toFixed(1)}px)`; };
    const squash = (sx, sy) => ball.animate([{ scale: `${sx} ${sy}` }, { scale: "1 1" }], { duration: 260, easing: SPR });
    const settle = () => {
      cancelAnimationFrame(raf); const h = home();
      const a = ball.animate([{ transform: ball.style.transform }, { transform: `translate(${(h.x - st.r).toFixed(1)}px, ${(h.y - st.r).toFixed(1)}px)` }], { duration: 950, easing: SPR, fill: "forwards" });
      a.finished.then(() => { if (st?.held) return; ball?.remove(); ball = null; st = null; dot.style.visibility = ""; dot.animate([{ transform: "scale(1.3)" }, { transform: "none" }], { duration: 520, easing: SPR }); }).catch(() => {});
    };
    const step = (now) => {
      if (!st) return;
      const dt = Math.min(0.033, (now - st.t) / 1000); st.t = now;
      if (!st.held) {
        const W = foot.clientWidth, H = foot.clientHeight;
        st.vy += 2600 * dt; st.x += st.vx * dt; st.y += st.vy * dt;
        if (st.y > H - st.r) { const v = Math.abs(st.vy); st.y = H - st.r; st.vy = v > 90 ? -v * 0.66 : 0; st.vx *= 0.88; if (v > 260) squash(1.3, 0.72); }
        if (st.y < st.r) { st.y = st.r; st.vy = Math.abs(st.vy) * 0.6; }
        if (st.x < st.r || st.x > W - st.r) { st.x = Math.min(W - st.r, Math.max(st.r, st.x)); if (Math.abs(st.vx) > 260) squash(0.75, 1.25); st.vx *= -0.7; }
        if (st.vy === 0) st.vx *= 0.94;
        st.rest = st.vy === 0 && Math.abs(st.vx) < 25 ? st.rest + dt : 0;
        if (st.rest > 0.45 || now - st.thrown > 5000) { draw(); return settle(); }
      }
      draw(); raf = requestAnimationFrame(step);
    };
    const grab = (e) => {
      if (e.button > 0) return; e.preventDefault(); touched = true;
      if (!ball) {
        const h = home(); ball = document.createElement("i"); ball.className = "ball"; ball.setAttribute("aria-hidden", "true"); ball.style.width = ball.style.height = h.d + "px"; foot.appendChild(ball);
        ball.addEventListener("pointerdown", grab); ball.addEventListener("pointermove", move); ball.addEventListener("pointerup", release); ball.addEventListener("pointercancel", release);
        st = { x: h.x, y: h.y, vx: 0, vy: 0, r: h.d / 2, rest: 0, t: performance.now() }; dot.style.visibility = "hidden"; draw();   // opacity 는 CSS 떨어지기 애니메이션이 덮어써서 visibility 로
      }
      ball.getAnimations().forEach((a) => a.cancel()); cancelAnimationFrame(raf);
      const f = foot.getBoundingClientRect();
      Object.assign(st, { held: true, ox: e.clientX - f.left - st.x, oy: e.clientY - f.top - st.y, trail: [[performance.now(), e.clientX, e.clientY]], moved: 0, t: performance.now() });
      ball.classList.add("held"); try { ball.setPointerCapture(e.pointerId); } catch {}
      raf = requestAnimationFrame(step);
    };
    const move = (e) => {
      if (!st?.held) return;
      const f = foot.getBoundingClientRect(), nx = e.clientX - f.left - st.ox, ny = e.clientY - f.top - st.oy;
      st.moved += Math.hypot(nx - st.x, ny - st.y); st.x = nx; st.y = ny;
      st.trail.push([performance.now(), e.clientX, e.clientY]); if (st.trail.length > 6) st.trail.shift();
    };
    const release = () => {
      if (!st?.held) return; st.held = false; ball.classList.remove("held"); played = performance.now();
      const tr = st.trail, a = tr[0], b = tr[tr.length - 1], dt = Math.max(0.016, (b[0] - a[0]) / 1000);
      st.vx = (b[1] - a[1]) / dt; st.vy = (b[2] - a[2]) / dt;
      if (st.moved < 6) { st.vx = (Math.random() - 0.5) * 700; st.vy = -1100; }   // 그냥 누르면 통 튀어 오름
      const v = Math.hypot(st.vx, st.vy); if (v > 3200) { st.vx *= 3200 / v; st.vy *= 3200 / v; }
      st.thrown = performance.now(); st.rest = 0;
    };
    dot.addEventListener("pointerdown", grab);
    link?.addEventListener("click", (e) => { if (performance.now() - played < 600 || e.target === dot) e.preventDefault(); });   // 점을 갖고 놀았으면 맨 위로 가지 않음
    new IntersectionObserver(([e]) => (seenFoot = e.isIntersecting)).observe(foot);
    setInterval(() => { if (seenFoot && !ball && !touched && document.visibilityState === "visible") dot.animate([{ transform: "none" }, { transform: "translateY(-70%) scale(1.08, .94)", offset: 0.35 }, { transform: "none" }], { duration: 750, easing: SPR }); }, 5200);
  })();

  // ── 단추가 커서 쪽으로 살짝 끌려옴(자석) — 넓은 화면, 첫 화면 단추와 머리 '웹앱 열기'
  if (!reduce && matchMedia("(hover: hover)").matches) for (const b of $$(".hero .cta .btn, .nav .btn.solid, .try .btn")) {
    b.classList.add("mag");
    b.addEventListener("pointermove", (e) => { const r = b.getBoundingClientRect(); b.style.translate = `${((e.clientX - r.left - r.width / 2) * 0.22).toFixed(1)}px ${((e.clientY - r.top - r.height / 2) * 0.35).toFixed(1)}px`; });
    b.addEventListener("pointerleave", () => { b.style.translate = ""; });
  }

  // ── 05 실시간 전광판: 정류장 안내판처럼 점(LED)으로 그린 글자 — 지금 경보 자전거가 한 칸씩 흘러감.
  //    글자를 16줄짜리 작은 그림으로 그린 뒤 픽셀마다 켜진 점/꺼진 점. 한 칸씩 움직일 때만 다시 그림(초당 16번)
  (async () => {
    const box = $("#led"); if (!box) return;
    const cv = box.querySelector("canvas"), ctx = cv.getContext("2d"), ROWS = 16;
    const [row, st] = await Promise.all([liveSnap(), stationsP.catch(() => ({}))]);
    let msg = "RIDEY.   점 하나가 신호다   ●   서울 따릉이 5분마다 실시간   ●   ";
    if (row && row.bikes && row.bikes.length) {
      const top = [...row.bikes].sort((a, b) => (b.chain || 0) - (a.chain || 0)).slice(0, 18);
      msg = `지금 서울 경보 ${row.bikes.length}대   ●   ` + top.map((b) => { const s = st[b.station]; return `${s ? s.gu + " " + s.name.replace(/\s*\(.*\)$/, "") : "대여소 " + b.station} · ${b.bike} · ${b.chain}명 연속`; }).join("   ●   ") + "   ●   ";
      box.setAttribute("aria-label", `지금 서울 경보 ${row.bikes.length}대 — ` + top.slice(0, 3).map((b) => `${st[b.station]?.gu || ""} ${b.bike} ${b.chain}명 연속`).join(", "));
    }
    if (document.fonts) await document.fonts.ready;
    const m = document.createElement("canvas").getContext("2d", { willReadFrequently: true });
    const font = `800 14px "Pretendard Variable", Pretendard, -apple-system, "Apple SD Gothic Neo", sans-serif`;
    m.font = font; const w = Math.ceil(m.measureText(msg).width) + 2;
    m.canvas.width = w; m.canvas.height = ROWS; m.font = font; m.textBaseline = "middle"; m.fillStyle = "#fff"; m.fillText(msg, 0, ROWS / 2 + 1);
    const px = m.getImageData(0, 0, w, ROWS).data, on = new Uint8Array(w * ROWS);
    for (let i = 0; i < w * ROWS; i++) on[i] = px[i * 4 + 3] > 110 ? 1 : 0;
    let W, H, dpr, pitch, cols, lit, dim;
    const sprite = (r, glow, core, halo) => {
      const c = document.createElement("canvas"), s = Math.ceil((r + glow) * 2 * dpr); c.width = c.height = s;
      const g = c.getContext("2d"), cx = s / 2, grd = g.createRadialGradient(cx, cx, 0, cx, cx, s / 2);
      grd.addColorStop(0, core); grd.addColorStop(r / (r + glow) * 0.82, core); grd.addColorStop(r / (r + glow), halo); grd.addColorStop(1, "rgba(255, 92, 46, 0)");
      g.fillStyle = grd; g.fillRect(0, 0, s, s); return c;
    };
    const size = () => {
      const r = cv.getBoundingClientRect(); dpr = Math.min(2, devicePixelRatio || 1); W = r.width; H = r.height;
      cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
      pitch = H / ROWS; cols = Math.ceil(W / pitch) + 1;
      lit = sprite(pitch * 0.36, pitch * 0.55, "#FFB08F", "rgba(255, 92, 46, .45)"); dim = sprite(pitch * 0.3, 0, "rgba(255, 92, 46, .09)", "rgba(255, 92, 46, .09)");
    };
    let off = 0;
    const draw = () => {
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height);
      const sl = lit.width / dpr, sd = dim.width / dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      for (let c = 0; c < cols; c++) {
        const x = c * pitch + pitch / 2, src = (c + off) % w;
        for (let r = 0; r < ROWS; r++) {
          const y = r * pitch + pitch / 2;
          if (on[r * w + src]) ctx.drawImage(lit, x - sl / 2, y - sl / 2, sl, sl); else ctx.drawImage(dim, x - sd / 2, y - sd / 2, sd, sd);
        }
      }
    };
    size(); draw();
    if (reduce) return;
    let vis = false, last = 0;
    new IntersectionObserver(([e]) => (vis = e.isIntersecting)).observe(box);
    const loop = (t) => { if (vis && t - last > 62) { last = t; off = (off + 1) % w; draw(); } requestAnimationFrame(loop); };
    requestAnimationFrame(loop);
    let rt; addEventListener("resize", () => { clearTimeout(rt); rt = setTimeout(() => { size(); draw(); }, 150); });
  })();

  // ── 05 흐름: 신호 점 하나가 1 → 2 → 3 → 4 단계를 차례로 지나감(지나가는 단계의 동그라미가 켜짐)
  (() => {
    const flow = $(".flow"); if (!flow || reduce) return;
    const ns = $$(".flow .n"); if (ns.length < 2) return;
    const track = document.createElement("i"), dot = document.createElement("i");
    track.className = "flow-track"; dot.className = "flow-dot"; track.setAttribute("aria-hidden", "true"); dot.setAttribute("aria-hidden", "true");
    flow.append(track, dot); flow.classList.add("run");
    const pos = (n) => { const f = flow.getBoundingClientRect(), r = n.getBoundingClientRect(); return [r.left + r.width / 2 - f.left, r.top + r.height / 2 - f.top]; };
    const place = () => { const [x0, y0] = pos(ns[0]), [, y1] = pos(ns[ns.length - 1]); Object.assign(track.style, { left: x0 - 1 + "px", top: y0 + "px", height: y1 - y0 + "px" }); };
    let i = 0, timer = 0;
    const go = () => {
      place(); const [x, y] = pos(ns[i]);
      dot.style.transform = `translate(${x}px, ${y}px)`;
      ns.forEach((n, k) => n.classList.toggle("on", k === i));
      i = (i + 1) % ns.length;
    };
    new IntersectionObserver(([e]) => { clearInterval(timer); if (e.isIntersecting) { go(); timer = setInterval(go, 1600); } }).observe(flow);
    addEventListener("resize", place);
  })();

  // ── 어두운 구역(원리·실시간): 커서 둘레에만 점 격자가 드러남 — 화면 밑에 깔린 신호들
  if (!reduce && matchMedia("(hover: hover)").matches) for (const sec of $$("#how, #live")) {
    const spot = document.createElement("i"); spot.className = "spot"; spot.setAttribute("aria-hidden", "true"); sec.prepend(spot);
    sec.addEventListener("pointermove", (e) => { const r = sec.getBoundingClientRect(); sec.style.setProperty("--mx", `${(e.clientX - r.left).toFixed(0)}px`); sec.style.setProperty("--my", `${(e.clientY - r.top).toFixed(0)}px`); }, { passive: true });
  }

  // ── 앱 화면 사진: 커서 쪽으로 살짝 기울어짐(3D)
  if (!reduce && matchMedia("(hover: hover)").matches) for (const f of $$(".phones figure")) {
    const img = f.querySelector("img"); if (!img) continue;
    f.addEventListener("pointermove", (e) => { const r = img.getBoundingClientRect(), x = (e.clientX - r.left) / r.width - 0.5, y = (e.clientY - r.top) / r.height - 0.5; img.style.transform = `perspective(1000px) rotateY(${(x * 12).toFixed(2)}deg) rotateX(${(-y * 10).toFixed(2)}deg) translateY(-8px)`; });
    f.addEventListener("pointerleave", () => { img.style.transform = ""; });
  }

  // ── 02 왜: 숫자 밑에 점 그림 — '16만 건' 은 점 16개(점 하나 = 1만 건), 비율은 점 100개(점 하나 = 1%, 빈 점은 달마다 다른 범위). 카드가 나타날 때 차례로 켜짐
  (() => {
    const facts = $$("#why .fact"); if (facts.length < 3) return;
    const spec = [{ n: 16, solid: 16, hollow: 0, cls: "ink", cap: "점 하나 = 1만 건" }, { n: 100, solid: 49, hollow: 12, cls: "", cap: "점 하나 = 1% · 빈 점은 달마다 다른 범위" }, { n: 100, solid: 82, hollow: 9, cls: "", cap: "점 하나 = 1% · 빈 점은 달마다 다른 범위" }];
    facts.forEach((f, k) => {
      const sp = spec[k], g = document.createElement("div");
      g.className = `iarr${sp.n === 16 ? " few" : ""}${sp.cls ? " " + sp.cls : ""}`; g.setAttribute("aria-hidden", "true");
      g.innerHTML = Array.from({ length: sp.n }, (_, i) => `<i class="${i < sp.solid ? "s" : i < sp.solid + sp.hollow ? "h" : ""}" style="--j:${i}"></i>`).join("") + `<span>${sp.cap}</span>`;
      f.querySelector(".num").after(g);
    });
  })();

  // ── 01 한 대의 12일 — 하루에 한 줄: 그날의 대여를 시간 순서대로 점(빌리자마자 반납)·선(그냥 타고 감)으로, 고장 신고는 세로 막대
  (async () => {
    const box = $("#lrows"), fig = $("#ledger"); if (!box || !fig) return;
    let D; try { D = await (await fetch("data/spb69683.json")).json(); } catch { return; }
    const ev = [...D.duds.map((h) => [h, "d"]), ...D.rides.map((h) => [h, "r"]), ...D.reports.map((h) => [h, "R"])].sort((a, b) => a[0] - b[0]);
    const alarmAt = D.duds.reduce((best, h) => (Math.abs(h - D.alarm) < Math.abs(best - D.alarm) ? h : best), D.duds[0]);
    const firstAt = Math.min(...D.duds);
    // 시각은 버림(15:43:34 → 15:43) — 본문·보고서의 시각과 같게
    const hm = (h) => { const m = Math.floor((h % 24) * 60 + 1e-6); return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`; };
    const WD = ["일", "월", "화", "수", "목", "금", "토"];
    const NOTE = { 12: ["alarm", `<b>15:43</b>RIDEY 경보 — 서로 다른 두 번째 사람`], 13: ["", `<b>07:58</b>첫 고장 신고. 그 뒤에도 54번 더`],
                   16: ["", `<b>07:13</b>출근길 37분 사이 7명이 연달아`], 21: ["", "누군가 탔다 — 그래도 고쳐지지 않음"], 24: ["", `<b>17:18</b>두 번째 신고 → 사라짐`] };
    let html = "", n = 0;
    for (let d = 12; d <= 24; d++) {
      const row = ev.filter(([h]) => 12 + Math.floor(h / 24) === d), dots = row.filter(([, k]) => k === "d").length, rides = row.filter(([, k]) => k === "r").length;
      const wd = WD[new Date(2026, 5, d).getDay()];
      const [cls, note] = NOTE[d] || (row.length ? ["", ""] : ["quiet", ""]);
      const glyphs = row.map(([h, k], i) => {
        const t = `<b>6/${d} ${hm(h)}</b>`;
        if (k === "R") return `<i class="g rep" style="--i:${i}" data-t="${t}고장 신고"></i>`;
        if (k === "r") return `<i class="g dash" style="--i:${i}" data-t="${t}그냥 타고 감"></i>`;
        n++;
        const c = h === firstAt ? "first" : h === alarmAt ? "alarm" : "";
        const what = c === "first" ? "1번째 사람 · 한 명만으로는 경보 없음" : c === "alarm" ? "<i></i>2번째 사람 · RIDEY 경보" : `${n}번째 사람 · 빌리자마자 반납`;
        return `<i class="g dot${c ? " " + c : ""}" style="--i:${i}" data-t="${t}${what}"></i>`;
      }).join("");
      html += `<li class="lrow${cls ? " " + cls : ""}" style="--r:${d - 12}">` +
        `<span class="ld"><b>6/${d}</b><small>${wd}</small></span>` +
        `<span class="lg" aria-hidden="true">${glyphs || `<span class="lq">아무도 빌리지 않음</span>`}</span>` +
        `<span class="lc${dots ? "" : " zero"}" aria-hidden="true">${dots || "–"}</span><span class="lnote">${note}</span>` +
        `<span class="sr">6월 ${d}일 ${wd}요일: ${row.length ? `빌리자마자 반납 ${dots}명, 그냥 타고 감 ${rides}번.` : "아무도 빌리지 않음."}</span></li>`;
    }
    box.innerHTML = html;
    seen(fig, () => { decode(fig.querySelector(".lid b"), 900); setTimeout(() => fig.classList.add("done"), 2600); setTimeout(() => burst(fig, fig.querySelector(".g.dot.alarm"), 0.8), 900); }, 0.12);

    // 점에 올리면(손가락은 누르면) 말풍선 하나가 그 점 위로 — 시각과 몇 번째 사람인지
    const tip = document.createElement("div"); tip.className = "ltip"; tip.setAttribute("aria-hidden", "true"); fig.appendChild(tip);
    let hot = null, hide = 0;
    const show = (g) => {
      clearTimeout(hide);
      if (g === hot) return;
      hot?.classList.remove("hot"); hot = g;
      if (!g) { tip.classList.remove("on"); return; }
      g.classList.add("hot"); tip.innerHTML = g.dataset.t;
      const r = g.getBoundingClientRect(), f = fig.getBoundingClientRect(), w = tip.offsetWidth;
      const x = r.left + r.width / 2 - f.left, cx = Math.max(w / 2 + 10, Math.min(f.width - w / 2 - 10, x));
      tip.style.left = `${cx}px`; tip.style.top = `${r.top - f.top}px`; tip.style.setProperty("--dx", `${x - cx}px`);
      tip.classList.add("on");
    };
    const later = () => { clearTimeout(hide); hide = setTimeout(() => show(null), 140); };
    box.addEventListener("pointerover", (e) => { const g = e.target.closest?.(".g[data-t]"); g ? show(g) : later(); });
    box.addEventListener("pointerleave", (e) => { if (e.pointerType !== "touch") later(); });
    document.addEventListener("pointerdown", (e) => { if (!e.target.closest?.(".g[data-t]")) show(null); }, { passive: true });
    addEventListener("scroll", () => hot && show(null), { passive: true });
  })();

  // ── 03 원리 — 길이 그어지는 동안 선과 점이 하나씩, 서로 다른 두 번째 점에서 카드가 한 번 빛남
  (() => {
    const box = $("#morse"); if (!box) return;
    const ms = $$("#morse .m"); let t = [];
    const play = () => {
      t.forEach(clearTimeout); t = []; box.classList.remove("go", "flash"); ms.forEach((m) => m.classList.remove("on"));
      if (reduce) { ms.forEach((m) => m.classList.add("on")); return; }
      void box.offsetWidth; box.classList.add("go");
      ms.forEach((m, i) => t.push(setTimeout(() => {
        m.classList.add("on");
        if (m.classList.contains("signal")) { box.classList.add("flash"); burst(box, m.querySelector("i")); t.push(setTimeout(() => box.classList.remove("flash"), 700)); }
      }, 200 + i * 900)));
    };
    seen(box, play, 0.45);
    $("#morse-again")?.addEventListener("click", play);
  })();

  // ── 03 직접 찍어 보기 — 단추가 곧 브랜드의 점. 짧게 누르면 점(빌리자마자 반납), 길게 누르면 선(타고 감 — 누르는 동안 자람).
  //    누를 때마다 다른 사람. 점이 서로 다른 두 사람째 이어지면 경보(카드가 빛나고, 안드로이드는 진동), 선이 오면 연쇄가 끊김.
  //    소리는 '소리 켜기' 를 눌렀을 때만(누르는 동안 삐— 전신기처럼, Web Audio).
  (() => {
    const btn = $("#key-btn"), strip = $("#key-strip"), say = $("#key-say"), card = $("#key"); if (!btn) return;
    const LONG = 220, MAX = 16;
    let t0 = 0, held = false, grow = null, raf = 0, chain = 0, ac = null, osc = null, soundOn = false;
    const buzz = (p) => { try { navigator.vibrate?.(p); } catch {} };
    const tone = (f, dur, at = 0) => {
      if (!soundOn || !ac) return;
      const t = ac.currentTime + at, o = ac.createOscillator(), g = ac.createGain();
      o.frequency.value = f; g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.08, t + 0.01); g.gain.setValueAtTime(0.08, t + dur - 0.03); g.gain.linearRampToValueAtTime(0, t + dur);
      o.connect(g).connect(ac.destination); o.start(t); o.stop(t + dur + 0.02);
    };
    const hum = (on) => {   // 누르는 동안만 소리
      if (!soundOn || !ac) return;
      if (on && !osc) { const o = ac.createOscillator(), g = ac.createGain(); o.frequency.value = 660; g.gain.value = 0; g.gain.linearRampToValueAtTime(0.07, ac.currentTime + 0.01); o.connect(g).connect(ac.destination); o.start(); osc = [o, g]; }
      if (!on && osc) { const [o, g] = osc; g.gain.cancelScheduledValues(ac.currentTime); g.gain.setValueAtTime(g.gain.value, ac.currentTime); g.gain.linearRampToValueAtTime(0, ac.currentTime + 0.03); o.stop(ac.currentTime + 0.05); osc = null; }
    };
    const add = (cls, w) => {
      const g = document.createElement("li"); g.className = `g ${cls}${reduce ? "" : " in"}`; if (w) g.style.setProperty("--w", `${w}px`);
      strip.appendChild(g);
      const kids = [...strip.children].filter((c) => !c.classList.contains("out"));
      if (kids.length > MAX) { const old = kids[0]; old.classList.add("out"); setTimeout(() => old.remove(), reduce ? 0 : 350); }
      return g;
    };
    const tell = (html) => { say.innerHTML = html; card.classList.toggle("alarm", chain >= 2); };
    const flash = () => { card.classList.add("flash"); setTimeout(() => card.classList.remove("flash"), 700); };
    const tick = () => {   // 길게 누르는 중: 선이 자람
      const ms = performance.now() - t0;
      if (ms >= LONG) {
        if (!grow) { grow = add("dash grow", 16); hum(true); }
        grow.style.setProperty("--w", `${Math.min(120, 16 + (ms - LONG) * 0.13)}px`);
      }
      raf = requestAnimationFrame(tick);
    };
    const down = () => {
      if (held) return; held = true; t0 = performance.now(); grow = null;
      btn.classList.add("down"); btn.classList.remove("tap"); hum(true);
      raf = requestAnimationFrame(tick);
    };
    const up = () => {
      if (!held) return; held = false; cancelAnimationFrame(raf); hum(false);
      btn.classList.remove("down"); void btn.offsetWidth; btn.classList.add("tap");
      if (grow) {   // 선 — 누군가 제대로 탔음: 연쇄가 끊김
        grow.classList.remove("grow");
        tell(chain >= 2 ? "누군가 제대로 타고 갔습니다 — 연쇄가 끊기고 <b>경보가 꺼집니다</b>." : "제대로 탄 대여(선) — 괜찮습니다.");
        chain = 0; card.classList.remove("alarm"); grow = null; return;
      }
      chain++;   // 점 — 빌리자마자 반납
      const gd = add(`dot${chain === 1 ? " first" : chain === 2 ? " alarm" : ""}`);
      if (chain >= 2) requestAnimationFrame(() => burst(card, gd, chain === 2 ? 1 : 0.6));
      if (chain === 1) { buzz(12); tell("한 사람이 빌리자마자 반납 — 한 명은 실수일 수 있어 아직 조용합니다."); }
      else if (chain === 2) { buzz([40, 60, 40]); tone(1320, 0.09, 0.05); tone(1320, 0.09, 0.2); flash(); tell("서로 다른 두 번째 사람도 바로 반납 → <b>경보</b>. 지도에 점이 켜지고 정비 목록에 오릅니다."); }
      else { buzz([30, 40, 30, 40, 90]); tone(1568, 0.08, 0.05); tone(1568, 0.08, 0.17); tone(1568, 0.08, 0.29); flash(); tell(`<b>${chain}명 연속</b> — 더 강한 경보. 다음 사람에게 '피하세요' 라고 알려 줍니다.`); }
    };
    btn.addEventListener("pointerdown", (e) => { if (e.button > 0) return; e.preventDefault(); btn.setPointerCapture?.(e.pointerId); btn.focus({ preventScroll: true }); down(); });
    btn.addEventListener("pointerup", up); btn.addEventListener("pointercancel", up); btn.addEventListener("lostpointercapture", up);
    btn.addEventListener("contextmenu", (e) => e.preventDefault());
    btn.addEventListener("keydown", (e) => { if ((e.key === " " || e.key === "Enter") && !e.repeat) { e.preventDefault(); down(); } else if (e.key === " " || e.key === "Enter") e.preventDefault(); });
    btn.addEventListener("keyup", (e) => { if (e.key === " " || e.key === "Enter") { e.preventDefault(); up(); } });
    btn.addEventListener("blur", up);
    $("#key-reset")?.addEventListener("click", () => { strip.innerHTML = ""; chain = 0; card.classList.remove("alarm"); tell("짧게 두 번 눌러 보세요."); });
    $("#key-sound")?.addEventListener("click", (e) => {
      soundOn = !soundOn; e.currentTarget.setAttribute("aria-pressed", soundOn); e.currentTarget.textContent = soundOn ? "소리 끄기" : "소리 켜기";
      if (soundOn) { try { ac = ac || new (window.AudioContext || window.webkitAudioContext)(); ac.resume?.(); } catch { soundOn = false; } }
    });
  })();

  // ── 04 검증 막대 (보고서 5-1): 앞서 서로 다른 사람 몇 명이 바로 반납 → 다음 사람도
  (() => {
    const bars = $("#bars"); if (!bars) return;
    const SETS = [["서울 1월", [2.5, 10.6, 37.1, 59.2]], ["서울 3월", [2.6, 10.6, 35.5, 54.6]], ["서울 6월", [2.5, 11.1, 35.3, 55.5]], ["대전 5월", [2.9, 17.7, 41.6, 58.5]], ["대전 10월", [2.6, 16.3, 43.6, 61.3]]];
    const LB = ["0명", "1명", "2명 · 경보", "3명+"];
    bars.innerHTML = LB.map((l, i) => `<div class="bar${i === 2 ? " hot" : i === 3 ? " hotter" : ""}" style="--i:${i}"><span class="v">0%</span><span class="colw"><span class="col"></span></span><span class="x">${l}</span></div>`).join("");
    const bs = $$("#bars .bar");
    $("#sets").innerHTML = SETS.map(([n]) => `<button role="tab" type="button" aria-selected="false">${n}</button>`).join("");
    const tabs = $$("#sets button");
    const show = (k, first) => {
      tabs.forEach((b, i) => b.setAttribute("aria-selected", i === k));
      SETS[k][1].forEach((v, i) => {
        bs[i].querySelector(".col").style.height = (v / 64 * 100) + "%";
        const vEl = bs[i].querySelector(".v"); vEl.textContent = v + "%";
        if (first) { delete vEl.dataset.counted; countUp(vEl, 1300); }
      });
    };
    tabs.forEach((b, i) => b.addEventListener("click", () => show(i)));
    seen(bars, () => show(0, true), 0.3);
  })();

  // ── 04 하루 재생 (6월 15일) — 헛대여(회색)·경보(신호색)·경보 뒤 또 헛걸음(흰색)·뒤늦은 고장 신고(파랑)
  (async () => {
    const cv = $("#replay"); if (!cv) return;
    const ctx = cv.getContext("2d");
    const COL = ["#6B7078", "#FF5C2E", "#F3F1EC", "#7C9BFF"], SPEED = 3600;
    let st, ev = [], base, P, dpr, pulses = [], clock = 0, idx = 0, playing = !reduce, visible = false, last = 0;
    const count = [0, 0, 0, 0], lastSt = {};
    try { [st, ev] = await Promise.all([stationsP, fetch("data/replay.json").then((r) => r.json()).then((r) => r.events)]); } catch { $("#clock").textContent = "—"; return; }
    const B = box(st);
    function layout() {
      const s = sizeCanvas(cv), a = aspect(B); dpr = s.dpr;
      const mw = Math.min(s.W * 0.96, s.H * 0.94 * a), mh = mw / a;
      P = fit(B, (s.W - mw) / 2, (s.H - mh) / 2, mw);
      base = document.createElement("canvas"); base.width = cv.width; base.height = cv.height;
      const b = base.getContext("2d"); b.scale(dpr, dpr); b.fillStyle = "rgba(243, 241, 236, .22)";
      for (const v of Object.values(st)) { const [x, y] = (v.p = P(v)); b.fillRect(x - .8, y - .8, 1.6, 1.6); }
    }
    function render(now) {
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height); ctx.drawImage(base, 0, 0); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      pulses = pulses.filter((p) => now - p.t < p.life);
      for (const p of pulses) {
        const a = 1 - (now - p.t) / p.life, g = expo(1 - a);
        ctx.globalAlpha = a * (p.k ? .95 : .55); ctx.fillStyle = COL[p.k];
        if (p.k) { ctx.shadowColor = COL[p.k]; ctx.shadowBlur = 10 * a; }
        ctx.beginPath(); ctx.arc(p.x, p.y, p.k ? 3 + 4 * g : 1.8, 0, 7); ctx.fill(); ctx.shadowBlur = 0;
        if (p.k) { ctx.globalAlpha = a * .45; ctx.strokeStyle = COL[p.k]; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(p.x, p.y, 7 + 16 * g, 0, 7); ctx.stroke(); }
      }
      ctx.globalAlpha = 1;
    }
    function loop(now) {
      requestAnimationFrame(loop);
      if (!visible) { last = now; return; }
      const dt = Math.min(0.1, (now - last) / 1000); last = now;
      if (playing) {
        clock += dt * SPEED;
        while (idx < ev.length && ev[idx][0] <= clock) {
          const [, k, s, bike] = ev[idx++]; count[k]++;
          const S = st[s] || st[lastSt[bike]]; if (s) lastSt[bike] = s;
          if (S && S.p) pulses.push({ x: S.p[0], y: S.p[1], k, t: now, life: k ? 2600 : 900 });
        }
        if (idx >= ev.length && clock > ev[ev.length - 1][0] + 4 * SPEED) { clock = 0; idx = 0; count.fill(0); }
        const h = Math.floor(clock / 3600), m = Math.floor((clock % 3600) / 60);
        $("#clock").textContent = (h >= 24 ? "+1 " : "") + String(h % 24).padStart(2, "0") + ":" + String(m).padStart(2, "0");
        count.forEach((c, i) => ($("#c" + i).textContent = ko(c)));
      }
      render(now);
    }
    layout(); requestAnimationFrame(loop);
    new IntersectionObserver((es) => (visible = es[0].isIntersecting), { threshold: 0.05 }).observe(cv);
    const btn = $("#playbtn"); btn.textContent = playing ? "일시정지" : "재생";
    btn.addEventListener("click", () => { playing = !playing; btn.textContent = playing ? "일시정지" : "재생"; });
    let rt; addEventListener("resize", () => { clearTimeout(rt); rt = setTimeout(layout, 150); });
  })();

  // ── 05 실시간 채점 — 공개 뷰에서 지금 숫자로 (못 받으면 적어 둔 숫자)
  (async () => {
    if (!$("#livescore")) return;
    seen($("#ls-pct"), () => setTimeout(() => countUp($("#ls-pct"), 1600), 200), 0.6);
    try {
      const [row] = await sb("live_snapshot?select=at,score:body->score");
      const sc = row && row.score;
      if (sc && sc.scored >= 100) {
        const n = sc.scored, k = sc.next_rider_dud, p = k / n, z = 1.96, d = 1 + z * z / n;
        const c = (p + z * z / (2 * n)) / d, m = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d, at = new Date(row.at + "+09:00");
        if (!$("#ls-pct").dataset.counted) $("#ls-pct").textContent = Math.round(p * 100) + "%";
        $("#ls-n").textContent = ko(n); $("#ls-k").textContent = ko(k);
        $("#ls-ci").textContent = `${Math.round((c - m) * 100)}~${Math.round((c + m) * 100)}%`; $("#ls-w").textContent = ko(sc.waiting);
        const md = sc.model || {};
        if (md.n >= 30) { $("#ls-mp").textContent = md["pred_%"] + "%"; $("#ls-mr").textContent = md["real_%"] + "%"; $("#ls-mn").textContent = ko(md.n); $("#ls-model").hidden = false; }
        $("#ls-at").textContent = `${at.getMonth() + 1}월 ${at.getDate()}일 ${String(at.getHours()).padStart(2, "0")}:${String(at.getMinutes()).padStart(2, "0")}`;
      }
    } catch {}
  })();
  (() => {
    const bars = $("#ls-bars"); if (!bars) return;
    const LS = [["2026-09-27",285,86],["2026-09-28",366,112],["2026-09-29",345,109],["2026-09-30",332,104],["2026-10-01",327,93],["2026-10-02",280,88],
      ["2026-10-03",259,77],["2026-10-04",297,70],["2026-10-05",296,84],["2026-10-06",306,119],["2026-10-07",267,69]];
    const BASE = 2.5, TOP = 50, md = (s) => s.slice(5).split("-").map(Number).join("/");
    function draw(rows) {
      const d = rows.filter(([, n]) => n >= 100); if (d.length < 3) return;
      const pct = d.map(([, n, k]) => (100 * k) / n), lo = Math.min(...pct), hi = Math.max(...pct);
      bars.innerHTML = d.map((x, i) => `<div class="db" style="--h:${Math.min(100, pct[i] / TOP * 100).toFixed(1)}%;--i:${i}"><i>${Math.round(pct[i])}</i></div>`).join("") + `<div class="base" style="bottom:${BASE / TOP * 100}%"></div>`;
      bars.setAttribute("aria-label", "날마다 경보 뒤 다음 사람도 바로 반납한 비율: " + d.map(([day], i) => `${md(day)} ${Math.round(pct[i])}%`).join(", ") + ` (평소 ${BASE}%)`);
      $("#ls-d0").textContent = md(d[0][0]); $("#ls-d1").textContent = md(d[d.length - 1][0]);
      $("#ls-days-head").textContent = `${d.length}일 하루도 빠짐없이 평소의 ${Math.floor(lo / BASE)}배 이상`;
      $("#ls-range").textContent = `${Math.round(lo)}~${Math.round(hi)}%`;
    }
    draw(LS);
    sb("ops_alarm_days?select=day,scored,hit&order=day").then((r) => Array.isArray(r) && draw(r.map((x) => [x.day, x.scored, x.hit]))).catch(() => {});
  })();

  // ── 06 번호로 확인 (6월 15일 아침 시연 목록) — [번호, 대여소 번호, 대여소, 연쇄, 단계, 마지막]
  (async () => {
    const form = $("#lookup"); if (!form) return;
    let m; try { m = await (await fetch("data/morning.json")).json(); } catch { return; }
    const norm = (raw) => { const g = String(raw).toUpperCase().match(/SPB\s*-?\s*(\d{3,6})/) || String(raw).match(/^\s*(\d{3,6})\s*$/); return g ? "SPB-" + g[1].padStart(5, "0") : String(raw).trim().toUpperCase(); };
    const out = $("#result");
    function lookup(raw) {
      const id = norm(raw), hit = m.bikes.find((b) => b[0] === id);
      if (!/^SPB-\d{5}$/.test(id)) { out.className = "result"; out.innerHTML = `번호는 SPB- 뒤에 숫자 5자리예요 (예: SPB-69683).`; return; }
      out.className = "result"; void out.offsetWidth;   // 같은 결과를 다시 눌러도 다시 튀어나오게
      if (hit) {
        const [bike, , stn, chain, level, lastDud] = hit;
        out.className = "result warn pop";
        out.innerHTML = `<h4><i class="rdot" aria-hidden="true"></i>${esc(bike)} 는 피하세요</h4>어제까지 <b>서로 다른 ${chain}명</b>이 빌리자마자 반납했어요 (마지막 ${esc(lastDud)}, ${esc(stn)}). ` +
          `이런 자전거는 다음 사람도 ${level === "빨강" ? "절반 넘게" : "3명 중 1명꼴로"} 바로 반납했어요. 옆 자전거를 고르세요.`;
        setTimeout(() => burst(out, out.querySelector(".rdot"), 0.7), 120);
      } else { out.className = "result ok pop"; out.innerHTML = `<h4>${esc(id)} — 타도 괜찮아요</h4>어제까지 기록에 빌리자마자 반납한 연쇄가 없어요.`; }
    }
    form.addEventListener("submit", (e) => { e.preventDefault(); lookup($("#bike").value); });
    const picks = [m.bikes[0][0], (m.bikes.find((b) => b[4] === "노랑") || m.bikes[1])[0], "SPB-12345"];
    for (const p of picks) {
      const b = document.createElement("button"); b.type = "button"; b.className = "chip"; b.textContent = p;
      b.addEventListener("click", () => { $("#bike").value = p; lookup(p); });
      $("#samples").appendChild(b);
    }
  })();
})();
