"""운영 성적표 그림 — 실시간 경보가 울린 날마다 '다음 다른 사람도 바로 반납' 비율 (README).

    python analysis/ops_days.py      # → docs/img/ops-days.svg · ops-days-dark.svg

자료는 클라우드 DB 의 공개 뷰 public.ops_alarm_days (supabase/live.sql) — 앱·사이트와 같은 공개 키로 읽기만.
결과가 100건 넘게 정해진 날만 그린다(오늘처럼 아직 모이는 날은 뺌). 점선 = 평소 자전거 2.5%(서울 3개월, docs/results.md 연쇄0).
"""
import json, pathlib, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = "https://iqvquwvoljzuvdgtbpnu.supabase.co/rest/v1/ops_alarm_days?select=day,scored,hit&order=day"
KEY = "sb_publishable_YFBKlBvyPFAhBpLdS3o8_A_xIeUmTVE"   # 공개(publishable) 키 — web/cloud.js 와 같음
USUAL, TOP = 2.5, 50.0
LIGHT = dict(line="#dbe3e0", faint="#66727c", muted="#55626c", ink="#17232E", dud="#c2460d")   # spb69683.py 와 같은 색
DARK = dict(line="#24313f", faint="#7f8b96", muted="#a6b1bb", ink="#F5F7F6", dud="#e06b39")


def days():
    req = urllib.request.Request(URL, headers={"apikey": KEY})
    rows = json.load(urllib.request.urlopen(req, timeout=20))
    return [(r["day"], r["scored"], r["hit"]) for r in rows if r["scored"] >= 100]


def svg(D, c):
    W, H, left, right, top, base = 1000, 300, 60, 20, 46, 236
    pct = [100 * k / n for _, n, k in D]
    step = (W - left - right) / len(D)
    bw = step * 0.72
    y = lambda p: base - (base - top) * min(p, TOP) / TOP
    md = lambda d: "/".join(str(int(x)) for x in d.split("-")[1:])
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" font-family="-apple-system, \'Apple SD Gothic Neo\', \'Noto Sans KR\', \'Pretendard\', sans-serif">',
         f'<title>실시간 경보 운영 성적표 — {md(D[0][0])}~{md(D[-1][0])} 날마다 경보 뒤 다음 사람도 바로 반납한 비율 {round(min(pct))}~{round(max(pct))}%, 평소 2.5%</title>']
    for g in (0, 10, 20, 30, 40, 50):   # 눈금
        o += [f'<line x1="{left}" y1="{y(g):.1f}" x2="{W - right}" y2="{y(g):.1f}" stroke="{c["line"]}" stroke-width="1"/>',
              f'<text x="{left - 10}" y="{y(g) + 4:.1f}" text-anchor="end" font-size="13" fill="{c["faint"]}">{g}%</text>']
    for i, ((d, n, k), p) in enumerate(zip(D, pct)):
        x = left + step * i + (step - bw) / 2
        o += [f'<rect x="{x:.1f}" y="{y(p):.1f}" width="{bw:.1f}" height="{base - y(p):.1f}" rx="4" fill="{c["dud"]}"><title>{md(d)} — {n}건 중 {k}건 ({p:.1f}%)</title></rect>',
              f'<text x="{x + bw / 2:.1f}" y="{y(p) - 7:.1f}" text-anchor="middle" font-size="14" font-weight="600" fill="{c["ink"]}">{round(p)}</text>',
              f'<text x="{x + bw / 2:.1f}" y="{base + 22}" text-anchor="middle" font-size="13" fill="{c["faint"]}">{md(d)}</text>']
    o += [f'<line x1="{left}" y1="{y(USUAL):.1f}" x2="{W - right}" y2="{y(USUAL):.1f}" stroke="{c["ink"]}" stroke-width="2" stroke-dasharray="6 5"/>',
          f'<text x="{left}" y="24" font-size="15" font-weight="700" fill="{c["ink"]}">실시간 경보 뒤 다음 사람도 바로 반납 — 날마다</text>',
          f'<text x="{W - right}" y="24" text-anchor="end" font-size="13" fill="{c["muted"]}">점선 = 평소 자전거 2.5% · {len(D)}일 하루도 빠짐없이 평소의 {int(min(pct) // USUAL)}배 이상</text>',
          f'<text x="{left}" y="{H - 10}" font-size="12" fill="{c["faint"]}">클라우드 DB 가 5분마다 스스로 채점 (결과가 100건 넘게 정해진 날, 공개 뷰 ops_alarm_days)</text>',
          "</svg>"]
    return "\n".join(o) + "\n"


def main():
    D = days()
    assert len(D) >= 3, D
    out = ROOT / "docs" / "img"
    (out / "ops-days.svg").write_text(svg(D, LIGHT))
    (out / "ops-days-dark.svg").write_text(svg(D, DARK))
    pct = [100 * k / n for _, n, k in D]
    print(f"{len(D)}일 {D[0][0]}~{D[-1][0]} · {min(pct):.1f}~{max(pct):.1f}% · 합 {sum(k for *_, k in D)}/{sum(n for _, n, _ in D)}")


if __name__ == "__main__":
    main()
