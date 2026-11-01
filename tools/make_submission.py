"""대회 제출 zip 만들기 — 2026 디지털콘텐츠개발대회(생활 부문) 규칙에 맞춰 하나로 묶는다.

    python tools/make_submission.py --id 30000 --name 홍길동          # dist/[생활] 2026디콘_30000_홍길동.zip
    python tools/make_submission.py --id 30000 --name 홍길동 --check  # 만들기 전에 빠진 것만 확인

규칙(PLAN.md '목표 대회'): 모두 하나로 압축, 링크 제출 불가, 파일명 '[참가분야] 2026디콘_팀장학번_이름',
에셋·엔진의 출처와 다운로드 받은 폴더를 함께(미증명 실격), 일부 누락 시 실격.

zip 안:
  1_작품설명서/   작품설명서(학교 양식 — submission/작품설명서.* 에 두면 넣음) + 보고서(docs/report.pdf)
  2_시연영상/     docs/demo/*.mp4
  3_설치파일/     RIDEY.apk(Flutter 이용자 앱 — CI 'flutter' 의 ridey-apk 를 dist/RIDEY.apk 로) + 설치방법.txt
  4_소스/         git 에 있는 파일 전부(원본 대여이력처럼 큰 자료는 빼고, 받는 스크립트 포함)
  5_출처/         라이브러리 원본 꾸러미(받은 그대로) + 라이선스 + 자료·지도 출처 글
  6_발표자료/     docs/slides.pdf (본심용 — 예심 제출에도 넣어 둠)
  읽어보세요.txt
"""
import argparse, pathlib, re, subprocess, sys, urllib.request, zipfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
CACHE = ROOT / "data" / "cache" / "credits"   # 받은 원본 꾸러미 (git 밖)
APKS = (ROOT / "dist/RIDEY.apk", ROOT / "app/build/app/outputs/flutter-apk/app-release.apk")   # CI 에서 받은 것 → 직접 빌드한 것

# 출처 원본 — '다운로드 받은 폴더' 를 그대로 넣으려고 받은 곳에서 다시 받아 둔다
DOWNLOADS = {
    "jsqr-1.4.0/jsqr-1.4.0.tgz": "https://registry.npmjs.org/jsqr/-/jsqr-1.4.0.tgz",
}
TEXTS = {
    "openstreetmap.txt": "지도 바탕 그림: © OpenStreetMap 기여자 (Open Database License, https://www.openstreetmap.org/copyright)\n"
                         "앱이 인터넷으로 타일을 불러와 보여 주며, 지도 오른쪽 아래에 출처를 표시한다. 파일로 넣은 것은 없다.\n",
    "flutter.txt": "앱(app/): Flutter SDK(BSD-3, https://flutter.dev) 하나로 안드로이드·아이폰을 만든다. 상용 엔진 없음.\n"
                   "앱이 쓰는 패키지는 pub.dev 에서 받은 원본을 pub/ 에 그대로 넣었다(버전·sha256 은 4_소스/app/pubspec.lock).\n",
    "공공데이터.txt": "서울 열린데이터광장(https://data.seoul.go.kr): 따릉이 대여이력 OA-15182(실시간 API tbCycleRentData), 고장신고 OA-15644, 대여소 정보 — 공공누리 제1유형(출처 표시)\n"
                     "공공데이터포털(https://www.data.go.kr): 대전 타슈 대여이력, 한국환경공단 전기자동차 충전소 정보 — 공공누리 제1유형\n"
                     "앱 안에는 가공 결과(자전거 번호·대여소·시각)만 있고 이용자 정보(생년·성별)는 없다.\n",
    "클라우드.txt": "Supabase(무료 요금제) — 5분마다 서울 API 로 대여이력을 받아 경보 계산·채점(pg_cron, supabase/live.sql)\n"
                   "GitHub Actions(무료, 공개 저장소) — 백업·전기차 충전기 자료 모으기 (.github/workflows/cloud.yml)\n",
    "직접만든것.txt": "앱 아이콘·시작 화면·색·화면 디자인, 엔진·서버·분석 코드, 자체 모델(analysis/train_model.py 로 학습 → supabase/model.sql)은 모두 직접 만들었다.\n"
                    "분석·학습 도구: Python pandas·NumPy·scikit-learn(BSD, 무료) — 앱에는 들어가지 않는다.\n"
                    "로고·아이콘(RIDEY. 워드마크·R. 아이콘)은 tools/make_brand.py 가 코드로 그림(docs/brand.md). 앱 아이콘·시작 화면 PNG 는 tools/make_flutter_assets.js 가 만듦.\n"
                    "글꼴: Unbounded(SIL OFL 1.1, Google Fonts)에서 숫자·대문자·기호만 잘라 넣음 — site/fonts·app/assets/fonts, 라이선스 OFL-Unbounded.txt 가 같은 폴더에. 한글은 기기 기본 글꼴.\n"
                    "상용 엔진: 사용하지 않음.\n",
}
SKIP_SOURCE = ("docs/demo/", "docs/shots/")   # 큰 파일은 다른 폴더에 이미 들어감


def fetch(rel, url):
    p = CACHE / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(url, timeout=60) as r:
            p.write_bytes(r.read())
    return p


def pub_packages():
    """이용자 앱이 직접 쓰는 pub.dev 패키지 (pubspec.lock 의 direct main · hosted) → [(이름, 버전)]."""
    out, name, dep = [], None, None
    for line in (ROOT / "app/pubspec.lock").read_text().splitlines():
        if m := re.match(r"^  (\w+):$", line):
            name, dep = m[1], None
        elif m := re.match(r'^    dependency: "(.+)"$', line):
            dep = m[1]
        elif (m := re.match(r'^    version: "(.+)"$', line)) and dep == "direct main" and name:
            out.append((name, m[1]))
    return [(n, v) for n, v in out if n != "flutter"]   # flutter 는 SDK


def apk_file():
    return next((p for p in APKS if p.exists()), None)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True, help="팀장 학번")
    ap.add_argument("--name", required=True, help="팀장 이름")
    ap.add_argument("--field", default="생활")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args(argv)
    name = f"[{a.field}] 2026디콘_{a.id}_{a.name}"
    need = {"보고서 PDF": ROOT / "docs/report.pdf", "발표 PDF": ROOT / "docs/slides.pdf", "시연 영상": next(iter(sorted((ROOT / "docs/demo").glob("*.mp4"))), None),
            "APK": apk_file(), "작품설명서(학교 양식)": next(iter(sorted((ROOT / "submission").glob("작품설명서.*"))), None) if (ROOT / "submission").exists() else None}
    missing = [k for k, v in need.items() if not v or not pathlib.Path(v).exists()]
    for k, v in need.items():
        print(f"  {'✓' if k not in missing else '✗'} {k}: {v or '없음'}")
    if a.check:
        return 1 if missing else 0
    if "APK" in missing or "시연 영상" in missing:
        raise SystemExit("APK·시연 영상은 꼭 있어야 한다(없으면 실격). 먼저 만들 것.")

    DIST.mkdir(exist_ok=True)
    out = DIST / f"{name}.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        put = lambda src, arc: z.write(src, f"{name}/{arc}")
        if need["작품설명서(학교 양식)"]:
            put(need["작품설명서(학교 양식)"], f"1_작품설명서/{pathlib.Path(need['작품설명서(학교 양식)']).name}")
        put(need["보고서 PDF"], "1_작품설명서/보고서_RIDEY.pdf")
        put(need["시연 영상"], "2_시연영상/RIDEY_시연.mp4")
        put(need["APK"], "3_설치파일/RIDEY.apk")
        z.writestr(f"{name}/3_설치파일/설치방법.txt",
                   "1. 안드로이드 폰에 RIDEY.apk 를 옮긴다.\n2. 파일을 누르고 '출처를 알 수 없는 앱 설치' 를 허용한다.\n"
                   "3. 설치 뒤 'RIDEY' 를 연다. 인터넷이 있으면 5분마다 바뀌는 서울 실시간 경보가, 없으면 마지막으로 받은 기록이 보인다.\n"
                   "4. QR·번호판 읽기는 카메라, 내 주변 대여소는 위치, 습관 알림은 알림 권한을 물어본다(모두 거절해도 번호 입력으로 쓸 수 있다).\n"
                   "아이폰은 같은 소스(4_소스/app)를 Xcode 로 빌드한다(애플 정책상 설치 파일 배포 불가).\n"
                   "소개 사이트: https://zmflm0110.github.io/ridey/\n")
        for f in subprocess.run(["git", "ls-files"], capture_output=True, text=True, cwd=ROOT, check=True).stdout.splitlines():
            if not f.startswith(SKIP_SOURCE) and (ROOT / f).is_file():
                put(ROOT / f, f"4_소스/{f}")
        for rel, url in DOWNLOADS.items():
            put(fetch(rel, url), f"5_출처/{rel}")
        put(ROOT / "tests/vendor/jsqr/LICENSE", "5_출처/jsqr-1.4.0/LICENSE")
        for n, v in pub_packages():
            put(fetch(f"pub/{n}-{v}.tar.gz", f"https://pub.dev/api/archives/{n}-{v}.tar.gz"), f"5_출처/pub/{n}-{v}.tar.gz")
        for fn, text in TEXTS.items():
            z.writestr(f"{name}/5_출처/{fn}", text)
        put(ROOT / "docs/credits.md", "5_출처/출처_목록.md")
        put(need["발표 PDF"], "6_발표자료/RIDEY_발표.pdf")
        z.writestr(f"{name}/읽어보세요.txt",
                   "RIDEY — 따릉이 고장을 대여기록으로 먼저 찾는 앱 (2026 디지털콘텐츠개발대회 생활 부문)\n\n"
                   "1_작품설명서  작품 설명서·보고서\n2_시연영상  시연 영상\n3_설치파일  안드로이드 APK·설치 방법\n"
                   "4_소스  전체 소스(엔진·서버·Flutter 앱 app/·소개 사이트 site/). 처음 볼 곳: README.md\n5_출처  라이브러리 원본·라이선스, 지도·자료 출처\n6_발표자료  발표 자료\n\n"
                   "1분 둘러보기 (APK 설치 뒤)\n"
                   "1. 첫 실행에서 일반 시민 또는 관리 직원을 고른다.\n"
                   "2. 시민 — 번호를 넣거나 QR·번호판을 찍으면 고장 의심 여부와 연쇄를 본다. 홈에는 주변 대여소별 의심 대수.\n"
                   "3. 직원 — 담당 구의 고장 의심 대수와 대여소별 목록만 읽는다. 현장 판정·사진 업로드는 없다.\n")
    print(f"→ {out} ({out.stat().st_size / 1e6:.1f}MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
