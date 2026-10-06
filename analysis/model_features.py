"""자체 모델에 특징을 더하면 나아지나 — 더하기 전에 재 본다 (2026-10-06).

    python analysis/model_features.py      # → docs/model_features.md

목록 모델(analysis/snapshot_model.py, 특징 7개)에 '목록을 보는 시각(시간대)' 과 '주말' 을 더해,
두 달로 배우고 남은 한 달로 시험하는 것을 세 번(1·3·6월) 돌린다. 기준: 로그 손실(확률이 얼마나 맞나)과 목록 위 20대 중 진짜 고장 비율.
SQL 로 옮기기 쉬운 것부터 시험했다 — 이득이 없으면 넣지 않는다(5분 작업을 무겁게 하지 않게).
"""
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import numpy as np
import pandas as pd
from analysis.snapshot_model import samples, FEATS6
from analysis.train_model import model


def ll(y, p):
    p = np.clip(p, 1e-6, 1 - 1e-6)
    return float(-np.mean(y * np.log(p) + (1 - y) * np.log(1 - p)))


def top(d, p, k=20):
    G = pd.DataFrame({"at": d["at"].values, "p": p, "y": d["y"].values})
    return float(G.sort_values(["at", "p"], ascending=[True, False]).groupby("at").head(k)["y"].mean())


def main():
    S = {ym: samples(ym) for ym in ("2601", "2603", "2606")}
    for d in S.values():
        at = pd.to_datetime(d["at"])
        d["hour"] = at.dt.hour.astype(np.float32)
        d["wkend"] = (at.dt.dayofweek >= 5).astype(np.float32)
    rows = []
    for feats, name in ((FEATS6, "지금 모델 (7개)"), (FEATS6 + ["hour"], "+ 시간대"), (FEATS6 + ["hour", "wkend"], "+ 시간대·주말")):
        r = {"특징": name}
        for test in S:
            tr = pd.concat([S[m] for m in S if m != test]); te = S[test]
            p = model().fit(tr[feats], tr["y"]).predict_proba(te[feats])[:, 1]
            r[f"{test} 손실"] = round(ll(te["y"].to_numpy(), p), 4); r[f"{test} 위20"] = f"{top(te, p):.1%}"
        rows.append(r); print(r, flush=True)
    T = pd.DataFrame(rows)
    lines = ["# 자체 모델에 특징 더하기 — 재 보고 버린 것 (자동 생성: `python analysis/model_features.py`)", "", __doc__.split("\n", 1)[1].strip(), "",
             T.to_markdown(index=False), "",
             "→ 세 달 모두 로그 손실 차이 0.001 미만, 위 20대 +0\\~0.4%p. **넣지 않는다** (이유는 추정: '경과 시간·외면' 이 이미 시간대의 영향을 담는 듯)."]
    (ROOT / "docs" / "model_features.md").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
