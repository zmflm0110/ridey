// Flutter 이용자 앱(app/)의 아이콘·시작 화면 — 브랜드(docs/brand.md)에서: 아이콘 'R.'(web/icon.svg), 시작 화면은 잉크 바탕 가운데 'RIDEY.'
//   node tools/make_flutter_assets.js      (NODE_PATH 에 playwright — 저장소 루트의 tests/web/browser.js 를 씀)
//   안드로이드: mipmap-*/ic_launcher.png(둥근 네모) + 적응형(ic_launcher_foreground + 잉크 바탕, mipmap-anydpi-v26), 시작 화면 drawable-*/splash_wordmark.png
//   아이폰: AppIcon.appiconset 의 모든 크기(투명 없는 꽉 찬 네모 — 모서리는 iOS 가 깎음), LaunchImage.imageset 의 워드마크 + 바탕 잉크
const fs = require("fs"), path = require("path");
const { launch } = require("../tests/web/browser");
const ROOT = path.resolve(__dirname, ".."), APP = path.join(ROOT, "app");
const RES = path.join(APP, "android/app/src/main/res"), XC = path.join(APP, "ios/Runner/Assets.xcassets");
const INK = "#111317";
const icon = fs.readFileSync(path.join(ROOT, "web/icon.svg"), "utf8");
const glyph = icon.match(/<g transform="[^"]*">[\s\S]*?<\/g>/)[0];                       // 'R' + 신호 점 (512 칸 안 자리 그대로)
const square = icon.replace(/<rect([^>]*?)\srx="[^"]*"/, "<rect$1");                      // 아이폰: 모서리 없이(iOS 가 깎음)
const fg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><g transform="translate(256 256) scale(.74) translate(-256 -256)">${glyph}</g></svg>`;   // 적응형 앞면: 108 칸 중 가운데 66 칸 안에
const wordmark = fs.readFileSync(path.join(ROOT, "docs/brand/wordmark-dark.svg"), "utf8");
const DENS = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

(async () => {
  const browser = await launch(), page = await browser.newPage();
  const shot = async (html, w, h, file, transparent = false) => {
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(`<style>html,body{margin:0;background:${transparent ? "transparent" : INK}}svg{display:block}</style>${html}`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    await page.screenshot({ path: file, omitBackground: transparent });
  };
  const sized = (svg, w, h = w) => svg.replace("<svg ", `<svg width="${w}" height="${h}" `);

  // 안드로이드 아이콘
  for (const [d, k] of Object.entries(DENS)) {
    const s = Math.round(48 * k), f = Math.round(108 * k);
    await shot(sized(icon, s), s, s, path.join(RES, `mipmap-${d}`, "ic_launcher.png"), true);
    await shot(sized(fg, f), f, f, path.join(RES, `mipmap-${d}`, "ic_launcher_foreground.png"), true);
  }
  fs.mkdirSync(path.join(RES, "mipmap-anydpi-v26"), { recursive: true });
  fs.writeFileSync(path.join(RES, "mipmap-anydpi-v26/ic_launcher.xml"),
    `<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background" />\n    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n</adaptive-icon>\n`);
  fs.writeFileSync(path.join(RES, "values/ic_launcher_background.xml"),
    `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${INK}</color>\n</resources>\n`);

  // 안드로이드 시작 화면: 잉크 바탕 + 가운데 워드마크(너비 160dp)
  const wmW = 160, wmH = Math.round((160 * 75) / 415.1);
  for (const [d, k] of Object.entries(DENS)) {
    const w = Math.round(wmW * k), h = Math.round(wmH * k);
    await shot(wordmark.replace('<svg class="wordmark"', `<svg width="${w}" height="${h}"`), w, h, path.join(RES, `drawable-${d}`, "splash_wordmark.png"), true);
  }
  const layer = `<?xml version="1.0" encoding="utf-8"?>\n<!-- 시작 화면: 잉크 바탕 가운데 'RIDEY.' (tools/make_flutter_assets.js) -->\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n    <item android:drawable="@color/ic_launcher_background" />\n    <item>\n        <bitmap android:gravity="center" android:src="@drawable/splash_wordmark" />\n    </item>\n</layer-list>\n`;
  for (const dir of ["drawable", "drawable-v21"]) fs.writeFileSync(path.join(RES, dir, "launch_background.xml"), layer);

  // 아이폰 아이콘: Contents.json 의 모든 칸
  const set = path.join(XC, "AppIcon.appiconset"), contents = JSON.parse(fs.readFileSync(path.join(set, "Contents.json"), "utf8"));
  const done = new Set();
  for (const im of contents.images) {
    if (!im.filename || done.has(im.filename)) continue;
    const px = Math.round(parseFloat(im.size) * parseFloat(im.scale));
    await shot(sized(square, px), px, px, path.join(set, im.filename));   // 바탕 잉크로 꽉 참 — 투명 없음
    done.add(im.filename);
  }
  // 아이폰 시작 화면 그림: 워드마크(점 크기 160×29)
  for (const [name, k] of [["LaunchImage.png", 1], ["LaunchImage@2x.png", 2], ["LaunchImage@3x.png", 3]]) {
    const w = wmW * k, h = wmH * k;
    await shot(wordmark.replace('<svg class="wordmark"', `<svg width="${w}" height="${h}"`), w, h, path.join(XC, "LaunchImage.imageset", name), true);
  }
  await browser.close();
  console.log(`Flutter 아이콘·시작 화면 완료 — 안드로이드 ${Object.keys(DENS).length * 3}장, 아이폰 아이콘 ${done.size}장, 시작 그림 3장`);
})();
