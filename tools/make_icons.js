// 홈 화면 아이콘 PNG 만들기 — 아이폰은 apple-touch-icon 에 SVG 를 못 쓴다(무시하고 화면 캡처를 아이콘으로 씀).
//   node tools/make_icons.js   → site/img/icon-180.png, icon-192.png, icon-512.png. Flutter 앱 아이콘은 tools/make_flutter_assets.js
const fs = require("fs"), path = require("path");
const { launch } = require("../tests/web/browser");
const ROOT = path.resolve(__dirname, "..");
const OUT = path.join(ROOT, "site/img");
(async () => {
  const svg = fs.readFileSync(path.join(ROOT, "docs/brand/icon.svg"), "utf8");
  const square = svg.replace(/<rect([^>]*?)\srx="[^"]*"/, "<rect$1");   // 둥근 모서리 없이
  const browser = await launch();
  const page = await browser.newPage();
  fs.mkdirSync(OUT, { recursive: true });
  for (const [name, size, src] of [["icon-180.png", 180, square], ["icon-192.png", 192, square], ["icon-512.png", 512, square]]) {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<style>html,body{margin:0}svg{display:block;width:${size}px;height:${size}px}</style>${src}`);
    await page.screenshot({ path: path.join(OUT, name), omitBackground: false });
    console.log(name);
  }
  await browser.close();
})();
