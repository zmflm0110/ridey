// 안드로이드 앱(android-app) 아이콘·시작 화면 — 새 브랜드(docs/brand.md)에서: 앱 아이콘 'R.'(web/icon.svg), 시작 화면은 잉크 바탕 가운데 'RIDEY.'
//   node tools/make_android_assets.js        (먼저 python tools/make_brand.py 로 web/icon.svg · docs/brand/wordmark-dark.svg 를 만들어 둠)
//   아이콘: 예전 모양(ic_launcher·round), 적응형 앞면(ic_launcher_foreground — 108dp 중 가운데 66dp 안에 그림) + 바탕색(잉크)
//   시작 화면: res/drawable*/splash.png 크기 그대로
const fs = require("fs"), path = require("path");
const { launch } = require("../tests/web/browser");
const ROOT = path.resolve(__dirname, "..");
const RES = path.join(ROOT, "android-app/android/app/src/main/res");
const INK = "#111317";
const icon = fs.readFileSync(path.join(ROOT, "web/icon.svg"), "utf8");
const glyph = icon.match(/<g transform="[^"]*">[\s\S]*?<\/g>/)[0];               // 'R' + 신호 점 (512 칸 안 자리 그대로)
const wordmark = fs.readFileSync(path.join(ROOT, "docs/brand/wordmark-dark.svg"), "utf8");
const round = icon.replace(/<rect([^>]*?)\srx="[^"]*"/, '<rect$1 rx="256"');
// 적응형 앞면: 108 칸 중 가운데 66 칸 안에 — 512 칸 아이콘의 글자 묶음을 그대로 줄여 가운데에
const fg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g transform="translate(256 256) scale(.74) translate(-256 -256)">${glyph}</g></svg>`;
const DENS = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
(async () => {
  const browser = await launch();
  const page = await browser.newPage();
  const shot = async (html, w, h, file, transparent = false) => {
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<style>html,body{margin:0;background:${transparent ? "transparent" : INK}}svg{display:block}</style>${html}`);
    await page.screenshot({ path: file, omitBackground: transparent });
  };
  const sized = (svg, s) => svg.replace("<svg ", `<svg width="${s}" height="${s}" `);
  for (const [d, k] of Object.entries(DENS)) {
    const dir = path.join(RES, `mipmap-${d}`), s = Math.round(48 * k), f = Math.round(108 * k);
    await shot(sized(icon, s), s, s, path.join(dir, "ic_launcher.png"), true);
    await shot(sized(round, s), s, s, path.join(dir, "ic_launcher_round.png"), true);
    await shot(sized(fg, f), f, f, path.join(dir, "ic_launcher_foreground.png"), true);
  }
  // 시작 화면 — 기존 파일 크기 그대로, 잉크 바탕 가운데 'RIDEY.' (점은 신호색)
  for (const dir of fs.readdirSync(RES).filter((x) => x.startsWith("drawable"))) {
    const file = path.join(RES, dir, "splash.png");
    if (!fs.existsSync(file)) continue;
    const buf = fs.readFileSync(file); const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);
    const ww = Math.round(Math.min(w, h) * 0.46);
    await shot(`<div style="width:${w}px;height:${h}px;display:grid;place-items:center;background:${INK}">` +
      wordmark.replace('<svg class="wordmark"', `<svg style="width:${ww}px;height:auto"`) + `</div>`, w, h, file);
  }
  fs.writeFileSync(path.join(RES, "values/ic_launcher_background.xml"),
    `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${INK}</color>\n</resources>\n`);
  await browser.close();
  console.log("안드로이드 아이콘·시작 화면 완료");
})();
