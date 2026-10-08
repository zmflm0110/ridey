"""실제 자전거 한 대의 12일 (SPB-69683, 2026년 6월) — 이야기의 첫 장면 그림.

    python analysis/spb69683.py      # → docs/img/spb69683.svg · spb69683-dark.svg (README) + site/data/spb69683.json (사이트가 그림)

6월 12일 15:20 부터 두 번째 신고(24일 17:18)까지, 브랜드의 '선과 점' 으로: 그냥 타고 간 대여는 선(—), 서로 다른 사람의
'빌리자마자 반납'(재시도 뺌)은 점(•, 신호색)으로 위로 쌓고, RIDEY 경보(두 번째 사람)·고장 신고 두 번은 세로선으로 (docs/brand.md 색).
"""
import datetime as dt, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
import pandas as pd

BIKE, START, END = "SPB-69683", "2026-06-12 15:20", "2026-06-24 17:18:45"
ALARM, REPORTS = "2026-06-12 15:43:35", ("2026-06-13 07:58:54", "2026-06-24 17:18:45")
T0 = dt.datetime(2026, 6, 12)
LIGHT = dict(bg="#FFFFFF", line="#E2DFD7", faint="#63676F", muted="#474B53", ink="#111317", accent="#C8320A", dud="#FF4F1F", ride="#9A9DA3")
DARK = dict(bg="#16191E", line="#262A31", faint="#8A8F98", muted="#B3B7BE", ink="#F3F1EC", accent="#FF7A52", dud="#FF5C2E", ride="#6B7078")


def timeline():
    M = pd.read_pickle(ROOT / "data" / "cache" / "ml" / "M_2606.pkl")
    B = M[M["bike"].astype(str) == BIKE].sort_values("t0")
    W = B[(B["t0"] >= START) & (B["t0"] < END)]
    hrs = lambda s: [(t - T0).total_seconds() / 3600 for t in s]
    h = lambda t: (pd.Timestamp(t) - T0).total_seconds() / 3600
    return dict(duds=hrs(W[W["dud"] & ~W["retry"]]["t1"]), rides=hrs(W[~W["dud"]]["t1"]), alarm=h(ALARM), reports=[h(t) for t in REPORTS])


def svg(D, c):
    X0, X1, H0, H1, base = 40, 980, 12, 306, 196
    x = lambda h: X0 + (h - H0) / (H1 - H0) * (X1 - X0)
    o = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 268" font-family="-apple-system, \'Apple SD Gothic Neo\', \'Noto Sans KR\', \'Pretendard\', sans-serif">',
         f'<rect width="1000" height="268" rx="18" fill="{c["bg"]}"/>', f'<line x1="{X0}" y1="{base}" x2="{X1}" y2="{base}" stroke="{c["line"]}" stroke-width="1.5"/>']
    for d in range(13, 25):
        xx = x((d - 12) * 24)
        o += [f'<line x1="{xx:.1f}" y1="70" x2="{xx:.1f}" y2="{base + 6}" stroke="{c["line"]}" stroke-dasharray="2 4"/>',
              f'<text x="{xx:.1f}" y="{base + 24}" text-anchor="middle" font-size="13" fill="{c["faint"]}">{d}일</text>']
    for h, alarm, label, anchor, row in [(D["alarm"], True, "15:43 RIDEY 경보", "start", 0), (D["reports"][0], False, "첫 고장 신고 (16시간 뒤)", "start", 1),
                                         (D["reports"][1], False, "두 번째 신고 → 사라짐", "end", 0)]:
        xx, y, col = x(h), 28 + row * 22, c["accent"] if alarm else c["ink"]
        o += [f'<line x1="{xx:.1f}" y1="{y + 6}" x2="{xx:.1f}" y2="{base}" stroke="{col}" stroke-width="{2 if alarm else 1.5}"{"" if alarm else " stroke-dasharray=\"5 4\""}/>',
              f'<text x="{xx + (6 if anchor == "start" else -6):.1f}" y="{y + 4}" text-anchor="{anchor}" font-size="14" font-weight="{700 if alarm else 600}" fill="{col}">{label}</text>']
    o += [f'<rect x="{x(h) - 5:.1f}" y="{base - 12}" width="10" height="4" rx="2" fill="{c["ride"]}"/>' for h in D["rides"]]   # 선 = 탄 대여
    rows = []
    for h in sorted(D["duds"]):   # 겹치지 않게 위로 쌓기
        xx, r = x(h), 0
        while any(abs(xx - px) < 10.5 for px, pr in rows if pr == r):
            r += 1
        rows.append((xx, r))
        o.append(f'<circle cx="{xx:.1f}" cy="{base - 30 - r * 11}" r="4.5" fill="{c["dud"]}" stroke="{c["bg"]}" stroke-width="1.5"/>')
    ly, lx = 250, 236
    o += [f'<circle cx="{lx}" cy="{ly - 4}" r="5" fill="{c["dud"]}"/><text x="{lx + 10}" y="{ly}" font-size="13" fill="{c["muted"]}">빌리자마자 반납 — 서로 다른 {len(D["duds"])}명</text>',
          f'<rect x="{lx + 218}" y="{ly - 7}" width="12" height="4" rx="2" fill="{c["ride"]}"/><text x="{lx + 236}" y="{ly}" font-size="13" fill="{c["muted"]}">그냥 타고 감 {len(D["rides"])}번</text>',
          f'<line x1="{lx + 352}" y1="{ly - 5}" x2="{lx + 368}" y2="{ly - 5}" stroke="{c["accent"]}" stroke-width="2"/><text x="{lx + 374}" y="{ly}" font-size="13" fill="{c["muted"]}">RIDEY 경보</text>',
          f'<line x1="{lx + 452}" y1="{ly - 5}" x2="{lx + 468}" y2="{ly - 5}" stroke="{c["ink"]}" stroke-width="1.5" stroke-dasharray="4 3"/><text x="{lx + 474}" y="{ly}" font-size="13" fill="{c["muted"]}">고장 신고</text>',
          "</svg>"]
    return "\n".join(o)


def main():
    D = timeline()
    after = sum(1 for h in D["duds"] if h > D["alarm"])
    print(f"{BIKE}: 서로 다른 {len(D['duds'])}명(경보 뒤 {after}명), 그냥 타고 감 {len(D['rides'])}번")
    (ROOT / "docs" / "img" / "spb69683.svg").write_text(svg(D, LIGHT))
    (ROOT / "docs" / "img" / "spb69683-dark.svg").write_text(svg(D, DARK))
    import json   # 사이트는 같은 숫자로 직접 그림(밝은·어두운 화면 색은 CSS)
    (ROOT / "site" / "data").mkdir(parents=True, exist_ok=True)
    json.dump({k: ([round(v, 3) for v in D[k]] if isinstance(D[k], list) else round(D[k], 3)) for k in ("duds", "rides", "alarm", "reports")},
              open(ROOT / "site" / "data" / "spb69683.json", "w"), separators=(",", ":"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
