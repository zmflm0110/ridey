// 작은 QR 코드 인코더 — 바이트 모드 · 오류 정정 M · 버전 1~6(글자 106자까지). 의존성 없음. 대여소 스티커용(사이트).
//   RideyQR.encode("https://…") → { size, get(x, y) → true(검정) }      RideyQR.svg(text, { quiet: 4 }) → 'M..z' 경로가 든 SVG 문자열
// 검증: tests/web/site.test.js 가 대여소 2,789곳의 주소를 모두 만들어 독립 디코더(jsQR)로 읽어 같은지 본다.
// 구조는 QR 표준(ISO/IEC 18004)의 그대로: 데이터 → 리드-솔로몬 오류 정정 → 블록 섞기 → 지그재그 배치 → 마스크 8개 중 벌점이 가장 낮은 것 → 형식 정보.
(() => {
  // 버전별 [전체 코드워드, 블록당 오류 정정 코드워드, 블록 수] — 오류 정정 M
  const VER = [null, [26, 10, 1], [44, 16, 1], [70, 26, 1], [100, 18, 2], [134, 24, 2], [172, 16, 4]];
  const ALIGN = [null, [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34]];

  const mul = (x, y) => { let z = 0; for (let i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >>> 7) * 0x11d); z ^= ((y >>> i) & 1) * x; } return z; };   // GF(256), 기약식 0x11D
  const divisor = (deg) => {
    const r = new Array(deg).fill(0); r[deg - 1] = 1; let root = 1;
    for (let i = 0; i < deg; i++) { for (let j = 0; j < deg; j++) { r[j] = mul(r[j], root); if (j + 1 < deg) r[j] ^= r[j + 1]; } root = mul(root, 2); }
    return r;
  };
  const remainder = (data, div) => {
    const r = new Array(div.length).fill(0);
    for (const b of data) { const f = b ^ r.shift(); r.push(0); div.forEach((c, i) => (r[i] ^= mul(c, f))); }
    return r;
  };

  function encode(text) {
    const bytes = [...new TextEncoder().encode(String(text))];
    let v = 1;
    for (; v <= 6; v++) { const [tot, ecc, nb] = VER[v]; if (bytes.length <= tot - ecc * nb - 2) break; }   // 모드 4비트 + 길이 8비트 = 2바이트
    if (v > 6) throw new Error("QR: 글자가 너무 깁니다(106자까지)");
    const [total, eccLen, nBlocks] = VER[v], dataLen = total - eccLen * nBlocks, size = 17 + 4 * v;

    // 1) 데이터 비트: 모드(0100) · 글자 수(8) · 바이트 · 끝 표시 · 채우기(EC, 11 번갈아)
    const bits = [];
    const put = (val, n) => { for (let i = n - 1; i >= 0; i--) bits.push((val >>> i) & 1); };
    put(4, 4); put(bytes.length, 8); bytes.forEach((b) => put(b, 8));
    put(0, Math.min(4, dataLen * 8 - bits.length));
    while (bits.length % 8) bits.push(0);
    const data = []; for (let i = 0; i < bits.length; i += 8) data.push(parseInt(bits.slice(i, i + 8).join(""), 2));
    for (let pad = 0xec; data.length < dataLen; pad ^= 0xec ^ 0x11) data.push(pad);

    // 2) 블록으로 나눠 오류 정정을 붙이고 열 단위로 섞기
    const shortN = nBlocks - (total % nBlocks), shortLen = Math.floor(total / nBlocks), div = divisor(eccLen), blocks = [];
    for (let i = 0, k = 0; i < nBlocks; i++) {
      const dl = shortLen - eccLen + (i < shortN ? 0 : 1), d = data.slice(k, k + dl); k += dl;
      blocks.push({ d, e: remainder(d, div) });
    }
    const out = [];
    for (let i = 0; i < blocks[blocks.length - 1].d.length; i++) blocks.forEach((b) => { if (i < b.d.length) out.push(b.d[i]); });
    for (let i = 0; i < eccLen; i++) blocks.forEach((b) => out.push(b.e[i]));

    // 3) 칸 배치
    const M = Array.from({ length: size }, () => new Array(size).fill(false)), F = Array.from({ length: size }, () => new Array(size).fill(false));
    const fn = (x, y, dark) => { M[y][x] = dark; F[y][x] = true; };
    for (let i = 0; i < size; i++) { fn(6, i, i % 2 === 0); fn(i, 6, i % 2 === 0); }
    for (const [cx, cy] of [[3, 3], [size - 4, 3], [3, size - 4]])
      for (let dy = -4; dy <= 4; dy++) for (let dx = -4; dx <= 4; dx++) { const x = cx + dx, y = cy + dy, d = Math.max(Math.abs(dx), Math.abs(dy)); if (x >= 0 && x < size && y >= 0 && y < size) fn(x, y, d !== 2 && d !== 4); }
    const ap = ALIGN[v];
    for (const cy of ap) for (const cx of ap) {
      if ((cx === 6 && cy === 6) || (cx === 6 && cy === ap[ap.length - 1]) || (cx === ap[ap.length - 1] && cy === 6)) continue;
      for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) fn(cx + dx, cy + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1);
    }
    const format = (mask) => {   // 오류 정정 M(00) + 마스크 3비트 → BCH(15,5) → 0x5412 로 섞음
      const d = (0 << 3) | mask; let r = d; for (let i = 0; i < 10; i++) r = (r << 1) ^ ((r >>> 9) * 0x537);
      const b = ((d << 10) | r) ^ 0x5412, bit = (i) => ((b >>> i) & 1) === 1;
      for (let i = 0; i <= 5; i++) fn(8, i, bit(i));
      fn(8, 7, bit(6)); fn(8, 8, bit(7)); fn(7, 8, bit(8));
      for (let i = 9; i < 15; i++) fn(14 - i, 8, bit(i));
      for (let i = 0; i < 8; i++) fn(size - 1 - i, 8, bit(i));
      for (let i = 8; i < 15; i++) fn(8, size - 15 + i, bit(i));
      fn(8, size - 8, true);
    };
    format(0);   // 자리만 잡음(아래에서 마스크마다 다시 씀)
    let i = 0;
    for (let right = size - 1; right >= 1; right -= 2) {
      if (right === 6) right = 5;
      for (let vert = 0; vert < size; vert++) for (let j = 0; j < 2; j++) {
        const x = right - j, y = ((right + 1) & 2) === 0 ? size - 1 - vert : vert;
        if (!F[y][x] && i < out.length * 8) { M[y][x] = ((out[i >>> 3] >>> (7 - (i & 7))) & 1) === 1; i++; }
      }
    }

    // 4) 마스크 8개를 모두 써 보고 벌점이 가장 낮은 것
    const MASK = [(x, y) => (x + y) % 2 === 0, (x, y) => y % 2 === 0, (x) => x % 3 === 0, (x, y) => (x + y) % 3 === 0,
      (x, y) => (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0, (x, y) => ((x * y) % 2) + ((x * y) % 3) === 0,
      (x, y) => (((x * y) % 2) + ((x * y) % 3)) % 2 === 0, (x, y) => (((x + y) % 2) + ((x * y) % 3)) % 2 === 0];
    const apply = (m) => { for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) if (!F[y][x] && MASK[m](x, y)) M[y][x] = !M[y][x]; };
    const penalty = () => {
      let p = 0;
      const line = (get) => {   // 한 줄: 같은 색 5칸 이상(3+초과), 1:1:3:1:1 모양 앞뒤 흰 4칸(40)
        let run = 1;
        for (let k = 1; k < size; k++) { if (get(k) === get(k - 1)) run++; else { if (run >= 5) p += 3 + (run - 5); run = 1; } }
        if (run >= 5) p += 3 + (run - 5);
        for (let k = 0; k + 11 <= size; k++) {
          const w = []; for (let t = 0; t < 11; t++) w.push(get(k + t) ? 1 : 0);
          const s = w.join("");
          if (s === "10111010000" || s === "00001011101") p += 40;
        }
      };
      for (let y = 0; y < size; y++) line((k) => M[y][k]);
      for (let x = 0; x < size; x++) line((k) => M[k][x]);
      for (let y = 0; y < size - 1; y++) for (let x = 0; x < size - 1; x++) { const c = M[y][x]; if (c === M[y][x + 1] && c === M[y + 1][x] && c === M[y + 1][x + 1]) p += 3; }
      let dark = 0; for (const r of M) for (const c of r) if (c) dark++;
      p += Math.floor(Math.abs(dark * 20 - size * size * 10) / (size * size)) * 10;
      return p;
    };
    let best = 0, bestP = Infinity;
    for (let m = 0; m < 8; m++) { apply(m); format(m); const p = penalty(); if (p < bestP) { bestP = p; best = m; } apply(m); }   // 같은 마스크를 한 번 더 적용하면 원래대로
    apply(best); format(best);
    return { size, version: v, mask: best, get: (x, y) => M[y][x] };
  }

  // SVG 문자열: 검정 칸을 가로로 이어 붙인 경로 하나. quiet = 바깥 여백(칸 수, 표준 4)
  function svg(text, { quiet = 4, dark = "#111317", light = "#fff", label = "QR 코드" } = {}) {
    const q = encode(text), n = q.size + quiet * 2;
    let d = "";
    for (let y = 0; y < q.size; y++) for (let x = 0; x < q.size; x++) {
      if (!q.get(x, y)) continue;
      let w = 1; while (x + w < q.size && q.get(x + w, y)) w++;
      d += `M${x + quiet} ${y + quiet}h${w}v1h-${w}z`; x += w - 1;
    }
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${n} ${n}" shape-rendering="crispEdges" role="img" aria-label="${label}"><rect width="${n}" height="${n}" fill="${light}"/><path d="${d}" fill="${dark}"/></svg>`;
  }

  (typeof window !== "undefined" ? window : globalThis).RideyQR = { encode, svg };
})();
