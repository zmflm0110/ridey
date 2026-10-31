"""작품 소개 웹사이트(site/) 만들기 — 대여소·시연 자료를 site/data 로, 앱 화면 사진을 site/img 로,
CHANGELOG.md 를 진행 기록 쪽(site/releases.html)으로.

    python tools/build_site.py                 # site/ 갱신
    python tools/build_site.py --out _site     # 올릴 묶음: site/ 전체 — GitHub Pages 가 이걸 올린다
"""
import html, json, pathlib, re, shutil, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
S = ROOT / "site"
(S / "data").mkdir(parents=True, exist_ok=True); (S / "img").mkdir(exist_ok=True)

st = json.load(open(ROOT / "app" / "assets" / "data" / "stations.json"))
json.dump([[s["id"], s["name"].strip(), s["gu"], round(s["lat"], 5), round(s["lon"], 5)] for s in st],
          open(S / "data" / "stations.json", "w"), ensure_ascii=False, separators=(",", ":"))
for n in ("1_morning", "2_lookup", "3_rescue", "4_replay"):
    src = ROOT / "docs" / "shots" / f"{n}.webp"
    if src.exists():
        shutil.copy(src, S / "img" / f"{n}.webp")
    (S / "img" / f"{n}.png").unlink(missing_ok=True)
for p in sorted((S / "data").iterdir()) + sorted((S / "img").iterdir()):
    print(f"{p.relative_to(ROOT)}  {p.stat().st_size / 1024:.0f}KB")


def md_inline(t):
    t = html.escape(t.replace("\\~", "~"), quote=False)
    t = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m: f'<a href="{m.group(2) if m.group(2).startswith("http") else "https://github.com/zmflm0110/ridey/blob/master/" + m.group(2)}">{m.group(1)}</a>', t)


def releases():
    """CHANGELOG.md → site/releases.html (머리·꼬리·글꼴·색은 index.html 과 같은 style.css)"""
    body, in_list = [], False
    for line in (ROOT / "CHANGELOG.md").read_text().splitlines():
        if line.startswith("- "):
            if not in_list:
                body.append("<ul>"); in_list = True
            body.append(f"<li>{md_inline(line[2:])}</li>")
            continue
        if in_list:
            body.append("</ul>"); in_list = False
        if line.startswith("## "):
            m = re.match(r"## \[(.+?)\] - (\S+)", line)
            body.append(f"<h2>{html.escape(m.group(1))}<small>{html.escape(m.group(2))}</small></h2>" if m else f"<h2>{md_inline(line[3:])}</h2>")
        elif line.startswith("# ") or not line.strip():
            continue
        else:
            body.append(f'<p class="lede">{md_inline(line)}</p>')
    if in_list:
        body.append("</ul>")
    idx = (S / "index.html").read_text()
    head = re.sub(r"<title>.*?</title>", "<title>진행 기록 — RIDEY</title>", idx[:idx.index("</head>")], count=1)
    head = re.sub(r"<!-- 진행 기록 링크에.*?-->\n<script type=\"speculationrules\">.*?</script>\n", "", head, flags=re.S)
    header = idx[idx.index('<header class="nav"'):idx.index("</header>") + len("</header>")]
    header = header.replace('class="nav"', 'class="nav solid"').replace('href="#', 'href="./#')
    footer = idx[idx.index('<footer'):idx.index("</footer>") + len("</footer>")].replace('href="#', 'href="./#')
    theme = '<script src="main.js" defer></script>'
    page = f"""{head}</head>
<body>
{header}
<main class="doc">
<h1>진행 기록</h1>
{chr(10).join(body)}
</main>
{footer}
{theme}
</body>
</html>
"""
    (S / "releases.html").write_text(page)
    print("site/releases.html", f"{len(page) / 1024:.0f}KB")


releases()

if "--out" in sys.argv:
    out = pathlib.Path(sys.argv[sys.argv.index("--out") + 1])
    shutil.rmtree(out, ignore_errors=True)
    shutil.copytree(S, out)
    n = sum(1 for _ in out.rglob("*") if _.is_file())
    print(f"{out}/ 묶음: 파일 {n}개")
