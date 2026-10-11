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
      // 번호 확인
      await jump(page, "#try"); await wait(800);
      await page.fill("#bike", "69683"); await page.press("#bike", "Enter"); await wait(300);
      check(/피하세요/.test(await page.textContent("#result")), "번호 확인: SPB-69683 → 피하세요");
      await page.fill("#bike", "SPB-12345"); await page.press("#bike", "Enter"); await wait(200);
      check(/괜찮아요/.test(await page.textContent("#result")), "번호 확인: 목록에 없는 번호 → 타도 괜찮아요");
      await page.fill("#bike", "abc"); await page.press("#bike", "Enter"); await wait(100);
      check(/5자리/.test(await page.textContent("#result")), "번호 확인: 잘못된 입력 → 안내");
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
