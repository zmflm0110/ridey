"""경보 기준 탐색기용 격자 — 사이트 '기준을 바꿔 보세요' 가 읽는 site/data/rule_grid.json.

    python analysis/rule_grid.py            # 서울 1·3·6월 + 대전 5·10월, 기준 18가지(시간 60/120/180초 × 거리 100/200/300m × 연쇄 2/3)

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
    jan = {(r[0], r[1], r[2]): r for r in out["sets"][0]["rows"]}[(180, 300, 2)]
    print("1월 180·300·2:", jan, "(docs/phase1.md: 54.1% · 95.1건 · 89.7명)")


if __name__ == "__main__":
    main()
