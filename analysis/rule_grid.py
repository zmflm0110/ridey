"""경보 기준 탐색기용 격자 — 사이트 '기준을 바꿔 보세요' 가 읽는 site/data/rule_grid.json.

    python analysis/rule_grid.py            # 서울 1·3·6월 + 대전 5·10월, 기준 18가지(시간 60/120/180초 × 거리 100/200/300m × 연쇄 2/3)
                                            # → site/data/rule_grid.json (사이트 탐색기) + docs/img/rule-grid.svg (발표·README 그림)

analysis/phase1_rules.py 와 같은 정의(metrics)로 계산 — 1월 값은 docs/phase1.md 와 같아야 한다(아래에서 확인).
선택 규칙은 1월에서만 정했다(정밀도 ≥ 30% 중 하루 막은 수 최대 = 180초·300m·2연속). 다른 달·도시는 같은 기준을 그대로 시험한 결과.
"""
import itertools, json, pathlib, sys, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / "analysis"))
from engine.core import Rule, load_seoul, load_tashu, mark
from phase1_rules import metrics

RAW = ROOT / "data" / "raw"
SETS = [("서울 1월", "seoul-01", lambda: load_seoul(RAW / "rent_2601.csv")), ("서울 3월", "seoul-03", lambda: load_seoul(RAW / "rent_2603.csv")),
        ("서울 6월", "seoul-06", lambda: load_seoul(RAW / "rent_2606.csv")), ("대전 5월", "daejeon-05", lambda: load_tashu(RAW / "tashu" / "tashu_2505.csv")),
        ("대전 10월", "daejeon-10", lambda: load_tashu(RAW / "tashu" / "tashu_2510.csv"))]
GRID = list(itertools.product((60, 120, 180), (100, 200, 300), (2, 3)))


def figure(out, dest):
    """발표·README 용 그림 — 왼쪽: 1월 격자 18점(가로 하루 경보 수 · 세로 정밀도), 오른쪽: 1월에 고른 기준을 다른 달·도시에 그대로 적용한 결과."""
    INK, MUTED, FAINT, LINE, SIG, SIGT, CALM = "#111317", "#474B53", "#63676F", "#E2DFD7", "#FF4F1F", "#B82D07", "#2D5BFF"
    F = "-apple-system, 'Apple SD Gothic Neo', 'Noto Sans KR', 'Pretendard', sans-serif"
    jan = out["sets"][0]["rows"]; ch = out["chosen"]
    W, H = 1000, 380
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" font-family="{F}"><rect width="{W}" height="{H}" rx="18" fill="#fff"/>']
    # 왼쪽 패널
    L0, R0, T0, B0, XM, YM = 64, 470, 56, 318, 100, 80
    px = lambda x: L0 + x / XM * (R0 - L0); py = lambda y: T0 + (1 - y / YM) * (B0 - T0)
    o.append(f'<text x="{L0}" y="30" font-size="16" font-weight="800" fill="{INK}">기준 18가지 — 1월 기록으로 모두 돌려 봄</text>')
    for y in range(0, YM + 1, 20):
        o.append(f'<line x1="{L0}" x2="{R0}" y1="{py(y):.1f}" y2="{py(y):.1f}" stroke="{LINE}"/><text x="{L0 - 8}" y="{py(y) + 4:.1f}" font-size="12" text-anchor="end" fill="{FAINT}">{y}%</text>')
    for x in range(0, XM + 1, 20):
        o.append(f'<text x="{px(x):.1f}" y="{B0 + 20}" font-size="12" text-anchor="middle" fill="{FAINT}">{x}</text>')
    o.append(f'<text x="{R0}" y="{B0 + 40}" font-size="12.5" text-anchor="end" fill="{MUTED}">하루 경보 수 (건) →</text>')
    base = [r for r in jan if (r[0], r[1], r[2]) == (ch["sec"], ch["m"], ch["k"])][0][6]   # 고른 기준의 평소 비율
    o.append(f'<line x1="{L0}" x2="{R0}" y1="{py(base):.1f}" y2="{py(base):.1f}" stroke="{FAINT}" stroke-dasharray="3 5"/><text x="{R0}" y="{py(base) - 6:.1f}" font-size="12" font-weight="700" text-anchor="end" fill="{MUTED}">평소 자전거 약 {base:.1f}%</text>')
    for sec, m, k, p_, a_, v_, b_ in jan:
        mine = (sec, m, k) == (ch["sec"], ch["m"], ch["k"]); cx, cy = px(a_), py(p_)
        if k == 3: o.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="7" fill="#fff" stroke="{FAINT}" stroke-width="2.2"/>')
        else: o.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{9 if mine else 7}" fill="{SIG if mine else "#A9ABAF"}"/>')
        if mine:
            o.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="14" fill="none" stroke="{SIG}" stroke-width="1.6"/><text x="{cx:.1f}" y="{cy - 22:.1f}" font-size="13" font-weight="800" text-anchor="middle" fill="{SIGT}">우리 선택 3분·300m·2명</text>')
    o.append(f'<circle cx="{L0 + 6}" cy="{T0 + 12}" r="6" fill="#A9ABAF"/><text x="{L0 + 18}" y="{T0 + 16}" font-size="12" fill="{MUTED}">2명 연속</text>'
             f'<circle cx="{L0 + 92}" cy="{T0 + 12}" r="5" fill="#fff" stroke="{FAINT}" stroke-width="2"/><text x="{L0 + 104}" y="{T0 + 16}" font-size="12" fill="{MUTED}">3명 연속</text>')
    # 오른쪽 패널: 같은 기준을 다섯 세트에
    X0 = 560
    o.append(f'<text x="{X0}" y="30" font-size="16" font-weight="800" fill="{INK}">같은 기준을 처음 보는 달·도시에 그대로</text>')
    rows = []
    for st in out["sets"]:
        r = [x for x in st["rows"] if (x[0], x[1], x[2]) == (ch["sec"], ch["m"], ch["k"])][0]; rows.append((st["name"], r[3], r[6]))
    top = 74; gap = 46
    for i, (name, p_, b_) in enumerate(rows):
        y = top + i * gap
        o.append(f'<text x="{X0}" y="{y + 5}" font-size="14" font-weight="700" fill="{INK}">{name}{" · 기준을 정한 달" if i == 0 else ""}</text>')
        bx0, bw = X0 + 176, 170
        o.append(f'<rect x="{bx0}" y="{y - 9}" width="{bw}" height="18" rx="9" fill="#EFECE5"/>')
        o.append(f'<rect x="{bx0}" y="{y - 9}" width="{bw * p_ / 100:.1f}" height="18" rx="9" fill="{SIG if i == 0 else CALM}"/>')
        o.append(f'<circle cx="{bx0 + bw * b_ / 100:.1f}" cy="{y}" r="3.6" fill="{INK}"/>')
        o.append(f'<text x="{bx0 + bw + 14}" y="{y + 6}" font-size="18" font-weight="800" fill="{INK}">{p_:.1f}%</text>')
    o.append(f'<text x="{X0}" y="{top + 5 * gap + 6}" font-size="12.5" fill="{MUTED}">막대 = 경보 뒤 다음 사람도 또 반납한 비율 · 검은 점 = 평소 자전거({rows[0][2]:.1f}~{max(r[2] for r in rows):.1f}%)</text>')
    o.append(f'<text x="{X0}" y="{top + 5 * gap + 28}" font-size="12.5" fill="{MUTED}">기준은 1월 기록만으로 정했고, 나머지는 손대지 않았습니다.</text>')
    o.append("</svg>")
    dest.write_text("\n".join(o), encoding="utf-8")


def main():
    out = {"grid": {"sec": [60, 120, 180], "m": [100, 200, 300], "k": [2, 3]}, "chosen": {"sec": 180, "m": 300, "k": 2}, "sets": []}
    for name, key, load in SETS:
        t = time.time(); R = load(); rows = []
        for sec, m, k in GRID:
            rule = Rule(max_sec=sec, max_m=m, alarm_k=k)
            r = metrics(mark(R, rule), rule)
            rows.append([sec, m, k, r["precision_%"], r["alarms_per_day"], r["prevented_per_day"], r["base_%"]])
        out["sets"].append({"key": key, "name": name, "rows": rows})
        print(f"{name}: {len(R):,}행 {time.time() - t:.0f}초", flush=True)
    dest = ROOT / "site" / "data" / "rule_grid.json"
    dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
    figure(out, ROOT / "docs" / "img" / "rule-grid.svg")
    jan = {(r[0], r[1], r[2]): r for r in out["sets"][0]["rows"]}[(180, 300, 2)]
    print("1월 180·300·2:", jan, "(docs/phase1.md: 54.1% · 95.1건 · 89.7명)")


if __name__ == "__main__":
    main()
