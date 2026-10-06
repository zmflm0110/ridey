"""앱 화면 사진(docs/shots/*.png)을 사이트용 가벼운 WebP 로 (가로 600px — 사이트는 폰 그림 안에 300px 남짓으로 보여 줌, 2배 선명도).

    python tools/make_webp.py        # SHOTS=docs/shots node tests/web/smoke.js 로 사진을 새로 찍은 뒤에

GitHub 의 사이트 만들기(tools/build_site.py)는 표준 라이브러리만 써서 거기서 줄일 수 없다 — 그래서 여기서 만들어 저장소에 둔다.
"""
import pathlib
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parents[1]
for png in sorted((ROOT / "docs" / "shots").glob("[1-4]_*.png")):
    im = Image.open(png).convert("RGB")
    im.thumbnail((600, 10000), Image.LANCZOS)
    out = png.with_suffix(".webp")
    im.save(out, "WEBP", quality=82, method=6)
    print(f"{png.name} {png.stat().st_size / 1024:.0f}KB → {out.name} {out.stat().st_size / 1024:.0f}KB ({im.size[0]}×{im.size[1]})")
