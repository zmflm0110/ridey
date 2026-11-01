// 시연 영상 자동 녹화 (대회 제출·발표용) — 사이트 첫 화면(서울 점 지도·지금 경보 수) → 실제 자전거 SPB-69683 의 12일 → 직접 찍어 보기. 순서는 docs/story.md.
//   node tests/web/record_demo.js [나갈 폴더=docs/demo]   → demo.mp4 (ffmpeg 필요)
// 화질: Playwright 녹화는 폰 크기(390) 그대로라 2배 틀의 왼쪽 위에만 찍혔다(나머지 회색) → 2배 화면(780×1688)을 계속 캡처해 시각대로 잇는다.
const { spawn, execFileSync } = require("child_process");
const fs = require("fs"), os = require("os"), path = require("path");
const { launch } = require("./browser");
const ROOT = path.resolve(__dirname, "../..");
const OUT = path.resolve(process.argv[2] || path.join(ROOT, "docs/demo"));
const PORT = 8990 + Math.floor(Math.random() * 100);
const W = 390, H = 844;
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

(async () => {
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
  // 이야기 — 실제 자전거 한 대의 12일 (사이트의 '하루에 한 줄' 표를 위에서 아래로 훑으며, 점을 눌러 말풍선)
  // 스크롤은 여기(node)서 조금씩 — 캡처가 쉬지 않고 돌면 페이지 안 애니메이션 시계가 흔들려 한 번에 끝까지 갔다가 되돌아왔다
  const glide = async (sel, at, ms, bottom = false) => {   // sel 이 숫자면 그 스크롤 위치로
    const [from, to] = await page.evaluate(([sel, at, bottom]) => { if (typeof sel === "number") return [scrollY, sel]; const r = document.querySelector(sel).getBoundingClientRect(); return [scrollY, scrollY + (bottom ? r.bottom : r.top) - at]; }, [sel, at, bottom]);
    const n = Math.max(1, Math.round(ms / 50));
    for (let i = 1; i <= n; i++) {
      const k = i / n;
      await page.evaluate((v) => window.scrollTo({ top: v, behavior: "instant" }), from + (to - from) * k * k * (3 - 2 * k));
      await wait(50);
    }
  };
  // 점 위에 말풍선 — 2배 그림이라 마우스 좌표 대신 DOM 에서 바로 (i 가 음수면 뒤에서)
  const point = (sel, i = 0) => page.evaluate(([sel, i]) => { const g = [...document.querySelectorAll(sel)].at(i); g?.dispatchEvent(new PointerEvent("pointerover", { bubbles: true, pointerType: "mouse" })); }, [sel, i]);
  // 첫 화면에서 천천히 내려감 — 서울의 점들이 소용돌이치며 제목 '먼저.' 의 마침표로 빨려 들어감
  await cap("내리면 서울의 신호들이 한 점으로 모입니다.", "점 하나 → 서울 → 다시 점 하나. 그리고 실제 자전거 한 대의 이야기.", true);
  const pdEnd = await page.evaluate(() => { let y = 0; for (let el = document.querySelector(".hero h1 .pd"); el; el = el.offsetParent) y += el.offsetTop; return Math.max(160, y - innerHeight * 0.18); });
  await glide(Math.round(pdEnd + 40), 0, 2600); await wait(1100);
  // 표의 번호판(SPB-69683)이 자막 아래로 보이게 — 자막을 먼저 바꾸고, 줄이 차례로 나오는 동안 읽게
  await cap("서울 강서구 따릉이 SPB-69683, 2026년 6월 실제 기록.", "6월 12일 오후 3시 43분 — 서로 다른 두 번째 사람도 빌리자마자 반납.", true);
  await glide("#ledger", 128, 1400);
  await wait(2200); await point("#ledger .g.dot.alarm"); await wait(3000);
  await cap("다음 날 아침 첫 고장 신고. 그런데도 그 뒤 54번 더 빌렸다가 바로 반납.", "출근길엔 37분 사이에 7명이 연달아.", true);
  await glide("#ledger .lrow:nth-child(2)", 200, 2400); await wait(500);
  await point("#ledger .lrow:nth-child(2) .g.rep"); await wait(3200);
  await cap("12일 동안 서로 다른 73명. 기록엔 다 남아 있었어요.", "RIDEY 는 두 번째 사람이 반납한 그 순간 알아요.", true);
  await glide("#ledger .lf", 820, 3200, true); await wait(500);
  await point("#ledger .g.dot", -1); await wait(3200);
  // 원리 — 직접 찍어 보기: 짧게 두 번 누르면 경보(충격파). 2배 그림이라 마우스 대신 DOM 에 누름 신호를 보냄
  const press = async (ms) => {
    await page.evaluate(() => document.querySelector("#key-btn").dispatchEvent(new PointerEvent("pointerdown", { bubbles: true, pointerId: 7, button: 0, pointerType: "mouse" })));
    await wait(ms);
    await page.evaluate(() => document.querySelector("#key-btn").dispatchEvent(new PointerEvent("pointerup", { bubbles: true, pointerId: 7, button: 0, pointerType: "mouse" })));
  };
  await cap("원리는 하나 — 서로 다른 사람의 '점' 이 두 번 이어지면 경보.", "사이트에서 직접 눌러 볼 수 있어요: 짧게 = 빌리자마자 반납, 길게 = 타고 감.", true);
  await glide("#key", 200, 2200); await wait(900);
  await press(70); await wait(900); await press(650); await wait(800); await press(70); await wait(700); await press(70); await wait(2600);
  await cap("신고를 기다리지 말고, 흔적을 읽자 — RIDEY", "앱에서 시민·직원 모드로 확인합니다. 공개 데이터만 · 5분마다 갱신", true);
  await wait(4500);

  rec = false; await grab;
  await browser.close();
  siteSrv.kill();
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
