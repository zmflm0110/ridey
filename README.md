<h1 align="center"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/brand/wordmark-dark.svg">
  <img src="docs/brand/wordmark.svg" alt="RIDEY." width="320">
</picture></h1>

<p align="center"><b>타기 전에, 고장 난 따릉이를 먼저.</b></p>

<p align="center">
  <a href="https://zmflm0110.github.io/ridey/"><img alt="웹사이트" src="https://img.shields.io/badge/웹사이트-zmflm0110.github.io-111317"></a>
  <a href="https://github.com/zmflm0110/ridey/actions/workflows/test.yml"><img alt="검사" src="https://github.com/zmflm0110/ridey/actions/workflows/test.yml/badge.svg"></a>
  <a href="https://github.com/zmflm0110/ridey/actions/workflows/flutter.yml"><img alt="앱" src="https://github.com/zmflm0110/ridey/actions/workflows/flutter.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="라이선스 MIT" src="https://img.shields.io/badge/라이선스-MIT-555"></a>
</p>

<p align="center">
  <a href="https://zmflm0110.github.io/ridey/">웹사이트</a> ·
  <a href="docs/report.pdf">보고서</a> ·
  <a href="docs/slides.pdf">발표</a> ·
  <a href="docs/demo/demo.mp4">시연 영상</a> ·
  <a href="CHANGELOG.md">진행 기록</a>
</p>

<p align="center">
  <a href="https://zmflm0110.github.io/ridey/"><img src="docs/img/site.png" alt="RIDEY 웹사이트 첫 화면. 지금 경보가 켜진 대여소가 서울 지도 위에 점으로 보인다" width="820"></a>
</p>

따릉이가 고장 나도 신고하는 사람은 드뭅니다. 대신 빌렸다가 이상하면 그 자리에서 바로 반납합니다. 이런 반납이 서로 다른 사람에게서 연달아 나오면, 그 자전거는 고장일 가능성이 높습니다.

RIDEY는 서울시가 공개하는 대여 기록에서 이런 자전거를 찾습니다. 고장 신고보다 보통 하루 먼저 알려 줍니다.

## 점 하나가 신호다

제대로 탄 대여는 선, 빌리자마자 반납한 대여는 점입니다. 서로 다른 두 사람의 점이 이어지면 RIDEY가 경보를 켭니다. 누가 제대로 타고 가면 꺼집니다.

| 말 | 뜻 |
|---|---|
| 헛대여(점) | 같은 대여소에 3분 안에, 300m도 안 가고 반납한 대여입니다. 타 보려다 포기한 흔적으로 봅니다. |
| 서로 다른 사람 | 한 사람이 여러 번 해 본 건 한 번으로 셉니다. |
| 경보 | 서로 다른 사람의 점이 2명 이어지면 켜집니다. 3명부터는 강한 경보입니다. |
| 꺼짐 | 누군가 제대로 타고 가면 꺼집니다. |

기준은 2026년 1월 기록만 보고 정했습니다. 3월, 6월, 대전 타슈 기록에는 손대지 않고 그대로 썼습니다. 기준을 18가지로 바꿔 서울 세 달과 대전 두 달에 모두 돌려 봤더니, 1월에 고른 기준이 처음 보는 달과 도시에서도 51.8\~60.2% 맞았습니다([phase1](docs/phase1.md)). [사이트의 기준 탐색기](https://zmflm0110.github.io/ridey/#proof)에서 직접 바꿔 볼 수 있습니다.

## 자전거 한 대의 12일

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/spb69683-dark.svg">
  <img src="docs/img/spb69683.svg" alt="SPB-69683의 12일을 하루에 한 줄씩 그린 그림. 6월 12일 15시 43분 두 번째 사람에서 경보, 다음 날 첫 고장 신고, 그 뒤에도 바로 반납이 이어지다 24일 두 번째 신고 뒤 사라짐" width="900">
</picture>

서울 강서구의 실제 자전거 SPB-69683입니다. 2026년 6월의 대여 기록과 고장 신고를 그대로 그렸습니다([`analysis/spb69683.py`](analysis/spb69683.py)).

- 6월 12일 15:20, 첫 사람이 빌리자마자 같은 자리에 반납했습니다. 15:43, 두 번째 사람도 그랬습니다. RIDEY는 여기서 경보를 켭니다.
- 첫 고장 신고는 다음 날 아침 07:58에 들어왔습니다. 그 뒤로도 54번 더 빌려졌다가 바로 돌아왔습니다.
- 6월 16일 출근길에는 37분 사이 7명이 연달아 헛걸음했습니다.
- 6월 24일 두 번째 신고가 들어오고서야 사라졌습니다. 그동안 돌아선 사람은 서로 다른 73명입니다.

## 왜 아무도 몰랐을까

**신고는 귀찮습니다.** 여러 사람이 연달아 포기한 자전거의 49\~61%는 일주일이 지나도 신고가 없었습니다([보고서 5-3](docs/report.md)).

**눈으로는 안 보입니다.** 공단 직원은 고장을 찾으러 따로 돌지 않습니다. 자전거가 몰린 곳에서 모자란 곳으로 옮기는 재배치를 하다가, 눈에 띄는 고장만 거둡니다. 그래서 경보가 켜진 자전거의 82\~91%가 하루 안에 또 빌려졌습니다. 체인이나 브레이크처럼 타 봐야 아는 고장이 많아서입니다([공단 운영 조사](docs/operations.md), [`after_alarm.py`](analysis/after_alarm.py)).

**작은 문제가 아닙니다.** 2024년 따릉이 고장 접수는 16만 건, 운영 적자는 127억 원이었습니다([헤럴드경제](https://biz.heraldcorp.com/article/10878875)).

## 결과

<p align="center"><img src="docs/fig_chain.png" alt="앞서 포기한 인원에 따라 다음 사람도 포기한 비율. 서울 세 달과 대전 두 달" width="600"></p>

| 무엇을 봤나 | 결과 | 근거 |
|---|---|---|
| 서로 다른 두 사람이 포기한 뒤, 다음 사람 | 35\~44%가 또 바로 반납. 평소 자전거는 2.5% | [results](docs/results.md) |
| 고장 신고보다 얼마나 먼저 | 중앙값 20\~25시간. 그사이 한 대에서 평균 4명이 헛걸음 | [보고서 5-3](docs/report.md) |
| 막을 수 있던 헛걸음 | 서울 하루 90\~243명, 대전 하루 114\~132명 | [보고서 5-2](docs/report.md) |
| 검증한 기록 | 서울 3개월, 대전 2개월. 약 1천만 건 | [results](docs/results.md) |
| 정비 동선 | 근무 시간 안에 많이 막는 순서로 돌면 순위대로 돌 때보다 12\~17% 더 막음 | [route_backtest](docs/route_backtest.md) |

## 지금도 5분마다

서울 대여이력 API는 반납이 끝나면 바로 기록을 줍니다. 2026년 9월 27일부터 클라우드 DB(Supabase)가 5분마다 이 기록을 받아 직접 계산합니다. 켜 둔 서버나 컴퓨터는 없습니다. 앱은 그 결과를 읽기만 합니다.

10월 8일까지 실제로 돌린 결과입니다. 경보가 켜진 뒤 처음 빌린 다른 사람 3,478명 중 1,035명(29.8%)이 또 바로 반납했습니다. 지난 기록으로 잰 32\~34%와 비슷하고, 11일 동안 하루도 빠짐없이 24\~39%였습니다. 5분 작업은 하루 288번 모두 성공했습니다. 최신 숫자는 [웹사이트](https://zmflm0110.github.io/ridey/#live)에 있습니다.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/ops-days-dark.svg">
  <img src="docs/img/ops-days.svg" alt="9월 27일부터 10월 7일까지 날마다, 실시간 경보 뒤 다음 사람도 바로 반납한 비율. 24~39%로 평소 2.5%의 9배 이상 (analysis/ops_days.py)" width="900">
</picture>

<p align="center"><img src="docs/img/architecture.svg" alt="RIDEY 구조. 서울 API를 클라우드 DB가 5분마다 받아 SQL과 자체 모델로 계산하고, 앱이 읽고, 결과로 모델이 다시 배운다" width="900"></p>

## 자체 모델은 이길 때만

규칙만으로도 쓸 만합니다. 그래서 모델은 규칙과 같은 조건에서 겨뤄 이긴 곳에만 넣었습니다([model](docs/model.md)).

- 자전거마다 '다음 사람도 바로 반납할 확률'을 냅니다. 나무 60그루짜리 모델을 SQL로 옮겨 DB 안에서 5분마다 계산합니다.
- 확률 순으로 보여 주니 목록 위 20대 중 진짜 고장이 세 달 모두 2.4\~4.5%p 늘었습니다.
- 왜 그렇게 봤는지도 함께 보여 줍니다. 예를 들면 '서로 다른 12명이 연달아 반납 +36%p'입니다.
- '이 중 적어도 몇 대는 진짜 고장'이라는 하한을 90%로 보장합니다. 시험한 달에서는 98\~100% 맞았습니다.
- 3시간마다 새 정답으로 다시 배웁니다. 다만 미리 정한 기준(2%)보다 크게 나아질 때만 바꿉니다. 지금은 1.7%라 그대로 둡니다([model_live](docs/model_live.md)).
- 서울로만 배운 모델을 대전에 그대로 써도 위 10대 기준 4.5%p 나아졌습니다([model_daejeon](docs/model_daejeon.md)).

## 앱

앱은 하나입니다. 같은 폰을 시민과 직원이 번갈아 쓸 수 있어서, 켤 때마다 누가 쓰는지 묻습니다.

**시민: 타기 전에 확인합니다.**

- 홈 지도에 서울 전체의 고장 의심 따릉이가 뜹니다. 처음엔 내 근처를 크게 보여 줍니다.
- 학원이나 역 이름을 검색하면, 지금 있는 곳이 아니라 갈 곳의 대여소를 미리 볼 수 있습니다.
- 자전거 번호를 넣거나 번호표 QR을 찍으면 경보, 확률, 이유를 보여 줍니다.
- 타 보니 고장이면 '고장 신고하기'로 서울시 공식 신고 화면을 바로 엽니다. RIDEY가 신고를 따로 받지는 않습니다.
- 자주 쓰는 대여소를 넣어 두면 그곳부터 봅니다.

**직원: 재배치하는 길에 고장 의심도 거둡니다.**

- '오늘 추천 경로'는 넘친 대여소에서 싣고, 빈 대여소에 내려놓으면서, 고장 의심도 함께 거두는 순서입니다. 트럭 한 대 20대 기준입니다.
- '고장 의심만'으로 바꾸면 가장 짧은 순서로 다시 짭니다.
- 경로는 실제 도로를 따라 그립니다. 앱 안에서 다음 갈림길, 남은 거리, 그곳에서 할 일을 안내합니다.
- 구별 현황에서 구를 누르면 그 구의 대여소별 목록이 나옵니다.

공단 직원이 고장을 찾아 따로 돌지 않는다는 건 [전화로 확인했습니다](docs/operations.md). 직원 모드는 그 재배치 길에 얹는 목록입니다. 직원이 실제로 쓸지는 아직 확인하지 못했습니다.

앱은 계산하지 않고 클라우드가 낸 결과만 읽습니다. 공개 키로 읽기만 하니 로그인이 없고, 누구나 볼 수 있는 자료만 보입니다.

<table>
  <tr>
    <td align="center"><img src="docs/shots/app/onboarding.png" alt="켤 때" width="200"><br>켤 때<br><sub>점 하나가 서울로 퍼집니다</sub></td>
    <td align="center"><img src="docs/shots/app/home.png" alt="시민 홈" width="200"><br>홈<br><sub>서울 전체, 내 근처부터</sub></td>
    <td align="center"><img src="docs/shots/app/check.png" alt="자전거 확인" width="200"><br>자전거 확인<br><sub>몇 명이 이어졌는지, 확률</sub></td>
    <td align="center"><img src="docs/shots/app/evidence.png" alt="판단 근거" width="200"><br>판단 근거<br><sub>왜 경보가 켜졌는지</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/shots/app/stations.png" alt="내 대여소" width="200"><br>내 대여소<br><sub>지도에서 보고 넣기</sub></td>
    <td align="center"><img src="docs/shots/app/staff_route.png" alt="오늘 추천 경로" width="200"><br>오늘 추천 경로(직원)<br><sub>재배치와 수거를 한 길로</sub></td>
    <td align="center"><img src="docs/shots/app/staff_nav.png" alt="길안내" width="200"><br>길안내(직원)<br><sub>다음 갈림길과 할 일</sub></td>
    <td align="center"><img src="docs/shots/app/staff_list.png" alt="구별 현황" width="200"><br>구별 현황(직원)<br><sub>구마다 강한 경보 대수</sub></td>
  </tr>
</table>

사진은 2026년 11월 5일 아이폰에서 실제 자료로 찍었습니다. '내 위치'는 반포종합운동장 입구로 고정했습니다.

## 디자인

선과 점이 전부입니다. 제대로 탄 기록은 선, 빌리자마자 반납한 기록은 점으로 그립니다. 로고 `RIDEY.`의 마침표가 바로 그 점입니다.

바탕은 잉크색과 종이색입니다. 주황은 경보에만 씁니다. 내 위치와 들를 곳 번호는 파랑입니다. 초록 대신 파랑을 고른 건, 색각 이상이 있으면 주황과 초록이 거의 같아 보여서입니다.

앱을 켜면 폰 시작 화면의 `R.`을 그 자리에서 이어받습니다. R은 사라지고, 마침표만 튀어 올랐다가 떨어져 서울 대여소로 퍼집니다. 사이트, 앱, 발표가 같은 규칙을 씁니다([docs/brand.md](docs/brand.md)).

<p align="center"><img src="docs/brand/board.png" alt="RIDEY 브랜드 보드. 로고, 앱 아이콘, 색, 글꼴, 선과 점" width="860"></p>

## 다른 곳에서도

대전 타슈에 서울 기준을 그대로 썼습니다. 두 명이 포기한 뒤 다음 사람도 41.6\~43.6%가 포기했습니다. 평소는 2.9%입니다. 대여 기록이 공개된 곳이면 같은 구조로 쓸 수 있습니다.

## 만든 방법

| 부분 | 쓴 것 |
|---|---|
| 엔진 | 파이썬(`engine/`). 같은 규칙을 SQL로도 짜서, 둘이 같은 답을 내는지 자동으로 검사합니다. |
| 클라우드 | Supabase. 5분마다 서울 API를 받아 SQL로 연쇄와 확률을 계산합니다. 키는 DB 금고(Vault)와 맥 키체인에만 둡니다. |
| 앱 | Flutter 하나로 안드로이드와 아이폰. 지도는 OpenStreetMap입니다. |
| 검사 | 파이썬 40개, Flutter 100개, 사이트와 QR 검사. 올릴 때마다 GitHub Actions가 돌리고 APK도 만듭니다. |

무료 DB가 10월 2일 밤 6시간 멈춘 적이 있습니다. 5분 작업 한 번이 145MB를 건드려 캐시가 밀려난 탓이었습니다. 경보가 될 수 없는 자전거를 먼저 거르고 색인으로 바로 읽게 고쳐, 한 번에 40MB, 16\~20초로 줄였습니다. 고치기 전과 후가 같은 답을 내는지는 6월 기록으로 36시간 동안 73번 비교했습니다([`tools/live_sql_compare.py`](tools/live_sql_compare.py)).

## 못 하는 것

- **고장의 정답 자료가 없습니다.** 신고는 늦고 드물어서, 다음 사람도 바로 반납했는지를 정답 대신 씁니다. 현장에서 직접 확인하는 조사를 준비해 두었습니다([절차](docs/field_protocol.md)).
- **아무도 빌리지 않은 고장은 못 찾습니다.** 흔적이 있어야 찾습니다.
- **고장 종류는 못 맞힙니다.** 한 대씩 맞혀 보면 10\~14%뿐이라, 종류는 현장에서 봐야 합니다.
- **번호표 QR은 직접 풀었습니다.** QR에는 `SPB-00072627` 같은 번호가 글자판을 섞은 base64로 들어 있습니다. 공개된 문서가 없어 실제 번호표 16장으로 규칙을 찾았고, 16장 모두 맞았습니다. 다른 모양의 번호표가 나오면 번호를 직접 넣으면 됩니다.
- **길안내와 지명 검색은 무료 공개 서버를 씁니다.** 도로 경로는 OSRM, 지명은 OpenStreetMap Nominatim입니다. 경로를 새로 짤 때와 검색할 때만 부릅니다.

## 직접 돌려 보기

인증키 없이 공개 자료만으로 모든 표를 다시 만들 수 있습니다.

```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python data/download.py          # 원본 자료 (약 1.7GB)
.venv/bin/python analysis/report.py        # 주요 표 (docs/results.md)
.venv/bin/python server/app.py             # 소개 사이트 (http://localhost:8765)
.venv/bin/python -m pytest -q tests        # 파이썬 테스트
```

<details>
<summary>클라우드 실시간 켜기 (Supabase, 서울 열린데이터광장 인증키)</summary>

키는 코드나 git에 넣지 않습니다. 맥에서는 키체인에, 클라우드에서는 Supabase Vault에 둡니다. `-w`로 끝내면 화면에 보이지 않게 묻습니다.

```sh
security add-generic-password -a bike-doctor -s seoul-openapi -w      # 서울 열린데이터광장
security add-generic-password -a bike-doctor -s datagokr -w           # 공공데이터포털 (아침 목록을 --source api 로 돌릴 때만)
security add-generic-password -a bike-doctor -s supabase-db -w        # Supabase DB 비밀번호
```

1. Supabase 프로젝트에 `supabase/schema.sql`, `staff.sql`, `model.sql`, `live.sql`, `calib.sql`을 이 순서로 적용합니다. psql로 DB 비밀번호를 써서 직접 넣습니다. 이 맥처럼 5432 포트가 막힌 곳에서는 6543 포트를 씁니다.
2. Vault에 `seoul_openapi`를 넣고, 처음 한 번 `tools/supabase_live_load.py --stations --backfill 8`로 채웁니다.
3. 공개(publishable) 키를 `app/lib/config/ridey_config.dart`에 넣습니다.

잘 도는지는 `select at, ms from live.tick_log order by at desc limit 5`로 봅니다. 파이썬과 같은 답인지는 `tools/supabase_live_load.py --parity`, `--parity-model`로 봅니다. 모델 다시 배우기는 `tools/retrain.py`입니다(`--deploy`는 나아졌을 때만 바꿉니다).
</details>

<details>
<summary>안드로이드, 아이폰</summary>

- 안드로이드 APK는 GitHub Actions의 `flutter` 실행 화면에서 `ridey-apk`로 받습니다. 테스트를 통과해야 만들어집니다. 직접 만들려면 `cd app && flutter build apk --release`입니다.
- 아이폰은 `cd app && flutter build ios`, 또는 Xcode에서 `app/ios/Runner.xcworkspace`를 열고 Team을 고른 뒤 실행합니다.
- 앱 아이콘은 `node tools/make_flutter_assets.js`로 다시 만듭니다. 폰 시작 화면의 `R.`과 첫 장면이 이어지는 부분은 `app/lib/app/launch_mark.dart`에 있습니다.
- 시연 영상은 앱이 폰에서 스스로 움직이게 해서(`app/integration_test/demo_test.dart`) 맥에서 케이블로 녹화했습니다(`tools/iphone_rec.swift`).
- 같은 Actions 실행의 `ridey-screens`에는 주요 화면을 밝은 화면과 어두운 화면으로 찍은 사진이 있습니다. Flutter가 없는 컴퓨터에서도 디자인을 볼 수 있습니다.
</details>

<details>
<summary>검사와 제출물 다시 만들기</summary>

```sh
npm i playwright marked
node tests/web/qr.test.js && node tests/web/site.test.js                         # 사이트·QR 검사
node docs/build_pdf.js                                                           # 보고서·제안서·발표 PDF
.venv/bin/python tools/build_site.py                                             # 웹사이트
(cd app && flutter test)                                                         # 앱
python tools/live_sql_compare.py --old <커밋>                                     # 클라우드 SQL을 고칠 때 전후 비교 (로컬 Postgres)
```

브라우저가 없으면 `CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"`을 앞에 붙입니다. 대회 제출 zip은 `python tools/make_submission.py --id <학번> --name <이름>`으로 만들고, APK는 Actions에서 받아 `dist/RIDEY.apk`로 둡니다.
</details>

## 폴더

| 폴더 | 들어 있는 것 |
|---|---|
| [`engine/`](engine) | 헛대여, 연쇄, 경보 규칙(`core.py`), 아침 목록(`morning.py`) |
| [`supabase/`](supabase) | 5분 작업(`live.sql`), 모델 식(`model.sql`), 쓰기 표(`schema.sql`), 직원 명단(`staff.sql`) |
| [`app/`](app/README.md) | Flutter 앱(시민, 직원) |
| [`analysis/`](analysis) | 검증 스크립트. 기준 고르기, 실시간 대조, 모델 학습과 비교, 그림 |
| [`site/`](site) | 소개 웹사이트(GitHub Pages) |
| [`docs/`](docs/README.md) | 보고서, 발표, 대본, 결과 표, 조사 자료 |
| [`tools/`](tools) | 클라우드 적재와 대조, 다시 배우기, 제출물 만들기 |
| [`tests/`](tests) | 파이썬, 사이트, QR 검사(앱 검사는 `app/` 안) |

측정 과정과 실패한 시도는 [`PLAN.md`](PLAN.md)에, 바뀐 점은 [`CHANGELOG.md`](CHANGELOG.md)에 적어 두었습니다.

## 자료와 참고

- **자료:** 서울 열린데이터광장의 따릉이 대여이력([OA-15182](https://data.seoul.go.kr/dataList/OA-15182/F/1/datasetView.do), 실시간 API `tbCycleRentData`), 고장신고([OA-15644](https://data.seoul.go.kr/dataList/OA-15644/F/1/datasetView.do)), 대여소 정보. 공공데이터포털의 대전 타슈 대여이력. 모두 공공누리 제1유형입니다. 앱과 공개 화면에는 이용자 정보가 없고, 클라우드는 대여 기록을 8일만 둡니다.
- **참고 연구:** Kaspi, Raviv, Tzur, [Detection of Unusable Bicycles in Bike-Sharing Systems](https://www.researchgate.net/publication/290496984_Detection_of_Unusable_Bicycles_in_Bike-Sharing_Systems) (Omega, 2016). [Self-Supervised Transformer for Unusable Shared Bike Detection](https://arxiv.org/pdf/2505.00932) (2025). 비교는 [related_work](docs/related_work.md)에 있습니다.
- **라이브러리:** 앱은 Flutter와 pub.dev 패키지, 지도는 [flutter_map](https://pub.dev/packages/flutter_map)과 [OpenStreetMap](https://www.openstreetmap.org/copyright)(ODbL)입니다. QR 검사에 쓴 [jsQR](https://github.com/cozmo/jsQR) 1.4.0(Apache-2.0)은 라이선스와 함께 `tests/vendor/`에 넣었습니다. 글꼴은 Unbounded(OFL)에서 숫자와 대문자만 잘라 썼습니다. 전체 목록은 [docs/credits.md](docs/credits.md)에 있습니다.
- **라이선스:** 코드는 [MIT](LICENSE). 자료는 각 출처의 공공누리 제1유형(출처 표시)을 따릅니다.
