"""자체 모델에 특징을 더하면 나아지나 — 더하기 전에 재 본다 (2026-10-06).

    python analysis/model_features.py      # → docs/model_features.md

목록 모델(analysis/snapshot_model.py, 특징 7개)에 '목록을 보는 시각(시간대)' 과 '주말', 그리고 '대여소 탓'
(지난 7일 그 대여소에서 다른 자전거들이 바로 반납된 비율 — 거치대·단말기 문제면 자전거 탓이 아닐 수 있어서, 2026-10-08)을 더해,
두 달로 배우고 남은 한 달로 시험하는 것을 세 번(1·3·6월) 돌린다. 기준: 로그 손실(확률이 얼마나 맞나)과 목록 위 20대 중 진짜 고장 비율.
SQL 로 옮기기 쉬운 것부터 시험했다 — 이득이 없으면 넣지 않는다(5분 작업을 무겁게 하지 않게).
"""
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import numpy as np
import pandas as pd
from analysis.snapshot_model import marked, samples_from, FEATS6
from analysis.train_model import model


def ll(y, p):
    p = np.clip(p, 1e-6, 1 - 1e-6)
    return float(-np.mean(y * np.log(p) + (1 - y) * np.log(1 - p)))


def top(d, p, k=20):
    G = pd.DataFrame({"at": d["at"].values, "p": p, "y": d["y"].values})
    return float(G.sort_values(["at", "p"], ascending=[True, False]).groupby("at").head(k)["y"].mean())


W = np.timedelta64(7, "D")


def add_station(M, S):
    """표본마다: 지난 7일 그 대여소(반납한 곳)에서 다른 자전거의 헛대여 수 ÷ (그곳 대여 수 + 10)."""
    M = M.reset_index(drop=True)
    st = M["st1"].to_numpy()[S["row"].to_numpy()]; bk = M["bike"].astype(str).to_numpy()[S["row"].to_numpy()]
    T = S["at"].to_numpy()
    D = M[M["dud"]]
    dst = {k: np.sort(v.to_numpy()) for k, v in D.groupby("st1")["t1"]}
    down = {k: np.sort(v.to_numpy()) for k, v in D.assign(bike=D["bike"].astype(str)).groupby(["st1", "bike"])["t1"]}
    rst = {k: np.sort(v.to_numpy()) for k, v in M.groupby("st0")["t0"]}
    cnt = lambda a, lo, hi: 0 if a is None else int(np.searchsorted(a, hi, "left") - np.searchsorted(a, lo, "left"))
    other = np.zeros(len(S)); rent = np.zeros(len(S))
    for i in range(len(S)):
        lo, hi = T[i] - W, T[i]
        other[i] = cnt(dst.get(st[i]), lo, hi) - cnt(down.get((st[i], bk[i])), lo, hi)
        rent[i] = cnt(rst.get(st[i]), lo, hi)
    S = S.copy()
    S["st_other"] = (other / (rent + 10)).astype(np.float32)
    return S


def main():
    S = {}
    for ym in ("2601", "2603", "2606"):
        M = marked(ym); S[ym] = add_station(M, samples_from(M))
    for d in S.values():
        at = pd.to_datetime(d["at"])
        d["hour"] = at.dt.hour.astype(np.float32)
        d["wkend"] = (at.dt.dayofweek >= 5).astype(np.float32)
    rows = []
    for feats, name in ((FEATS6, "지금 모델 (7개)"), (FEATS6 + ["hour"], "+ 시간대"), (FEATS6 + ["hour", "wkend"], "+ 시간대·주말"),
                        (FEATS6 + ["st_other"], "+ 대여소 탓")):
        r = {"특징": name}
        for test in S:
            tr = pd.concat([S[m] for m in S if m != test]); te = S[test]
            p = model().fit(tr[feats], tr["y"]).predict_proba(te[feats])[:, 1]
            r[f"{test} 손실"] = round(ll(te["y"].to_numpy(), p), 4); r[f"{test} 위20"] = f"{top(te, p):.1%}"
        rows.append(r); print(r, flush=True)
    T = pd.DataFrame(rows)
    lines = ["# 자체 모델에 특징 더하기 — 재 보고 버린 것 (자동 생성: `python analysis/model_features.py`)", "", __doc__.split("\n", 1)[1].strip(), "",
             T.to_markdown(index=False), "",
             "→ 세 달 모두 로그 손실 차이 0.001 미만, 위 20대 +0\\~0.4%p. **넣지 않는다** (이유는 추정: '경과 시간·외면' 이 이미 시간대의 영향을 담는 듯).",
             "",
             "→ '대여소 탓' 도 손실 차이 0.001 안팎, 위 20대 +0\\~0.1%p — **넣지 않는다**. 남의 헛대여가 많은 대여소(위 4분위)는 다음 사람 반납 비율이 1·6월에 4\\~6%p 낮았지만 3월엔 차이가 없었고, 모델엔 보탬이 안 됐다",
             "(서로 다른 두 사람이 같은 자전거를 연달아 포기해야 경보라, 대여소 문제는 이미 대부분 걸러지는 듯)."]
    (ROOT / "docs" / "model_features.md").write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
