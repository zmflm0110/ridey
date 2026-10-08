// 시연 영상 자동 녹화 (대회 제출·발표용) — 사이트 첫 화면(서울 점 지도·지금 경보 수) → 실제 자전거 SPB-69683 의 12일(사이트 그림) → 지금 목록(클라우드) → 운영 성적표(날짜별 채점) → 구 고르기·정비 동선 → 조회 경고·AI 이유 → 내 대여소 → 현장 확인으로 순위 바뀜 → 현장 조사 → 하루 재생, 화면 아래 자막. 순서는 docs/story.md.
// 지금 목록은 진짜 클라우드(Supabase 가 5분마다 만든 것)에서 받는다(인터넷 필요). 확인·조사 기록은 임시 서버 DB 로만(클라우드 DB 에 안 씀).
//   node tests/web/record_demo.js [나갈 폴더=docs/demo]   → demo.mp4 (ffmpeg 필요)
// 화질: Playwright 녹화는 폰 크기(390) 그대로라 2배 틀의 왼쪽 위에만 찍혔다(나머지 회색) → 2배 화면(780×1688)을 계속 캡처해 시각대로 잇는다.
//   캡처가 초당 12장 안팎이라, 움직임이 많은 로고 장면만 5배 느리게 돌려 찍고 다시 빠르게 붙인다(부드럽게).
// 서버를 임시 DB 로 스스로 띄운다. 지도 조각이 안 받아지는 곳(오프라인)에서는 대여소 점 바탕으로 찍힌다.
const { spawn, execFileSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const { launch } = require("./browser");
const ROOT = path.resolve(__dirname, "../..");
const OUT = path.resolve(process.argv[2] || path.join(ROOT, "docs/demo"));
const PORT = 8990 + Math.floor(Math.random() * 100);
const URL = `http://127.0.0.1:${PORT}/index.html`;
const W = 390, H = 844;
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
  const db = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "hz-")), "t.sqlite");
  const srv = spawn(process.env.PYTHON || "python3", [path.join(ROOT, "server/app.py"), String(PORT)], { env: { ...process.env, BIKE_DB: db }, stdio: "ignore" });
  for (let i = 0; i < 50; i++) { try { await fetch(URL); break; } catch { await wait(100); } }
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "hz-frames-"));
  const browser = await launch();
  const ctx = await browser.newContext({ viewport: { width: W * 2, height: H * 2 }, deviceScaleFactor: 1, locale: "ko-KR", serviceWorkers: "block" });
  await ctx.addInitScript(() => { window.HZ_CLOUD_OFF = true; });   // 시연 기록은 임시 DB 로
  const SLOW = 3;   // 사이트 첫 화면만: 애니메이션·타이머·rAF 시계를 3배 느리게 찍고 다시 빠르게 붙임(부드럽게). 끝나면 window.__setSlow(1)
  await ctx.addInitScript((slow) => {
    if (!location.search.includes("site")) return;
    const pn = performance.now.bind(performance); let base = pn(), virt = base, k = slow;
    const now = () => virt + (pn() - base) / k;
    window.__setSlow = (nk) => { virt = now(); base = pn(); k = nk; };
    performance.now = now;
    const raf = window.requestAnimationFrame.bind(window); window.requestAnimationFrame = (cb) => raf(() => cb(now()));
    const st = window.setTimeout; window.setTimeout = (f, ms, ...a) => st(f, (ms || 0) * k, ...a);
  }, SLOW);
  // 첫 장면 — 사이트 첫 화면(서울이 레이더처럼 퍼지고 경보 점이 켜지고 숫자가 올라감). 글꼴을 먼저 받아 두려고 한 번 열었다 닫음(같은 context 라 캐시 공유)
  // 사이트는 만든 그대로(tools/build_site.py) 임시 폴더에서 띄움 — 파일로 열면 자료를 못 받음
  const siteDir = fs.mkdtempSync(path.join(os.tmpdir(), "hz-site-"));
  execFileSync(process.env.PYTHON || "python3", [path.join(ROOT, "tools/build_site.py"), "--out", siteDir], { stdio: "ignore" });
  const sitePort = PORT + 200, siteSrv = spawn(process.env.PYTHON || "python3", ["-m", "http.server", String(sitePort), "--bind", "127.0.0.1", "--directory", siteDir], { stdio: "ignore" });
  const SITE = `http://127.0.0.1:${sitePort}/index.html?site`;
  for (let i = 0; i < 50; i++) { try { await fetch(SITE); break; } catch { await wait(100); } }
  const warm = await ctx.newPage(); await warm.goto(SITE, { waitUntil: "networkidle" }); await warm.close();
  const page = await ctx.newPage();
  const cdp = await ctx.newCDPSession(page);
  const phone = () => cdp.send("Emulation.setDeviceMetricsOverride", { width: W, height: H, deviceScaleFactor: 2, mobile: false, scale: 2 });   // 폰 배치 그대로, 그림은 2배
  await phone();
  // 캡처: [시각(ms), 느림 배수, 파일] — 끝나면 시각 차이로 길이를 매겨 잇는다
  const frames = []; let rec = true, slowNow = 1, paused = false, cut = false;
  const grab = (async () => {
    while (rec) {
      if (paused) { await wait(30); continue; }
      try {
        const t = Date.now(), r = await cdp.send("Page.captureScreenshot", { format: "jpeg", quality: 90, optimizeForSpeed: true });
        const f = path.join(tmp, `f${String(frames.length).padStart(6, "0")}.jpg`);
        fs.writeFileSync(f, Buffer.from(r.data, "base64")); frames.push([t, slowNow, f, cut]); cut = false;
      } catch { await wait(30); }   // 페이지 넘어가는 순간
    }
  })();
  await cdp.send("Animation.enable"); await cdp.send("Animation.setPlaybackRate", { playbackRate: 1 / SLOW });
  slowNow = SLOW;
  await page.goto(SITE, { waitUntil: "domcontentloaded" });
  await wait(4300 * SLOW);   // 머리 → 제목 줄 → 글 → 단추 → 큰 숫자, 서울 점 지도가 퍼지고 경보 점이 차례로 켜짐
  await page.evaluate(() => window.__setSlow && window.__setSlow(1));
  await cdp.send("Animation.setPlaybackRate", { playbackRate: 1 });
  slowNow = 1;
  // 자막 상자 (사이트·앱 모두)
  const capStyle = () => page.addStyleTag({ content: `#cap{position:fixed;left:10px;right:10px;bottom:18px;z-index:9999;background:rgba(17,19,23,.93);color:#F7F5F0;
    font:700 16px/1.45 -apple-system,"Apple SD Gothic Neo","Noto Sans CJK KR",sans-serif;padding:12px 16px 12px 18px;border-radius:16px;box-shadow:inset 3px 0 0 #FF4F1F;transition:opacity .3s;pointer-events:none}
    #cap small{display:block;font-weight:400;opacity:.8;font-size:13px} #cap.top{top:10px;bottom:auto}` });
  // top: 시연 화면에서는 아래 숫자판을 가리지 않게 위(머리글 자리)에
  const cap = async (t, sub = "", top = false) => { await page.evaluate(([t, s, top]) => {
    let c = document.querySelector("#cap"); if (!c) { c = document.createElement("div"); c.id = "cap"; document.body.appendChild(c); }
    c.className = top ? "top" : ""; c.innerHTML = t + (s ? `<small>${s}</small>` : ""); }, [t, sub, top]); };
  await capStyle();
  const liveN = ((await page.textContent("#live-n").catch(() => "")) || "").trim(), liveK = ((await page.textContent("#live-k").catch(() => "")) || "").trim();
  await cap("RIDEY. — 점 하나가 신호다.", liveN ? `${liveK} ${liveN}대 — 클라우드가 5분마다 다시 셉니다.` : "앞사람들이 빌리자마자 반납한 흔적으로, 고장 난 따릉이를 먼저.", true);
  await wait(3800);
  // 이야기 — 실제 자전거 한 대의 12일 (사이트의 시간 축 그림을 왼쪽에서 오른쪽으로 밀며)
  await page.evaluate(() => { const r = document.querySelector("#story .tl").getBoundingClientRect(); window.scrollTo({ top: window.scrollY + r.top - 150, behavior: "instant" }); });
  await wait(1200);
  await cap("서울 강서구 따릉이 SPB-69683, 2026년 6월 실제 기록.", "6월 12일 오후 3시 43분 — 서로 다른 두 번째 사람도 빌리자마자 반납.", true);
  await wait(4200);
  // 가로 밀기는 여기(node)서 조금씩 — 캡처가 쉬지 않고 돌면 페이지 안 애니메이션 시계가 흔들려 한 번에 끝까지 갔다가 되돌아왔다
  const slide = async (to, ms) => {
    const [from, max] = await page.evaluate(() => { const e = document.querySelector("#story .tl-scroll"); return [e.scrollLeft, e.scrollWidth - e.clientWidth]; });
    const end = to * max, n = Math.max(1, Math.round(ms / 50));
    for (let i = 1; i <= n; i++) {
      const k = i / n;
      await page.evaluate((v) => { document.querySelector("#story .tl-scroll").scrollLeft = v; }, from + (end - from) * k * k * (3 - 2 * k));
      await wait(50);
    }
  };
  await cap("다음 날 아침 첫 고장 신고. 그런데도 그 뒤 54번 더 빌렸다가 바로 반납.", "출근길엔 37분 사이에 7명이 연달아.", true);
  await slide(0.5, 4200); await wait(1600);
  await cap("12일 동안 서로 다른 73명. 기록엔 다 남아 있었어요.", "RIDEY 는 두 번째 사람이 반납한 그 순간 알아요.", true);
  await slide(1, 3600); await wait(2400);
  paused = true;   // 앱을 불러오는 빈 화면은 빼고 잇는다
  await page.goto(URL, { waitUntil: "networkidle" });
  await phone();
  await page.waitForSelector("#bike-list li", { timeout: 60000 }).catch(async (e) => {
    fs.writeFileSync(path.join(OUT, "fail.jpg"), Buffer.from((await cdp.send("Page.captureScreenshot", { format: "jpeg" })).data, "base64")); throw e; });
  await wait(1500);   // 지도 조각까지
  cut = true; paused = false;
  const live = (await page.$eval("#day", (d) => d.value)) === "live";
  await capStyle();
  // 누르기: 2배 그림(scale 2) 에서는 마우스 좌표가 어긋나서 DOM 에서 바로 누름
  const tap = (sel) => page.$eval(sel, (el) => el.click());
  const tab = (t) => tap(`#tabs button[data-tab="${t}"]`);
  const show = (sel) => page.evaluate((sel) => { const r = document.querySelector(sel).getBoundingClientRect(); window.scrollTo({ top: window.scrollY + r.top - 130, behavior: "smooth" }); }, sel);   // 머리글 아래로 온전히
  const type = async (sel, text) => { for (const ch of text) { await page.type(sel, ch); await wait(90); } };

  await cap("신고는 귀찮고, 순회 직원도 타 봐야 아는 고장은 못 봐요.", "경보 자전거의 82~91% 가 하루 안에 또 빌려졌어요 — 그래서 '어디부터 볼지' 를 알려 줍니다.");
  await wait(3800);
  await cap(live ? "RIDEY는 서울시 공개 대여기록을 5분마다 읽어요." : "RIDEY는 서울시 공개 대여기록만 봅니다.",
    "서로 다른 사람이 연달아 빌리자마자(3분·300m 안) 반납한 자전거 = 고장 의심. 센서·장비 없이.");
  await wait(4800);
  const ai = ((await page.textContent("#morning-summary .ai").catch(() => "")) || "").replace("✦ ", "");
  if (ai) {   // 자체 AI — 목록 자전거마다 확률, '최소 몇 대는 진짜' 보장
    await cap("자체 AI 가 자전거마다 '다음 사람도 반납할 확률' 을 계산해 순서를 매겨요.", ai + " — 실시간 결과로 스스로 다시 배워요.");
    await wait(4200);
  }
  if (live && await page.waitForSelector("#morning-retro .days", { timeout: 8000 }).catch(() => null)) {   // 운영 성적표 — 실제로 맞았나
    const pct = await page.textContent("#morning-retro .ring b"), head = await page.textContent("#morning-retro .days .detail b");
    await show("#morning-retro");
    await cap("정말 맞았을까? 9월 27일부터 실제로 운영하며 스스로 채점해요.", `경보 뒤 다음 사람 ${pct} 가 또 바로 반납 — ${head}.`);
    await wait(5200);
    await page.evaluate(() => window.scrollTo({ top: 0, behavior: "smooth" })); await wait(700);
  }
  const gu = await page.$eval("#stories .story:nth-child(2)", (b) => b.dataset.gu);
  await tap("#stories .story:nth-child(2)");
  // 고른 구 안에서 확률이 높은 자전거 중, 정비 순위 맨 위가 아닌 대여소의 것 — 확인하면 맨 위로 올라가는 게 보이게
  const bike = await page.evaluate(() => {
    const top = document.querySelector("#station-rank li b")?.textContent;
    const rows = [...document.querySelectorAll("#bike-list li")].map((li) => [li.querySelector("b").textContent, li.querySelector(".s").textContent]);
    return (rows.find(([, s]) => top && !s.startsWith(top)) || rows[0])[0];
  });
  await cap(`정비 기사는 구를 골라요 — ${gu}.`, "지도와 '먼저 볼 곳' 순위. 경보의 절반이 대여소 16% 에 몰려 있어요.");
  await wait(3500);
  await show("#station-rank");
  await wait(2500);
  await page.evaluate(() => document.querySelector("#route-list").scrollIntoView({ behavior: "smooth", block: "center" }));
  const total = ((await page.textContent("#route-list li.total").catch(() => "")) || "").replace(/\s+/g, " ").trim();
  await cap("근무 시간 안에 헛걸음을 가장 많이 막는 정비 동선.", total || "붐비는 대여소를 먼저, 한산한 곳은 나중에.");
  await wait(5000);
  await page.evaluate(() => window.scrollTo({ top: 0, behavior: "smooth" }));

  await tab("lookup");
  await cap("이용자는 빌리기 전에 번호나 QR 로 확인.", "");
  await wait(1200);
  await type("#bike-input", bike);
  await page.press("#bike-input", "Enter");
  const pText = ((await page.textContent("#lookup-result .facts b.red").catch(() => "")) || "").trim();
  await cap(`${bike} — 서로 다른 사람들이 바로 반납한 자전거`, `다음 사람도 바로 반납할 확률 ${pText || "약 35~44%"} (평소 2.5%). 옆 자전거를 고르면 헛걸음 끝.`);
  await wait(4600);
  if (await page.$("#lookup-result .why")) {   // 설명 가능한 AI — 그 확률의 이유
    await show("#lookup-result .why");
    const why = await page.$$eval("#lookup-result .why div span", (s) => s.map((x) => x.textContent).slice(0, 2).join(" · "));
    await cap("AI 가 본 이유도 사람 말로 보여 줘요.", why);
    await wait(4200);
  }
  // 내 대여소 — 방금 본 자전거의 대여소 + 의심 자전거가 많은 곳 하나를 넣어 둔 모습 (이 폰에만 저장)
  const myIds = await page.evaluate((bk) => { const bs = state.morning.bikes, own = (bs.find((b) => b.bike === bk) || {}).station, c = {};
    for (const b of bs) if (b.station !== own) c[b.station] = (c[b.station] || 0) + 1;
    const other = Object.entries(c).sort((a, b) => b[1] - a[1])[0]; return [own, other && other[0]].filter(Boolean); }, bike);
  if (myIds.length) {
    await page.evaluate((ids) => { mine = ids; saveMine(); renderMine(); }, myIds);
    await show("#my-list");
    await cap("자주 가는 대여소를 넣어 두면,", "가기 전에 그곳에 서 있는 '피할 번호' 를 바로 — 누르면 자세히.");
    await wait(4800);
    await show("#lookup-result .choices");
    await wait(700);
  }
  await cap("순회 중 의심 자전거 앞에서 탭 한 번.", "체인·타이어·안장·멀쩡함 → 모든 폰의 정비 순위에 '사람이 확인함' 으로.");
  await wait(2200);
  await tap("#lookup-result .choices button:has-text('체인·기어')");
  await wait(2500);
  await tab("morning");
  await page.waitForFunction(() => document.querySelector("#station-rank").textContent.includes("사람이 확인한 고장"), null, { timeout: 15000 }).catch(() => {});
  await show("#station-rank");
  await cap("확인된 곳이 정비 순위 맨 위로.", "모든 폰에서 같이 바뀌어요(클라우드 DB).");
  await wait(3800);
  await page.evaluate(() => window.scrollTo({ top: 0 }));

  await tab("survey");
  await cap("현장 조사 — 사람이 본 상태를 기록해 경보가 맞았는지 잽니다.", "사진·위치와 함께 클라우드 DB 로. 인터넷이 없으면 폰에 모았다가 나중에.");
  await wait(4200);

  await tab("replay");
  await cap("2026년 6월 15일, 서울 따릉이 실제 기록을 하루 재생합니다.", "주황 = 경보 · 흰 점 = 경보 뒤 또 헛걸음 · 파랑 = 한참 뒤에 들어온 고장 신고", true);
  await page.selectOption("#speed", "1800");
  await wait(2500);
  await tap("#play");
  await page.waitForFunction(() => document.querySelector("#clock").textContent >= "08:00", null, { timeout: 60000 });
  await cap("출근 시간 — 경보가 켜진 자전거를 또 빌려 헛걸음한 사람들(흰 점).", "경보만 보여 줬어도 막을 수 있었던 헛걸음이에요.", true);
  await page.waitForFunction(() => document.querySelector("#clock").textContent >= "15:00", null, { timeout: 60000 });
  await page.selectOption("#speed", "3600");
  await cap("고장 신고는 경보보다 중앙값 20시간 늦게 들어와요.", "그 사이 한 자전거에서 평균 3.5~4.6명이 헛걸음.", true);
  await page.waitForFunction(() => document.querySelector("#clock").textContent.startsWith("다음 날"), null, { timeout: 60000 });
  await page.evaluate(() => { const s = document.querySelector("#speed"); s.insertAdjacentHTML("beforeend", '<option value="14400">4시간/초</option>'); s.value = "14400"; });
  await cap("다음 날 — 뒤늦은 고장 신고만 드문드문(파랑).", "우리 경보는 이미 전날 울렸던 자전거들이에요.", true);
  await page.waitForFunction(() => document.querySelector("#play").textContent.includes("다시"), null, { timeout: 90000 });
  const n = await page.evaluate(() => ["#c-alarm", "#c-prev", "#c-fault"].map((s) => document.querySelector(s).textContent));
  await cap(`하루 동안 경보 ${n[0]} · 막을 수 있던 헛걸음 ${n[1]}명`, "서울 3개월·대전 2개월, 약 1천만 건으로 검증 · 경보는 고장 신고보다 20~25시간 먼저", true);
  await wait(5000);
  await cap("신고를 기다리지 말고, 흔적을 읽자 — RIDEY", "안드로이드·아이폰·웹 · 공개 데이터만 · 5분마다 갱신", true);
  await wait(4500);

  rec = false; await grab;
  await browser.close();
  srv.kill(); siteSrv.kill();
  // 프레임마다 길이 = 다음 프레임까지 걸린 시간 ÷ 느림 배수 → ffmpeg concat 으로 30fps mp4
  const list = frames.map(([t, k, f], i) => {
    const nx = frames[i + 1], dur = !nx ? 0.1 : nx[3] ? 0.4 : (nx[0] - t) / 1000 / k;   // 잘라 낸 자리 앞 장면은 0.4초만
    return `file '${f}'\nduration ${dur.toFixed(4)}`;
  }).join("\n") + `\nfile '${frames[frames.length - 1][2]}'\n`;
  fs.writeFileSync(path.join(tmp, "list.txt"), list);
  fs.mkdirSync(OUT, { recursive: true });
  const mp4 = path.join(OUT, "demo.mp4"), ff = process.env.FFMPEG || "ffmpeg";
  execFileSync(ff, ["-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", path.join(tmp, "list.txt"), "-fps_mode", "cfr", "-r", "30",
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "26", "-preset", "slow", "-movflags", "+faststart", mp4]);
  const secs = frames.reduce((a, [t, k], i) => a + (!frames[i + 1] ? 0 : frames[i + 1][3] ? 400 : (frames[i + 1][0] - t) / k), 0) / 1000;
  console.log("저장:", mp4, (fs.statSync(mp4).size / 1e6).toFixed(1) + "MB", `${secs.toFixed(0)}초, 프레임 ${frames.length}장`);
  fs.rmSync(tmp, { recursive: true, force: true });
})();
