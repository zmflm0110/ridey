"""클라우드 SQL(supabase/*.sql) 이 파이썬 엔진과 같은 답을 내나 — 진짜 Postgres 에서 (CI 는 postgres 서비스, 로컬은 PG_TEST_DSN).

    PG_TEST_DSN="host=localhost port=54329 user=postgres dbname=postgres" python -m pytest -q tests/test_sql_parity.py

원본 자료 없이: 정해진 난수로 9일 치 대여 기록을 만든다 — 고장 연쇄(서로 다른 사람·같은 사람 재시도·생년 없는 사람), 마음이 바뀐 한 번짜리
바로 반납, 정상 이동, 고친 뒤 다시 정상. 같은 기록을 파이썬(server/live.py live_state, engine/core.py mark)과 SQL(live.record_alarms·compute·score)에
넣고 지금 목록(자전거·연쇄·대여소)·오늘 경보 수·채점(경보 뒤 다음 다른 사람)이 같은지 본다. 5분 작업처럼 캐시(live.mark_cache)를 채운 길도, live.tick 이 오류 없이 도는지도.
"""
import json, os, pathlib, subprocess, sys, tempfile
import numpy as np
import pandas as pd
import pytest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
DSN = os.environ.get("PG_TEST_DSN")
pytestmark = pytest.mark.skipif(not DSN, reason="PG_TEST_DSN 이 있을 때만 (CI 는 postgres 서비스)")
DB = "ridey_sql_parity"
NOW = pd.Timestamp("2026-06-20 18:00")


def psql(sql, db=DB):
    r = subprocess.run(["psql", f"{DSN} dbname={db}", "-X", "-At", "-q", "-v", "ON_ERROR_STOP=1"], input=sql, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr[-2000:]
    return r.stdout.strip()


def synth(seed=7, bikes=300, days=9):
    """현실 비슷한 가짜 대여 기록 (자전거는 반납한 대여소에서 다음 대여가 시작)."""
    rng = np.random.default_rng(seed)
    stations = [f"{i:05d}" for i in range(101, 161)]
    who = lambda p_none=0.08: None if rng.random() < p_none else f"{rng.integers(1960, 2006)}{rng.choice(['M', 'F'])}"
    rows, start = [], NOW - pd.Timedelta(days=days)
    for b in range(bikes):
        bike, loc = f"SPB-{30000 + b:05d}", rng.choice(stations)
        t, broken_until = start + pd.Timedelta(minutes=int(rng.integers(0, 600))), None
        while t < NOW:
            if broken_until is None and rng.random() < 0.04:   # 고장 남
                broken_until = t + pd.Timedelta(hours=float(rng.uniform(1, 70)))
            if broken_until is not None and t < broken_until:   # 빌리자마자 반납
                w = who(); t1 = t + pd.Timedelta(seconds=int(rng.integers(8, 175)))
                rows.append((bike, t, loc, t1, loc, float(rng.choice([0, 0, 0, 50.0, 111.2])), w))
                if w and rng.random() < 0.2:   # 같은 사람이 한 번 더 해 봄
                    t2 = t1 + pd.Timedelta(seconds=int(rng.integers(20, 110))); t3 = t2 + pd.Timedelta(seconds=int(rng.integers(8, 90)))
                    rows.append((bike, t2, loc, t3, loc, 0.0, w)); t1 = t3
                t = t1 + pd.Timedelta(minutes=float(rng.exponential(80)) + 1)
                continue
            broken_until = None
            if rng.random() < 0.04:   # 마음이 바뀐 한 번짜리 바로 반납
                t1 = t + pd.Timedelta(seconds=int(rng.integers(10, 170)))
                rows.append((bike, t, loc, t1, loc, 0.0, who())); t = t1 + pd.Timedelta(minutes=float(rng.exponential(60)) + 1)
                continue
            dest = rng.choice(stations); t1 = t + pd.Timedelta(seconds=int(rng.integers(300, 3600)))
            rows.append((bike, t, loc, t1, dest, float(rng.uniform(500, 6000)), who(0.05)))
            loc, t = dest, t1 + pd.Timedelta(minutes=float(rng.exponential(240)) + 1)
    R = pd.DataFrame(rows, columns=["bike", "t0", "st0", "t1", "st1", "dist_m", "who"])
    R = R[R["t1"] <= NOW]   # 지금까지 반납된 것만 보인다
    R["t0"] = R["t0"].dt.floor("s"); R["t1"] = R["t1"].dt.floor("s")
    return R.drop_duplicates(["bike", "t0"]).sort_values(["bike", "t0"], kind="stable").reset_index(drop=True)


@pytest.fixture(scope="module")
def loaded():
    from tools.live_sql_compare import STUBS, portable
    psql(f"drop database if exists {DB}", "postgres"); psql(f"create database {DB}", "postgres")
    psql("create schema live;" + STUBS)
    for f in ("model.sql", "live.sql", "calib.sql"):
        psql(portable((ROOT / "supabase" / f).read_text()))
    R = synth()
    csv = pathlib.Path(tempfile.mkdtemp()) / "r.csv"
    R.assign(t0=R["t0"].dt.strftime("%Y-%m-%d %H:%M:%S"), t1=R["t1"].dt.strftime("%Y-%m-%d %H:%M:%S")).to_csv(csv, header=False, index=False)
    psql(f"\\copy live.rentals (bike, t0, st0, t1, st1, dist_m, who) from '{csv}' with csv\nanalyze live.rentals;")
    psql(f"select live.record_alarms('{NOW}'::timestamp)")
    yield R
    psql(f"drop database if exists {DB}", "postgres")


def python_list(R):
    from server import live
    R7 = R[R["t0"] >= NOW - pd.Timedelta(days=7)].reset_index(drop=True)
    bikes, alarms = live.live_state(R7, NOW)
    return {(b["bike"], b["chain"], b["station"]) for b in bikes}, int((alarms["t1"] >= NOW.normalize()).sum())


def sql_list():
    out = json.loads(psql(f"select live.compute('{NOW}'::timestamp)"))
    return {(b["bike"], b["chain"], b["station"]) for b in out["bikes"]}, out["today_alarms"], out


def test_synthetic_data_has_what_we_need(loaded):
    py, today = python_list(loaded)
    assert len(loaded) > 5000 and len(py) >= 5 and today >= 1, (len(loaded), len(py), today)
    assert any(c >= 3 for _, c, _ in py), "빨강(서로 다른 3명+) 도 있어야"


def test_list_and_today_alarms_match_python(loaded):
    py, today = python_list(loaded)
    sq, sq_today, out = sql_list()
    assert py == sq, (sorted(py - sq)[:5], sorted(sq - py)[:5])
    assert today == sq_today
    assert all(0 <= b["p_next"] <= 100 for b in out["bikes"]), "자전거마다 AI 확률"
    assert out["model"]["at_least"] <= out["model"]["expected"] + 1e-9


def test_cached_marks_give_same_list(loaded):
    _, _, before = sql_list()
    psql(f"truncate live.mark_cache; insert into live.mark_cache select '{NOW}'::timestamp, * from live.mark_rows('{NOW}'::timestamp - interval '7 days', live.cand('{NOW}'::timestamp))")
    _, _, after = sql_list()
    psql("truncate live.mark_cache")
    assert before["bikes"] == after["bikes"] and before["today_alarms"] == after["today_alarms"]


def test_score_matches_python(loaded):
    from engine.core import mark
    from engine.morning import RULE
    sc = json.loads(psql(f"select live.score('{NOW}'::timestamp, false)"))
    A = pd.read_csv(pd.io.common.StringIO(psql("copy (select bike, at from live.alarms) to stdout with csv")), names=["bike", "at"], parse_dates=["at"])
    M = mark(loaded[loaded["t0"] >= NOW - pd.Timedelta(days=9)].reset_index(drop=True), RULE)
    g = {k: v for k, v in M.groupby("bike")}
    hit = scored = 0
    for a in A.itertuples():
        b = g.get(a.bike)
        nxt = b[(b["t0"] > a.at) & ~b["retry"]] if b is not None else None
        if nxt is not None and not nxt.empty:
            scored += 1; hit += bool(nxt["dud"].iloc[0])
    assert len(A) >= 5 and scored >= 1
    assert (hit, scored) == (sc["next_rider_dud"], sc["scored"])
    # 운영 성적표 뷰(날짜별): 결과를 적어 둔(settle) 뒤엔 합이 채점과 같다. 가짜 기록은 경보를 한 시점에 몰아 적으므로 '바로 본 경보' 로 잠깐 바꿔서
    psql(f"select live.settle('{NOW}'::timestamp + interval '8 hours')")
    out = psql("begin; update live.alarms set seen_at = at;"
               "select coalesce(sum(scored), 0) || ',' || coalesce(sum(hit), 0) || ',' || count(*) from public.ops_alarm_days;"
               "select count(next_dud) || ',' || count(*) filter (where next_dud) from live.alarms; rollback;").split("\n")
    days, settled = out[0].rsplit(",", 1)[0], out[1]
    assert days == settled and days != "0,0" and int(out[0].rsplit(",", 1)[1]) >= 2, out


def test_tick_runs(loaded):
    # 마지막에: tick 은 '진짜 지금' 기준으로 오래된 대여를 지우므로 가짜 기록이 사라진다
    psql("select live.tick(); select live.tick();")
    assert psql("select count(*) from live.tick_log") != "0"
