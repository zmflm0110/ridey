// 소개 사이트(site/) 검사 — 사이트를 만든 그대로(tools/build_site.py) 임시 폴더에서 띄우고, 구역마다 눌러 본다. 실패하면 종료 코드 1.
//   node tests/web/site.test.js        (PYTHON=.venv/bin/python 로 파이썬 지정 가능 · NODE_PATH 에 playwright)
// 보는 것: 화면 오류 없음 · 대여소 자료를 못 받아도 깨지지 않음 · '직접 찍어 보기' 규칙(점 둘 = 경보, 선 = 끊김) · 12일 표 · 점 그림 수 = 글자 수 ·
//         움직임 줄이기에서도 숫자가 나옴 · 진행 기록 쪽 머리 · 폰 화면에서 가로로 넘치지 않음. 클라우드(Supabase)는 막고 적어 둔 값으로만.
const { spawn, execFileSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const { launch } = require("./browser");
const ROOT = path.resolve(__dirname, "../..");
const PY = process.env.PYTHON || "python3";
const PORT = 8690 + Math.floor(Math.random() * 100);
const BASE = `http://127.0.0.1:${PORT}/`;
const fails = [];
const check = (ok, what) => { console.log((ok ? "  ✓ " : "  ✗ ") + what); if (!ok) fails.push(what); };
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "hz-site-"));
  execFileSync(PY, [path.join(ROOT, "tools/build_site.py"), "--out", dir], { stdio: "ignore" });
  const srv = spawn(PY, ["-m", "http.server", String(PORT), "--bind", "127.0.0.1", "--directory", dir], { stdio: "ignore" });
  for (let i = 0; i < 50; i++) { try { await fetch(BASE); break; } catch { await wait(100); } }
  const browser = await launch();
  const open = async (opts = {}, setup) => {
    const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, colorScheme: "dark", locale: "ko-KR", serviceWorkers: "block", ...opts });
    await ctx.route(/supabase\.co|cdn\.jsdelivr\.net/, (r) => r.abort());   // 클라우드·글꼴 CDN 은 막음 — 결과가 인터넷에 안 흔들리게(없으면 적어 둔 값으로)
    const page = await ctx.newPage(), errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => { if (m.type() === "error" && !/Failed to load resource|net::ERR/.test(m.text())) errors.push(m.text()); });
    if (setup) await setup(ctx, page);
    return { ctx, page, errors };
  };
  const press = async (page, ms) => {   // 점 단추 누르기(누른 시간만큼)
    const b = await (await page.$("#key-btn")).boundingBox();
    await page.mouse.move(b.x + b.width / 2, b.y + b.height / 2); await page.mouse.down(); await wait(ms); await page.mouse.up(); await wait(120);
  };
  const jump = (page, sel) => page.evaluate((sel) => { document.documentElement.style.scrollBehavior = "auto"; document.querySelector(sel).scrollIntoView({ block: "center" }); }, sel);

  try {
    // ── 1. 첫 화면·전체 흐름
    {
      const { ctx, page, errors } = await open();
      await page.goto(BASE, { waitUntil: "networkidle" }); await wait(1800);
      const n = await page.textContent("#live-n");
      check(/^\d[\d,]*$/.test(n.trim()) && +n.replace(/,/g, "") > 0, `첫 화면 큰 숫자가 채워짐 (${n.trim()})`);
      check(await page.evaluate(() => !!document.querySelector(".hero h1 .pd")), "제목 마침표가 점(.pd)으로 바뀜");
      check(await page.evaluate(() => document.querySelector(".hero h1").textContent.trim().endsWith(".")), "제목 글자에는 마침표가 남아 있음(복사·화면 읽기)");
      check(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), "가로로 넘치지 않음(넓은 화면)");
      const og = await page.evaluate(() => document.querySelector('meta[property="og:image"]')?.content);
      check(!!og && /\/img\/og\.png$/.test(og) && (await fetch(BASE + "img/og.png")).ok, "링크 미리보기(og:image) 이미지가 있음");
      // 12일 표
      await jump(page, "#ledger"); await wait(1200);
      const rows = await page.$$eval("#lrows .lrow", (r) => r.length);
      const dots = await page.$$eval("#lrows .g.dot", (r) => r.length), alarm = await page.$$eval("#lrows .g.dot.alarm", (r) => r.length), first = await page.$$eval("#lrows .g.dot.first", (r) => r.length);
      check(rows === 13 && dots === 73 && alarm === 1 && first === 1, `12일 표: 13줄·점 73·경보 점 1·첫 점 1 (${rows}/${dots}/${alarm}/${first})`);
      await wait(1500);
      check((await page.textContent("#ledger .lid b")).trim() === "SPB-69683", "번호판이 제 번호로 풀림");
      await page.hover("#lrows .g.dot.alarm"); await wait(500);
      const tip = (await page.textContent(".ltip")).replace(/\s+/g, " ");
      check(/6\/12 15:43/.test(tip) && /2번째 사람/.test(tip), `말풍선: 경보 점 → 시각·몇 번째 (${tip.trim()})`);
      // 점 그림 = 카드 글자
      const arr = await page.$$eval("#why .fact", (fs) => fs.map((f) => [f.querySelector(".num").textContent.replace(/\s+/g, ""), f.querySelectorAll(".iarr i.s").length, f.querySelectorAll(".iarr i.h").length]));
      const ok = arr.length === 3 && arr.every(([t, s, h]) => { const r = t.match(/^(\d+)~(\d+)%$/), c = t.match(/^(\d+)만건$/); return r ? s === +r[1] && s + h === +r[2] : c ? s === +c[1] : false; });
      check(ok, `왜(02) 점 그림이 카드 글자와 같은 수 (${arr.map((a) => a.join("/")).join(" · ")})`);
      // 직접 찍어 보기
      await jump(page, "#key"); await wait(1200);
      await press(page, 60);
      check(await page.$$eval("#key-strip .g", (g) => g.length === 1 && g[0].classList.contains("first")) && !(await page.evaluate(() => document.querySelector("#key").classList.contains("alarm"))), "짧게 한 번 = 빈 점, 아직 경보 없음");
      await press(page, 60);
      check(await page.evaluate(() => document.querySelector("#key").classList.contains("alarm")) && /경보/.test(await page.textContent("#key-say")), "짧게 두 번째 = 경보");
      await wait(300);
      check((await page.$$("#key .fx .sw")).length > 0, "경보 순간 충격파가 생김");
      await press(page, 700);
      check(await page.$$eval("#key-strip .g", (g) => g[g.length - 1].classList.contains("dash")) && !(await page.evaluate(() => document.querySelector("#key").classList.contains("alarm"))), "길게 = 선, 경보가 꺼짐");
      await press(page, 60); await press(page, 60); await press(page, 60);
      check(/3명 연속/.test(await page.textContent("#key-say")), "점이 이어지면 N명 연속");
      for (let i = 0; i < 24; i++) await press(page, 40);
      await wait(500);
      check((await page.$$eval("#key-strip .g:not(.out)", (g) => g.length)) <= 16, "띠는 16칸을 넘지 않음");
      await page.keyboard.press("Tab"); await page.click("#key-reset"); await wait(100);
      check((await page.$$("#key-strip .g")).length === 0, "처음부터 → 띠가 빔");
      // 기준 탐색기: 격자 값이 docs/phase1.md 와 같고, 기준을 바꾸면 균형(정밀도↑ → 경보↓)대로 움직임
      await jump(page, "#explore"); await wait(900);
      const num = async (id) => parseFloat((await page.textContent(id)).replace(/[^\d.]/g, ""));
      await wait(600);
      check((await num("#ex-p")) === 54.1 && (await num("#ex-a")) === 95 && (await num("#ex-v")) === 90, `탐색기 처음: 서울 1월 180초·300m·2명 = 54.1% · 95건 · 90명 (docs/phase1.md 와 같음)`);
      check((await page.$$("#ex-plot .pt")).length === 18 && (await page.$$("#ex-plot .pt.on")).length === 1, "탐색기: 점 18개 중 고른 점 1개");
      await page.click('#ex-k button[data-v="3"]'); await wait(700);
      const p3 = await num("#ex-p"), a3 = await num("#ex-a");
      check(p3 > 54.1 && a3 < 95, `탐색기: 3명 연속 → 정밀도↑ ${p3}% · 경보↓ ${a3}건`);
      check(/놓치는|떨어집니다|줄어요/.test(await page.textContent("#ex-say")), "탐색기: 균형을 말로 설명");
      await page.click("#ex-sets button:nth-child(3)"); await page.click('#ex-k button[data-v="2"]'); await wait(900);
      check((await num("#ex-p")) === 51.8, "탐색기: 서울 6월(기준을 정하지 않은 달)에도 같은 기준 51.8%");
      await page.click('#ex-sec button[data-v="60"]'); await page.click('#ex-m button[data-v="100"]'); await page.click('#ex-k button[data-v="2"]'); await wait(700);
      check(/평소 자전거 2\.0%/.test(await page.textContent("#ex-plot .basel")), "탐색기: 평소 비율 점선이 고른 기준의 값(2.0%)을 따라감");
      const before = await page.textContent("#ex-title");
      await page.dispatchEvent("#ex-plot .pt:not(.on)", "click"); await wait(300);   // 고른 점은 고리가 계속 돌아 '안정' 을 기다리지 않게 이벤트를 직접
      check((await page.$$("#ex-plot .pt.on")).length === 1 && (await page.textContent("#ex-title")) !== before, "탐색기: 점을 눌러도 기준이 바뀜");
      // 번호 확인
      await jump(page, "#try"); await wait(800);
      await page.fill("#bike", "69683"); await page.press("#bike", "Enter"); await wait(300);
      check(/피하세요/.test(await page.textContent("#result")), "번호 확인: SPB-69683 → 피하세요");
      await page.fill("#bike", "SPB-12345"); await page.press("#bike", "Enter"); await wait(200);
      check(/괜찮아요/.test(await page.textContent("#result")), "번호 확인: 목록에 없는 번호 → 타도 괜찮아요");
      await page.fill("#bike", "abc"); await page.press("#bike", "Enter"); await wait(100);
      check(/5자리/.test(await page.textContent("#result")), "번호 확인: 잘못된 입력 → 안내");
      // 대여소 스티커: 처음엔 SPB-69683 이 서 있던 강서구 힐스테이트에코, 검색해서 바꾸면 이름·앱 주소가 같이 바뀜
      await jump(page, "#stk"); await wait(1200);
      check(await page.$$eval("#sticker .s-qr svg path", (p) => p.length === 1) && /힐스테이트에코/.test(await page.textContent("#sticker .s-name")), "스티커: 처음 = 힐스테이트에코 + QR");
      await page.fill("#stk-q", "망원역"); await wait(200);
      await page.click("#stk-sugg button:first-child"); await wait(400);
      check(/망원역/.test(await page.textContent("#sticker .s-name")) && (await page.getAttribute("#stk-open", "href")) === "app/?s=00102", "스티커: 검색해 고르면 이름·앱 주소가 바뀜");
      await page.evaluate(() => { window.__printed = 0; window.print = () => { window.__printed++; document.dispatchEvent(new Event("hz-print")); }; });
      await page.click("#stk-print"); await wait(300);
      check(await page.evaluate(() => window.__printed === 1 && !!document.querySelector("#print-root .sticker") && document.body.classList.contains("printing")), "스티커: 인쇄를 누르면 스티커만 남기는 복사본이 생김");
      await page.evaluate(() => window.dispatchEvent(new Event("afterprint"))); await wait(100);
      check(await page.evaluate(() => !document.querySelector("#print-root") && !document.body.classList.contains("printing")), "스티커: 인쇄가 끝나면 복사본을 치움");
      // 맨 아래 점
      await page.evaluate(() => scrollTo(0, document.documentElement.scrollHeight)); await wait(900);
      const d = await page.evaluate(() => { const r = document.querySelector("#foot .wordmark .dot").getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; });
      await page.mouse.move(d.x, d.y); await page.mouse.down();
      for (let i = 1; i <= 6; i++) { await page.mouse.move(d.x + i * 30, d.y - i * 20); await wait(16); }
      await page.mouse.up(); await wait(300);
      check(await page.evaluate(() => !!document.querySelector(".ball")), "맨 아래 점을 던지면 공이 생김");
      await wait(6500);
      check(await page.evaluate(() => !document.querySelector(".ball") && getComputedStyle(document.querySelector("#foot .wordmark .dot")).visibility !== "hidden"), "멈추면 제자리로 돌아와 점이 다시 보임");
      check(page.url() === BASE, "점을 갖고 놀아도 페이지가 넘어가지 않음");
      check(errors.length === 0, "화면 오류 없음" + (errors.length ? ": " + errors.slice(0, 3).join(" | ") : ""));
      await ctx.close();
    }

    // ── 1-1. 화면 흔들림(CLS): 충격파 고리처럼 크기를 키우는 움직임이 레이아웃을 건드리면 여기서 잡힘 (좋음 < 0.1, 여기서는 0.03 안쪽)
    for (const [name, vp] of [["넓은 화면", { width: 1440, height: 900 }], ["폰", { width: 390, height: 844 }]]) {
      const { ctx, page } = await open({ viewport: vp, deviceScaleFactor: vp.width < 800 ? 2 : 1 });
      await page.addInitScript(() => {
        window.__cls = 0;
        new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) window.__cls += e.value; }).observe({ type: "layout-shift", buffered: true });
      });
      await page.goto(BASE, { waitUntil: "load" }); await wait(3500);
      await jump(page, "#key"); await wait(900); await press(page, 60); await press(page, 60); await wait(1200);   // 경보 충격파까지
      await page.evaluate(() => { document.documentElement.style.scrollBehavior = "auto"; scrollTo(0, 0); });
      const cls = await page.evaluate(() => window.__cls);
      check(cls < 0.03, `${name}: 화면 흔들림(CLS) ${cls.toFixed(4)} < 0.03`);
      await ctx.close();
    }

    // ── 1-2. 웹앱: 대여소 QR 주소(?s=)로 열면 조회 탭 맨 위에 그 대여소 카드
    {
      const { ctx, page, errors } = await open({ viewport: { width: 390, height: 844 }, colorScheme: "light" });
      await page.goto(BASE + "app/?s=02720&day=2026-06-15", { waitUntil: "networkidle" }); await wait(1800);
      const on = await page.evaluate(() => document.querySelector("#lookup").classList.contains("on") || document.querySelector("#tabs button[data-tab=lookup]")?.getAttribute("aria-selected") === "true");
      check(on, "앱 ?s=: 조회 탭이 열림");
      const card = (await page.textContent("#st-card")).replace(/\s+/g, " ");
      check(/힐스테이트에코/.test(card) && /피할 자전거/.test(card), `앱 ?s=: 대여소 카드 (${card.slice(0, 40)})`);
      check((await page.$$eval("#st-card [data-bike]", (b) => b.map((x) => x.dataset.bike))).includes("SPB-69683"), "앱 ?s=: 이 대여소의 의심 자전거에 SPB-69683");
      await page.click('#st-card [data-bike="SPB-69683"]'); await wait(400);
      check(/SPB-69683/.test(await page.textContent("#lookup-result")), "앱 ?s=: 번호를 누르면 아래에서 바로 조회");
      await page.click("#st-card .st-add"); await wait(300);
      check(await page.evaluate(() => JSON.parse(localStorage.getItem("my_stations") || "[]").includes("02720")), "앱 ?s=: 내 대여소에 넣기");
      await page.goto(BASE + "app/?s=%3Cimg%20src%3Dx%3E", { waitUntil: "networkidle" }); await wait(900);
      check((await page.textContent("#st-card")).trim() === "" , "앱 ?s=: 이상한 값은 무시(주입 없음)");
      check(errors.length === 0, "앱 ?s=: 화면 오류 없음" + (errors.length ? ": " + errors[0] : ""));
      await ctx.close();
    }

    // ── 2. 대여소 자료를 못 받아도 깨지지 않음(씨앗 점이 남지 않음)
    {
      const { ctx, page, errors } = await open({}, async (c, p) => { await p.route("**/data/stations.json", (r) => r.fulfill({ status: 404, body: "" })); });
      await page.goto(BASE, { waitUntil: "networkidle" }); await wait(3200);
      check(await page.evaluate(() => document.querySelectorAll(".seed, .shock").length) === 0, "대여소 자료 404 → 씨앗 점이 남지 않음");
      check(errors.filter((e) => !/stations|JSON|Unexpected/.test(e)).length === 0, "대여소 자료 404 → 다른 오류 없음" + (errors.length ? ` (${errors[0]})` : ""));
      await ctx.close();
    }

    // ── 3. 움직임 줄이기: 멈춘 그림으로도 숫자·표가 다 나옴
    {
      const { ctx, page, errors } = await open({ reducedMotion: "reduce" });
      await page.goto(BASE, { waitUntil: "networkidle" }); await wait(1500);
      const n = (await page.textContent("#live-n")).trim();
      check(/^\d+$/.test(n) && +n > 0, `움직임 줄이기: 큰 숫자가 바로 보임 (${n})`);
      check(await page.evaluate(() => document.querySelectorAll(".seed, .shock, .ball, .ltip.on").length) === 0, "움직임 줄이기: 씨앗·충격파 없음");
      check((await page.$$("#lrows .g.dot")).length === 73, "움직임 줄이기: 12일 표가 그대로");
      check(errors.length === 0, "움직임 줄이기: 화면 오류 없음" + (errors.length ? ": " + errors[0] : ""));
      await ctx.close();
    }

    // ── 4. 폰 화면
    {
      const { ctx, page, errors } = await open({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, hasTouch: true, colorScheme: "light" });
      await page.goto(BASE, { waitUntil: "networkidle" }); await wait(1500);
      check(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), "폰: 가로로 넘치지 않음");
      await page.evaluate(() => { document.documentElement.style.scrollBehavior = "auto"; scrollTo(0, 220); }); await wait(600);
      check(await page.evaluate(() => !!document.querySelector(".hero h1 .pd")), "폰: 제목 마침표 점");
      check(errors.length === 0, "폰: 화면 오류 없음" + (errors.length ? ": " + errors[0] : ""));
      await ctx.close();
    }

    // ── 4-1. 글꼴이 더 넓은 기기(리눅스·안드로이드 기본 한글 글꼴)에서도 가로로 넘치지 않음 — 글자를 일부러 5% 넓혀, 작은 폰(320·360)까지.
    //        (격자 한 칸짜리가 minmax(auto,1fr) 이면 내용 최소 너비가 칸을 화면보다 넓힌다 — 맥에서는 통과하고 CI(리눅스)에서만 실패했던 문제)
    for (const w of [320, 360, 390]) {
      const { ctx, page } = await open({ viewport: { width: w, height: 800 }, colorScheme: "light", deviceScaleFactor: 1 });
      await page.goto(BASE, { waitUntil: "networkidle" }); await wait(1200);
      await page.addStyleTag({ content: "body *:not(svg):not(svg *) { letter-spacing: .05em !important; }" }); await wait(300);
      const r = await page.evaluate(() => {
        const W = innerWidth, bad = [];
        for (const el of document.querySelectorAll("body *")) {
          const q = el.getBoundingClientRect(); if (!q.width || q.right <= W + 0.5) continue;
          let a = el.parentElement, clipped = false;
          while (a && a !== document.body) { const o = getComputedStyle(a).overflowX; if (o !== "visible") { clipped = true; break; } a = a.parentElement; }
          if (!clipped && getComputedStyle(el).position !== "fixed") bad.push(`${el.tagName.toLowerCase()}.${String(el.className).split(" ")[0]}#${el.id}`);
        }
        return { sw: document.documentElement.scrollWidth, W, bad: bad.slice(0, 4) };
      });
      check(r.sw <= r.W + 1, `${w}px 폭, 글자 5% 넓혀도 가로로 넘치지 않음 (${r.sw}/${r.W}${r.bad.length ? " — " + r.bad.join(", ") : ""})`);
      await ctx.close();
    }

    // ── 5. 진행 기록 쪽 머리
    {
      const { ctx, page, errors } = await open({ colorScheme: "light" });
      await page.goto(BASE + "releases.html", { waitUntil: "networkidle" }); await wait(900);
      check(/solid/.test(await page.getAttribute("#top", "class")), "진행 기록: 머리가 처음부터 종이색");
      check((await page.evaluate(() => document.querySelector(".nav nav > a.on")?.textContent || "")).includes("진행 기록"), "진행 기록: 점이 '진행 기록' 아래");
      check(errors.length === 0, "진행 기록: 화면 오류 없음" + (errors.length ? ": " + errors[0] : ""));
      await ctx.close();
    }
  } catch (e) {
    fails.push(e.message);
    console.log("  ✗ " + e.message);
  } finally {
    await browser.close();
    srv.kill();
    fs.rmSync(dir, { recursive: true, force: true });
  }
  console.log(fails.length ? `불합격 ${fails.length}` : "합격");
  process.exit(fails.length ? 1 : 0);
})();
