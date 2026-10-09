"""실제 자전거 한 대의 12일 (SPB-69683, 2026년 6월) — 이야기의 첫 장면 그림.

    python analysis/spb69683.py      # → docs/img/spb69683.svg · spb69683-dark.svg (README) · spb69683-slide.svg (발표) + site/data/spb69683.json (사이트가 그림)

6월 12일 15:20 부터 두 번째 신고(24일 17:18)까지, 사이트와 같은 '하루에 한 줄' 표로: 날마다 한 줄, 그날의 대여를 시간 순서대로
그냥 타고 간 대여는 선(—), 서로 다른 사람의 '빌리자마자 반납'(재시도 뺌)은 점(•, 신호색), 고장 신고는 세로 막대(|).
첫 사람은 빈 점, 서로 다른 두 번째 사람(RIDEY 경보)은 고리를 두른 점 — 그 줄은 옅게 물들임 (docs/brand.md 색).
"""
import datetime as dt, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
import pandas as pd

BIKE, START, END = "SPB-69683", "2026-06-12 15:20", "2026-06-24 17:18:45"
ALARM, REPORTS = "2026-06-12 15:43:35", ("2026-06-13 07:58:54", "2026-06-24 17:18:45")
T0 = dt.datetime(2026, 6, 12)
LIGHT = dict(bg="#FFFFFF", line="#E2DFD7", faint="#63676F", muted="#474B53", ink="#111317", accent="#B82D07", dud="#FF4F1F", ride="#A9ABAF", band=".09")
DARK = dict(bg="#16191E", line="#262A31", faint="#8A8F98", muted="#B3B7BE", ink="#F3F1EC", accent="#FF7A52", dud="#FF5C2E", ride="#5A5F67", band=".16")


def timeline():
    M = pd.read_pickle(ROOT / "data" / "cache" / "ml" / "M_2606.pkl")
    B = M[M["bike"].astype(str) == BIKE].sort_values("t0")
    W = B[(B["t0"] >= START) & (B["t0"] < END)]
    hrs = lambda s: [(t - T0).total_seconds() / 3600 for t in s]
    h = lambda t: (pd.Timestamp(t) - T0).total_seconds() / 3600
    return dict(duds=hrs(W[W["dud"] & ~W["retry"]]["t1"]), rides=hrs(W[~W["dud"]]["t1"]), alarm=h(ALARM), reports=[h(t) for t in REPORTS])


def svg(D, c, RH=28):
    """사이트 '하루에 한 줄' 표와 같은 그림: 날마다 한 줄, 그날의 대여를 시간 순서대로 점·선·세로 막대로. RH = 줄 높이(발표는 22로 낮게)."""
    W, PAD, LANE, TOP = 1000, 28, 104, 62
    ev = sorted([(h, "d") for h in D["duds"]] + [(h, "r") for h in D["rides"]] + [(h, "R") for h in D["reports"]])
    first, alarm = min(D["duds"]), min(D["duds"], key=lambda h: abs(h - D["alarm"]))
    after = sum(1 for h in D["duds"] if h > alarm)
    hm = lambda h: f"{int((h % 24) * 60 + 1e-6) // 60:02d}:{int((h % 24) * 60 + 1e-6) % 60:02d}"   # 버림 — 본문 시각(15:43)과 같게
    NOTE = {12: (f"{hm(alarm)}", "RIDEY 경보 — 서로 다른 두 번째 사람"), 13: (hm(D["reports"][0]), "첫 고장 신고. 그 뒤에도 54번 더"),
            16: ("07:13", "출근길 37분 사이 7명이 연달아"), 21: ("", "누군가 탔다 — 그래도 고쳐지지 않음"), 24: (hm(D["reports"][1]), "두 번째 신고 → 사라짐")}
    WD = "월화수목금토일"
    H = TOP + 13 * RH + 58
    o = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" font-family="-apple-system, \'Apple SD Gothic Neo\', \'Noto Sans KR\', \'Pretendard\', sans-serif">' % (W, H),
         f'<defs><linearGradient id="band" x1="0" x2="1"><stop offset="0" stop-color="{c["dud"]}" stop-opacity="{c["band"]}"/><stop offset=".72" stop-color="{c["dud"]}" stop-opacity="0"/></linearGradient></defs>',
         f'<rect width="{W}" height="{H}" rx="18" fill="{c["bg"]}"/>',
         f'<text x="{PAD}" y="40"><tspan font-size="21" font-weight="800" fill="{c["ink"]}" letter-spacing="-.4">{BIKE}</tspan>'
         f'<tspan dx="12" font-size="13" font-weight="600" fill="{c["muted"]}">서울 강서구 · 2026년 6월 12~24일</tspan></text>']
    lx = 572   # 범례 — 오른쪽 위 (글자 폭을 넉넉히 잡아 어느 글꼴에서도 겹치지 않게)
    o += [f'<circle cx="{lx + 5}" cy="35.5" r="5" fill="{c["dud"]}"/><text x="{lx + 17}" y="40" font-size="13" font-weight="600" fill="{c["muted"]}">빌리자마자 반납 <tspan font-weight="800" fill="{c["ink"]}">{len(D["duds"])}명</tspan></text>',
          f'<rect x="{lx + 173}" y="32.25" width="20" height="6.5" rx="3.25" fill="{c["ride"]}"/><text x="{lx + 200}" y="40" font-size="13" font-weight="600" fill="{c["muted"]}">그냥 타고 감 <tspan font-weight="800" fill="{c["ink"]}">{len(D["rides"])}번</tspan></text>',
          f'<rect x="{lx + 332}" y="28" width="2.5" height="15" rx="1.25" fill="{c["ink"]}"/><text x="{lx + 342}" y="40" font-size="13" font-weight="600" fill="{c["muted"]}">고장 신고</text>',
          f'<line x1="{PAD}" y1="{TOP}" x2="{W - PAD}" y2="{TOP}" stroke="{c["line"]}"/>']
    for i, d in enumerate(range(12, 25)):
        y0 = TOP + i * RH; cy = y0 + RH / 2
        row = [(h, k) for h, k in ev if 12 + int(h // 24) == d]
        dots = sum(1 for _, k in row if k == "d")
        is_alarm = any(k == "d" and h == alarm for h, k in row)
        if is_alarm:   # 경보 줄 — 카드 끝까지 옅게, 왼쪽 끝에 신호 막대
            o += [f'<rect x="0" y="{y0}" width="{W}" height="{RH}" fill="url(#band)"/>', f'<rect x="0" y="{y0}" width="3" height="{RH}" fill="{c["dud"]}"/>']
        if i < 12:
            o.append(f'<line x1="{PAD}" y1="{y0 + RH}" x2="{W - PAD}" y2="{y0 + RH}" stroke="{c["line"]}"/>')
        o.append(f'<text x="{PAD}" y="{cy + 5}" font-size="14" font-weight="800" fill="{c["ink"] if row else c["faint"]}">6/{d}'
                 f'<tspan dx="7" font-size="11.5" font-weight="600" fill="{c["faint"]}">{WD[dt.date(2026, 6, d).weekday()]}</tspan></text>')
        x = LANE
        for h, k in row:
            if k == "R":
                o.append(f'<rect x="{x + 3:.1f}" y="{cy - 8}" width="2.5" height="16" rx="1.25" fill="{c["ink"]}"/>'); x += 13
            elif k == "r":
                o.append(f'<rect x="{x:.1f}" y="{cy - 3.25}" width="20" height="6.5" rx="3.25" fill="{c["ride"]}"/>'); x += 24.5
            elif h == first:   # 첫 사람 — 빈 점(한 명만으로는 경보 없음)
                o.append(f'<circle cx="{x + 5:.1f}" cy="{cy}" r="4.2" fill="none" stroke="{c["dud"]}" stroke-width="1.6"/>'); x += 14.5
            elif h == alarm:   # 서로 다른 두 번째 사람 = 경보 — 고리를 두른 점
                x += 3.5
                o.append(f'<circle cx="{x + 5:.1f}" cy="{cy}" r="5" fill="{c["dud"]}"/><circle cx="{x + 5:.1f}" cy="{cy}" r="8.4" fill="none" stroke="{c["dud"]}" stroke-width="1.6"/>'); x += 18
            else:
                o.append(f'<circle cx="{x + 5:.1f}" cy="{cy}" r="5" fill="{c["dud"]}"/>'); x += 14.5
        if not row:
            o.append(f'<text x="{LANE}" y="{cy + 4.5}" font-size="13" fill="{c["faint"]}">아무도 빌리지 않음</text>')
        o.append(f'<text x="520" y="{cy + 5}" text-anchor="end" font-size="14" font-weight="{800 if dots else 600}" fill="{c["accent"] if dots else c["faint"]}">{dots or "–"}</text>')
        if d in NOTE:
            t, note = NOTE[d]; col = c["accent"] if is_alarm else c["muted"]
            o.append(f'<text x="544" y="{cy + 4.5}" font-size="13.5" font-weight="600" fill="{col}">' +
                     (f'<tspan font-weight="800" fill="{c["accent"] if is_alarm else c["ink"]}">{t}</tspan><tspan dx="7">{note}</tspan>' if t else note) + "</text>")
    fy = TOP + 13 * RH + 8
    o += [f'<line x1="{PAD}" y1="{fy}" x2="{W - PAD}" y2="{fy}" stroke="{c["line"]}"/>',
          f'<text x="{PAD}" y="{fy + 30}" font-size="13.5" font-weight="500" fill="{c["muted"]}">점 하나가 한 사람. 서로 다른 <tspan font-weight="800" fill="{c["ink"]}">두 번째 점</tspan>에서 RIDEY 경보 — 그 뒤로도 '
          f'<tspan font-weight="800" fill="{c["accent"]}">{after}명</tspan>이 이 자전거를 빌렸다가 바로 돌려놓았다.</text>', "</svg>"]
    return "\n".join(o)


def main():
    D = timeline()
    after = sum(1 for h in D["duds"] if h > D["alarm"])
    print(f"{BIKE}: 서로 다른 {len(D['duds'])}명(경보 뒤 {after}명), 그냥 타고 감 {len(D['rides'])}번")
    (ROOT / "docs" / "img" / "spb69683.svg").write_text(svg(D, LIGHT))
    (ROOT / "docs" / "img" / "spb69683-dark.svg").write_text(svg(D, DARK))
    (ROOT / "docs" / "img" / "spb69683-slide.svg").write_text(svg(D, LIGHT, RH=22))   # 발표 2장 — 1280×720 한 장에 13줄
    import json   # 사이트는 같은 숫자로 직접 그림(밝은·어두운 화면 색은 CSS)
    (ROOT / "site" / "data").mkdir(parents=True, exist_ok=True)
    json.dump({k: ([round(v, 3) for v in D[k]] if isinstance(D[k], list) else round(D[k], 3)) for k in ("duds", "rides", "alarm", "reports")},
              open(ROOT / "site" / "data" / "spb69683.json", "w"), separators=(",", ":"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
