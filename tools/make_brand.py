"""RIDEY 브랜드 — 로고·앱 아이콘·큰 숫자 글꼴을 코드로 만든다 (docs/brand.md).

    pip install fonttools brotli          # 한 번 (brotli 는 woff2 압축)
    python tools/make_brand.py            # → web/icon.svg · site/img/mark.svg · docs/brand/*.svg · web/fonts/unbounded-ridey.woff2
                                          #   + web/index.html · site/index.html 안의 <!-- brand:wordmark --> 자리를 새 로고로
    그다음 node tools/make_icons.js && node tools/make_android_assets.js (PNG 아이콘·안드로이드 시작 화면)

로고 = 'RIDEY' + 신호 점. 글자는 Unbounded(SIL OFL 1.1, 예약 글꼴 이름 없음)의 굵기 760 을 도형으로 바꾼 것이고,
마침표 자리의 점은 정확한 원으로 다시 놓아 신호색(#FF4F1F)을 칠한다 — "점 하나가 신호다".
앱 아이콘 = 잉크 바탕에 'R' + 신호 점. 글꼴 파일은 data/cache/fonts 에 받아 두고 저장소에는 넣지 않는다(만든 도형만 넣음).
"""
import pathlib, re, sys, urllib.request
ROOT = pathlib.Path(__file__).resolve().parents[1]
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

FONT_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/unbounded/Unbounded%5Bwght%5D.ttf"
FONT = ROOT / "data" / "cache" / "fonts" / "Unbounded.ttf"
WGHT = 760
INK, PAPER, SIGNAL = "#111317", "#F7F5F0", "#FF4F1F"


def font():
    if not FONT.exists():
        FONT.parent.mkdir(parents=True, exist_ok=True)
        FONT.write_bytes(urllib.request.urlopen(urllib.request.Request(FONT_URL, headers={"User-Agent": "Mozilla/5.0"}), timeout=60).read())
    return instancer.instantiateVariableFont(TTFont(FONT), {"wght": WGHT})


def glyphs(f, text, size, track=-0.01):
    """글자들을 한 경로로(위가 0, 기준선 = 대문자 높이). 돌려줌: (경로, 너비, 높이, 마침표 원 (cx, cy, r))."""
    upm = f["head"].unitsPerEm; k = size / upm
    cmap, gs, hmtx = f.getBestCmap(), f.getGlyphSet(), f["hmtx"]
    cap = f["OS/2"].sCapHeight * k
    pen = SVGPathPen(gs, ntos=lambda v: f"{v:.1f}".rstrip("0").rstrip("."))
    x = 0.0
    for ch in text:
        g = cmap[ord(ch)]
        gs[g].draw(TransformPen(pen, (k, 0, 0, -k, x, cap)))
        x += hmtx[g][0] * k + track * size
    x -= track * size
    bp = BoundsPen(gs); gs[cmap[ord(".")]].draw(bp); x0, y0, x1, y1 = bp.bounds
    r = max(x1 - x0, y1 - y0) / 2 * 1.1 * k
    gap = size * 0.045
    dot = (x + gap + r, cap - r, r)   # 점 바닥 = 글자 바닥선 (마침표처럼 앉음)
    return pen.getCommands(), x + gap + 2 * r, cap, dot


def wordmark(f, size=100, ink="currentColor", dot=SIGNAL, label=True):
    d, w, h, (cx, cy, r) = glyphs(f, "RIDEY", size)
    a = ' role="img" aria-label="RIDEY"' if label else ' aria-hidden="true"'
    return (f'<svg class="wordmark" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.1f} {h:.1f}"{a}>'
            f'<path fill="{ink}" d="{d}"/><circle class="dot" cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{dot}"/></svg>')


def icon(f, size=512, bg=INK, fg=PAPER, dot=SIGNAL, rx=True):
    """앱 아이콘: 둥근 네모 + 가운데 'R' + 신호 점 (대문자 높이 = 아이콘의 36%)."""
    s = size * 0.36 / (f["OS/2"].sCapHeight / f["head"].unitsPerEm)
    d, w, h, (cx, cy, r) = glyphs(f, "R", s, track=0)
    ox, oy = (size - w) / 2, (size - h) / 2
    rr = f' rx="{size * 0.225:.0f}"' if rx else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}"><rect width="{size}" height="{size}"{rr} fill="{bg}"/>'
            f'<g transform="translate({ox:.1f} {oy:.1f})"><path fill="{fg}" d="{d}"/><circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{dot}"/></g></svg>')


def numbers_font():
    """큰 숫자·대문자용 Unbounded 일부(숫자·대문자·기호, 굵기 500~900) → woff2 약 9KB."""
    from fontTools import subset
    f = instancer.instantiateVariableFont(TTFont(FONT), {"wght": (500, 900)})
    o = subset.Options(); o.flavor = "woff2"; o.layout_features = ["kern", "tnum", "lnum"]; o.name_IDs = ["*"]
    s = subset.Subsetter(o); s.populate(text="0123456789%+-–~.,:/·×xABCDEFGHIJKLMNOPQRSTUVWXYZ "); s.subset(f)
    f.flavor = "woff2"
    out = ROOT / "web" / "fonts" / "unbounded-ridey.woff2"; out.parent.mkdir(exist_ok=True); f.save(out)
    lic = ROOT / "web" / "fonts" / "OFL-Unbounded.txt"
    if not lic.exists():
        lic.write_bytes(urllib.request.urlopen("https://raw.githubusercontent.com/google/fonts/main/ofl/unbounded/OFL.txt", timeout=60).read())
    return out


def put(path, html):
    """HTML 안의 <!-- brand:wordmark --> … <!-- /brand:wordmark --> 를 새 로고로 (여러 군데면 모두)."""
    p = ROOT / path
    if not p.exists():
        return 0
    s = p.read_text()
    s2, n = re.subn(r"(<!-- brand:wordmark -->)[\s\S]*?(<!-- /brand:wordmark -->)", lambda m: m.group(1) + html + m.group(2), s)
    if n:
        p.write_text(s2)
    return n


def main():
    f = font()
    (ROOT / "web" / "icon.svg").write_text(icon(f) + "\n")
    (ROOT / "site" / "img").mkdir(parents=True, exist_ok=True)
    (ROOT / "site" / "img" / "mark.svg").write_text(icon(f) + "\n")
    B = ROOT / "docs" / "brand"; B.mkdir(parents=True, exist_ok=True)
    (B / "wordmark.svg").write_text(wordmark(f, ink=INK) + "\n")
    (B / "wordmark-dark.svg").write_text(wordmark(f, ink=PAPER) + "\n")
    (B / "wordmark-mono.svg").write_text(wordmark(f, ink=INK, dot=INK) + "\n")
    (B / "icon.svg").write_text(icon(f) + "\n")
    (B / "icon-light.svg").write_text(icon(f, bg=PAPER, fg=INK) + "\n")
    w = wordmark(f, label=False)
    n = put("web/index.html", w) + put("site/index.html", w) + put("site/releases.html", w)
    try:
        out = numbers_font(); print(f"{out.relative_to(ROOT)} {out.stat().st_size / 1024:.1f}KB")
    except ImportError:
        print("woff2 는 건너뜀 — pip install brotli")
    print(f"아이콘·로고 완료 (HTML 로고 자리 {n}곳)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
