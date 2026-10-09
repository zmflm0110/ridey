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
      { duration: 700, easing: getComputedStyle(document.documentElement).getPropertyValue("--spring").trim() || "ease-out" }));
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
  $$(".head").forEach((h) => heads.observe(h));
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
  //     레이더처럼 가운데서 서울이 퍼져 나오고, 경보 점이 가까운 곳부터 차례로 켜진다. 몇 초마다 한 곳에 꼬리표.
  (async () => {
    const cv = $("#livemap"); if (!cv) return;
    const ctx = cv.getContext("2d");
    const st = await stationsP, B = box(st);
    let marks = [], live = false;
    try {
      const [row] = await sb("live_snapshot?select=at,bikes:body->bikes");
      if (row && row.bikes && row.bikes.length) {
        live = true; marks = row.bikes.map((b) => [b.station, b.chain, b.bike]);
        const at = new Date(row.at + "+09:00"), hh = String(at.getHours()).padStart(2, "0"), mm = String(at.getMinutes()).padStart(2, "0");
        $("#live-n").textContent = row.bikes.length;
        $("#live-d").textContent = `${at.getMonth() + 1}월 ${at.getDate()}일 ${hh}:${mm} 기준 · 클라우드가 5분마다 다시 셉니다`;
      }
    } catch {}
    if (!live) {
      try {
        const m = await (await fetch("data/morning.json")).json();
        marks = m.bikes.map((b) => [b[1], b[3], b[0]]);
        $("#live-k").textContent = "6월 15일 아침, 고장 의심 따릉이"; $("#live-n").textContent = m.bikes.length;
        $("#live-d").textContent = "시연 자료 — 지금은 실시간 목록을 받지 못했어요"; $("#hero-src").textContent = "서울 따릉이 · 2026년 6월 15일 실제 기록";
      } catch {}
    }
    setTimeout(() => countUp($("#live-n"), 1800), reduce ? 0 : 1100);
    const by = {};
    for (const [id, chain, bike] of marks) { const s = st[id]; if (!s) continue; const p = (by[id] = by[id] || { s, n: 0, top: 0, bike }); p.n++; if (chain > p.top) { p.top = chain; p.bike = bike; } }
    const pts = Object.values(by);
    let base, W, H, dpr, cx, cy, maxR, running = true, t0 = null;
    function layout() {
      ({ W, H, dpr } = sizeCanvas(cv));
      const mobile = W < 760, a = aspect(B);
      const mw = mobile ? W * 1.08 : Math.min(W * 0.62, (H * 0.84) * a), mh = mw / a;
      const ox = mobile ? (W - mw) / 2 : Math.min(W - mw - 12, W * 0.66 - mw / 2), oy = mobile ? H - mh - 40 : Math.max(70, (H - mh) / 2 - 20);
      const P = fit(B, ox, oy, mw);
      cx = ox + mw / 2; cy = oy + mh / 2; maxR = Math.hypot(mw, mh) / 2 + 30;
      base = document.createElement("canvas"); base.width = cv.width; base.height = cv.height;
      const b = base.getContext("2d"); b.scale(dpr, dpr); b.fillStyle = "rgba(243, 241, 236, .26)";
      for (const s of Object.values(st)) { const [x, y] = P(s); b.fillRect(x - .85, y - .85, 1.7, 1.7); }
      pts.forEach((p) => { p.xy = P(p.s); p.d = Math.hypot(p.xy[0] - cx, p.xy[1] - cy); });
      [...pts].sort((a, b) => a.d - b.d).forEach((p, i) => (p.on = 650 + i * 26));   // 가운데부터 차례로 켜짐
    }
    function draw(t) {
      if (t0 === null) t0 = t;
      const since = reduce ? 1e9 : t - t0, rev = expo(Math.min(1, since / 1500));
      ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, cv.width, cv.height);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      if (rev < 1) {   // 레이더처럼 퍼지는 원 안만 + 가장자리 고리
        ctx.save(); ctx.beginPath(); ctx.arc(cx, cy, maxR * rev, 0, 7); ctx.clip();
        ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(base, 0, 0); ctx.restore(); ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        ctx.beginPath(); ctx.arc(cx, cy, maxR * rev, 0, 7); ctx.strokeStyle = `rgba(255, 92, 46, ${0.35 * (1 - rev)})`; ctx.lineWidth = 1.5; ctx.stroke();
      } else { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.drawImage(base, 0, 0); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); }
      for (const p of pts) {
        const age = since - p.on; if (age < 0) continue;
        const [x, y] = p.xy, strong = p.top >= 3, r = 2.6 + Math.min(p.n, 4) * 1.1 + (strong ? 1 : 0);
        const ign = Math.min(1, age / 700), flash = 1 - ign;   // 켜지는 순간 크게 번쩍
        const ph = reduce ? 0.35 : ((t / 2200) + ((x * 0.37 + y * 0.61) % 1)) % 1;
        if (flash > 0) { ctx.beginPath(); ctx.arc(x, y, r + 26 * ign, 0, 7); ctx.strokeStyle = `rgba(255, 140, 100, ${flash * .8})`; ctx.lineWidth = 2; ctx.stroke(); }
        ctx.beginPath(); ctx.arc(x, y, r + ph * 18, 0, 7); ctx.strokeStyle = `rgba(255, 92, 46, ${(1 - ph) * (strong ? .5 : .32) * ign})`; ctx.lineWidth = 1.4; ctx.stroke();
        ctx.shadowColor = "rgba(255, 92, 46, .9)"; ctx.shadowBlur = (strong ? 14 : 8) + flash * 18;
        ctx.beginPath(); ctx.arc(x, y, r * (0.6 + 0.4 * expo(ign)) + flash * 2, 0, 7); ctx.fillStyle = flash > .3 ? "#FFB59A" : strong ? "#FF5C2E" : "rgba(255, 128, 92, .85)"; ctx.fill();
        ctx.shadowBlur = 0;
      }
    }
    const loop = (t) => { if (running) draw(t); requestAnimationFrame(loop); };
    layout(); requestAnimationFrame(loop);
    new IntersectionObserver(([e]) => (running = e.isIntersecting)).observe(cv);
    let rt; addEventListener("resize", () => { clearTimeout(rt); rt = setTimeout(layout, 150); });
    // 꼬리표: 몇 초마다 경보 점 하나 옆에 '몇 명 연속 · 어디' (넓은 화면, 글·숫자와 안 겹치는 자리만)
    const blips = $("#blips");
    if (blips && !reduce) {
      let last = null;
      setInterval(() => {
        if (!running || W < 760) return;
        const ok = pts.filter((p) => p !== last && p.xy[0] > W * 0.47 && p.xy[0] < W - 230 && p.xy[1] > 110 && p.xy[1] < H - 360);
        if (!ok.length) return;
        const p = (last = ok[Math.floor(Math.random() * ok.length)]);
        const el = document.createElement("div"); el.className = "blip";
        el.style.left = p.xy[0] + "px"; el.style.top = p.xy[1] + "px";
        el.innerHTML = `<b>${p.top}명 연속</b>${esc(p.s.gu)} · ${esc(p.bike || "")}`;
        blips.appendChild(el);
        requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add("on")));
        setTimeout(() => el.classList.remove("on"), 2600); setTimeout(() => el.remove(), 3400);
      }, 3200);
    }
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
    seen(fig, () => setTimeout(() => fig.classList.add("done"), 2600), 0.12);

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
        if (m.classList.contains("signal")) { box.classList.add("flash"); t.push(setTimeout(() => box.classList.remove("flash"), 700)); }
      }, 200 + i * 900)));
    };
    seen(box, play, 0.45);
    $("#morse-again")?.addEventListener("click", play);
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
        out.innerHTML = `<h4>${esc(bike)} 는 피하세요</h4>어제까지 <b>서로 다른 ${chain}명</b>이 빌리자마자 반납했어요 (마지막 ${esc(lastDud)}, ${esc(stn)}). ` +
          `이런 자전거는 다음 사람도 ${level === "빨강" ? "절반 넘게" : "3명 중 1명꼴로"} 바로 반납했어요. 옆 자전거를 고르세요.`;
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
