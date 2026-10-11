// QR 인코더(site/qr.js) 검사 — 대여소 2,789곳의 앱 주소를 모두 QR 로 만들어 독립 디코더(jsQR)로 읽고, 글자가 그대로인지 본다.
//   node tests/web/qr.test.js     (브라우저 없이 node 만 · 약 20초)
const fs = require("fs"), vm = require("vm"), path = require("path");
const ROOT = path.resolve(__dirname, "../..");
const sandbox = { TextEncoder, console }; sandbox.window = sandbox; vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(ROOT, "site/qr.js"), "utf8"), sandbox);
const m = { exports: {} };
new Function("module", "exports", "self", fs.readFileSync(path.join(ROOT, "web/vendor/jsqr/jsQR.js"), "utf8"))(m, m.exports, {});
const jsQR = typeof m.exports === "function" ? m.exports : (m.exports.default || m.exports.jsQR);
const stations = JSON.parse(fs.readFileSync(path.join(ROOT, "web/data/stations.json"), "utf8"));
const APP = "https://zmflm0110.github.io/ridey/app/?s=";
const texts = stations.map((s) => APP + (Array.isArray(s) ? s[0] : s.id));
// 길이·글자 종류가 다른 경우도: 짧은 글, 한글, 106자(버전 6 끝), 107자(오류)
const extra = ["A", "https://zmflm0110.github.io/ridey/", "한글 주소 테스트 " + "가".repeat(10), "x".repeat(106)];
const decode = (text) => {
  const q = sandbox.RideyQR.encode(text), S = 6, Qz = 4, N = (q.size + 2 * Qz) * S, img = new Uint8ClampedArray(N * N * 4).fill(255);
  for (let y = 0; y < q.size; y++) for (let x = 0; x < q.size; x++) if (q.get(x, y))
    for (let dy = 0; dy < S; dy++) for (let dx = 0; dx < S; dx++) { const o = (((y + Qz) * S + dy) * N + (x + Qz) * S + dx) * 4; img[o] = img[o + 1] = img[o + 2] = 0; }
  const r = jsQR(img, N, N);
  return r && r.data;
};
let bad = 0;
for (const t of [...texts, ...extra]) { const got = decode(t); if (got !== t) { bad++; if (bad <= 5) console.log("  ✗ 불일치:", t.slice(0, 50), "→", got && got.slice(0, 50)); } }
let threw = false; try { sandbox.RideyQR.encode("x".repeat(107)); } catch { threw = true; }
const ok = bad === 0 && threw && texts.length > 2000;
console.log(`  ${bad === 0 ? "✓" : "✗"} QR ${texts.length + extra.length}개 중 불일치 ${bad}`);
console.log(`  ${threw ? "✓" : "✗"} 106자를 넘으면 오류를 냄`);
console.log(ok ? "합격" : "불합격"); process.exit(ok ? 0 : 1);
