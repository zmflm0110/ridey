// 링크 미리보기(OG) 이미지 1200×630 — 브랜드(docs/brand.md): 잉크 바탕·워드마크·'점 하나가 신호다'·실제 자전거 한 대(SPB-69683)의 12일을 점으로.
//   node tools/make_og.js      → site/img/og.png   (NODE_PATH 에 playwright · 데이터는 site/data/spb69683.json)
const fs = require("fs"), path = require("path");
const { launch } = require("../tests/web/browser");
const ROOT = path.resolve(__dirname, ".."), D = JSON.parse(fs.readFileSync(path.join(ROOT, "site/data/spb69683.json"), "utf8"));
const wm = fs.readFileSync(path.join(ROOT, "docs/brand/wordmark-dark.svg"), "utf8").replace('class="wordmark"', 'style="height:64px;width:auto;display:block"');
// 점: 하루 한 줄(12~24일), 시간 순서 — 12일 표와 같은 그림을 작게
const rows = [];
for (let d = 12; d <= 24; d++) {
  const r = [...D.duds.map((h) => [h, "d"]), ...D.rides.map((h) => [h, "r"]), ...D.reports.map((h) => [h, "R"])].filter(([h]) => 12 + Math.floor(h / 24) === d).sort((a, b) => a[0] - b[0]);
  rows.push(r);
}
const first = Math.min(...D.duds), alarm = D.duds.reduce((b, h) => (Math.abs(h - D.alarm) < Math.abs(b - D.alarm) ? h : b), D.duds[0]);
const cell = (h, k) => k === "R" ? '<i class="rep"></i>' : k === "r" ? '<i class="dash"></i>' : `<i class="dot${h === first ? " first" : h === alarm ? " alarm" : ""}"></i>`;
const html = `<!doctype html><meta charset="utf-8"><style>
  @font-face { font-family: "PretendardLocal"; src: local("Pretendard Variable"), local("Pretendard"), local("Apple SD Gothic Neo"); }
  * { box-sizing: border-box; margin: 0 }
  body { width: 1200px; height: 630px; background: #0D0F12; color: #F3F1EC; font-family: "Pretendard Variable", Pretendard, "Apple SD Gothic Neo", "Noto Sans CJK KR", sans-serif; position: relative; overflow: hidden }
  .glow { position: absolute; right: -120px; top: -140px; width: 640px; height: 640px; background: radial-gradient(circle, rgba(255, 92, 46, .22), transparent 66%) }
  .wrap { position: absolute; left: 72px; top: 64px; right: 72px; bottom: 56px }
  h1 { margin-top: 56px; font-size: 92px; line-height: 1.04; letter-spacing: -.055em; font-weight: 800 }
  h1 em { font-style: normal; color: #FF5C2E }
  p { margin-top: 26px; font-size: 29px; line-height: 1.4; color: #B3B7BE; font-weight: 600; letter-spacing: -.02em; max-width: 600px }
  .led { position: absolute; right: 0; bottom: 0; width: 392px; display: grid; gap: 8px }
  .row { display: flex; gap: 5px; align-items: center; height: 11px }
  .dot { width: 10px; height: 10px; border-radius: 50%; background: #FF5C2E; flex: none }
  .dot.first { background: transparent; box-shadow: inset 0 0 0 2px #FF5C2E }
  .dot.alarm { box-shadow: 0 0 0 3px #0D0F12, 0 0 0 5px #FF5C2E; margin: 0 4px }
  .dash { width: 20px; height: 6px; border-radius: 3px; background: #5A5F67; flex: none }
  .rep { width: 3px; height: 14px; border-radius: 2px; background: #F3F1EC; margin: 0 3px; flex: none }
  .cap { position: absolute; right: 0; bottom: 268px; font-size: 20px; color: #8A8F98; font-weight: 600; margin: 0; text-align: right }
</style><div class="glow"></div><div class="wrap">
  ${wm}
  <h1>타기 전에,<br>고장 난 따릉이를<br><em>먼저.</em></h1>
  <p>빌리자마자 반납한 흔적으로<br>신고보다 먼저 — 점 하나가 신호다</p>
  <div class="cap">SPB-69683 · 12일 동안 서로 다른 73명</div>
  <div class="led">${rows.map((r) => `<div class="row">${r.map(([h, k]) => cell(h, k)).join("")}</div>`).join("")}</div>
</div>`;
(async () => {
  const b = await launch(), p = await b.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
  await p.setContent(html); await p.waitForTimeout(300);
  await p.screenshot({ path: path.join(ROOT, "site/img/og.png") });
  await b.close();
  console.log("site/img/og.png", (fs.statSync(path.join(ROOT, "site/img/og.png")).size / 1024).toFixed(0) + "KB");
})();
