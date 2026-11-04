"""앱 지도의 대여소 목록(app/assets/data/stations.json)을 지금 운영 중인 대여소로 다시 만든다.

    python tools/refresh_stations.py           # 바꿀 내용만 보여 줌
    python tools/refresh_stations.py --write   # 파일에 씀

- 좌표·이름·구: 서울 열린데이터광장 '공공자전거 대여소 정보'(tbCycleStationInfo, 공식 원부 — 문 닫은 곳도 들어 있다).
- 지금 운영 중인지: 클라우드가 5분마다 받는 실시간 대여소 현황(공개 뷰 live_station_status)에 있는 곳만.
  (2026-11-04 확인: 실시간 현황의 좌표는 원부와 0m 차이로 같았다.)
2026-11-04 에 만든 이유: 6월 원부로 만든 목록이 지금과 105곳 30m 넘게 어긋났고(최대 289m, 옮기며 이름이 바뀐 곳 포함),
문 닫은 65곳이 지도에 남고 새로 생긴 13곳이 빠져 있었다.
"""
import json, math, pathlib, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from server.seoul_api import key  # noqa: E402

OUT = ROOT / "app" / "assets" / "data" / "stations.json"
SUPABASE = "https://iqvquwvoljzuvdgtbpnu.supabase.co/rest/v1/live_station_status?select=id"
PUBLISHABLE = "sb_publishable_YFBKlBvyPFAhBpLdS3o8_A_xIeUmTVE"


def master():
    k, rows, start = key(), [], 1
    while True:
        url = f"http://openapi.seoul.go.kr:8088/{k}/json/tbCycleStationInfo/{start}/{start + 999}/"
        body = json.load(urllib.request.urlopen(url, timeout=30))["stationInfo"]
        rows += body["row"]
        if start + 999 >= int(body["list_total_count"]):
            return {r["RENT_NO"]: r for r in rows}
        start += 1000


def operating():
    ids = set()
    for a in range(0, 10000, 1000):
        req = urllib.request.Request(SUPABASE, headers={"apikey": PUBLISHABLE, "Range-Unit": "items", "Range": f"{a}-{a + 999}"})
        page = json.load(urllib.request.urlopen(req, timeout=30))
        ids |= {r["id"] for r in page}
        if len(page) < 1000:
            return ids


def meters(a, b, c, d):
    p1, p2 = math.radians(a), math.radians(c)
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(d - b) / 2) ** 2
    return 2 * 6371000 * math.asin(math.sqrt(h))


def main():
    m, live = master(), operating()
    if len(live) < 2000:
        raise SystemExit(f"실시간 대여소가 {len(live)}곳뿐 — 받기가 덜 된 것 같아 멈춤")
    new = []
    for i in sorted(live):
        r = m.get(i)
        if not r:
            continue
        lat, lon = float(r["STA_LAT"] or 0), float(r["STA_LONG"] or 0)
        if not lat or not lon:
            continue
        new.append({"id": i, "name": r["RENT_NM"].strip(), "gu": r["STA_LOC"].strip(), "lat": round(lat, 6), "lon": round(lon, 6)})
    old = {s["id"]: s for s in json.load(open(OUT))}
    ids = {s["id"] for s in new}
    moved = [(round(meters(o["lat"], o["lon"], s["lat"], s["lon"])), s["name"]) for s in new if (o := old.get(s["id"]))]
    print(f"운영 중 {len(new)}곳 (전 {len(old)}곳) · 새로 {len(ids - old.keys())} · 빠짐(운영 안 함) {len(old.keys() - ids)}"
          f" · 30m 넘게 옮김 {sum(d > 30 for d, _ in moved)}")
    if "--write" in sys.argv:
        json.dump(new, open(OUT, "w"), ensure_ascii=False)
        print("썼음:", OUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
