<h1 align="center"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/brand/wordmark-dark.svg">
  <img src="docs/brand/wordmark.svg" alt="RIDEY." width="320">
</picture></h1>

<p align="center">타기 전에, 고장 난 따릉이를 먼저 알려 주는 앱</p>

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

따릉이가 고장 나도 신고하는 사람은 많지 않다. 대신 빌렸다가 이상하다 싶으면 그 자리에서 바로 반납한다. 이런 반납이 서로 다른 사람에게서 연달아 나오는 자전거는 고장일 가능성이 높다. RIDEY는 서울시가 공개하는 대여 기록에서 이런 자전거를 찾아, 보통 고장 신고보다 하루쯤 먼저 알려 준다.

## 자전거 한 대의 12일

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/spb69683-dark.svg">
  <img src="docs/img/spb69683.svg" alt="SPB-69683의 12일을 하루에 한 줄씩 그린 그림. 6월 12일 15시 43분 두 번째 사람에서 경보, 다음 날 첫 고장 신고, 그 뒤에도 바로 반납이 이어지다 24일 두 번째 신고 뒤 사라짐" width="900">
</picture>

서울 강서구의 실제 자전거 SPB-69683이다. 2026년 6월 대여 기록과 고장 신고를 그대로 그렸다([`analysis/spb69683.py`](analysis/spb69683.py)).

- 6월 12일 15:20에 첫 사람이 빌리자마자 같은 대여소에 반납했고, 15:43에 두 번째 사람도 그랬다. RIDEY라면 여기서 경보를 켠다.
- 첫 고장 신고는 다음 날 07:58에 들어왔다. 그런데도 그 뒤로 54번 더 빌려졌다가 바로 반납됐다.
- 6월 16일 출근길(07:13\~07:50)에는 37분 동안 7명이 연달아 헛걸음했다.
- 6월 24일 두 번째 신고가 들어온 뒤에야 사라졌다. 그동안 돌아선 사람이 서로 다른 73명이다.

## 왜 지금은 못 찾나

- 신고를 잘 안 한다. 여러 사람이 연달아 포기한 자전거의 49\~61%는 7일이 지나도 신고가 없었다([보고서 5-3](docs/report.md)).
- 눈으로 봐서는 모른다. 공단 직원은 고장을 찾으러 따로 순찰하지 않는다. 자전거가 한쪽에 몰린 곳에서 거두어 모자란 곳에 놓는 재배치를 하다가 눈에 띄는 고장을 발견하면 센터로 가져가고, 이렇게 신고 없이 찾는 수거가 전체의 절반쯤이다. 그래도 경보가 켜진 자전거의 82\~91%는 하루 안에 또 빌려졌다. 체인이나 브레이크처럼 타 봐야 아는 고장이 많기 때문이다([공단 운영 조사와 전화 확인](docs/operations.md), [`after_alarm.py`](analysis/after_alarm.py)).
- 규모도 작지 않다. 2024년 고장 접수가 16만 건이었고 운영 적자는 127억 원이었다([헤럴드경제](https://biz.heraldcorp.com/article/10878875)).

## 규칙

| 말 | 뜻 |
|---|---|
| 헛대여 | 같은 대여소에 3분 안에, 300m도 안 가고 반납한 것. 타 보려다 포기한 흔적으로 본다 |
| 서로 다른 사람 | 한 사람이 여러 번 한 건 한 번으로 센다(생년·성별, 없으면 '반납 2분 안 재대여'로 구분) |
| 경보 | 서로 다른 사람의 헛대여가 2명 이어지면 경보, 3명 이상이면 강한 경보 |
| 끝 | 누군가 정상으로 타고 가면 풀린다 |

기준은 2026년 1월 기록만 보고 정했고, 3월·6월과 대전 타슈 기록에는 손대지 않고 그대로 적용했다([phase1](docs/phase1.md)). 시간·거리·인원을 바꾼 기준 18가지를 서울 세 달, 대전 두 달 기록에 모두 돌려 봤는데, 1월에 고른 기준이 처음 보는 달과 도시에서도 51.8\~60.2%였다. [사이트의 기준 탐색기](https://zmflm0110.github.io/ridey/#proof)에서 직접 바꿔 볼 수 있다(`analysis/rule_grid.py`).

## 결과

<p align="center"><img src="docs/fig_chain.png" alt="앞서 포기한 인원에 따라 다음 사람도 포기한 비율. 서울 세 달과 대전 두 달" width="600"></p>

| 무엇 | 결과 | 근거 |
|---|---|---|
| 서로 다른 두 사람이 포기한 뒤 다음 사람 | 35\~44%가 또 바로 반납(평소 자전거는 2.5%) | [results](docs/results.md) |
| 신고보다 얼마나 빠른가 | 경보에서 고장 신고까지 중앙값 20\~25시간, 그사이 한 대에서 평균 4명이 헛걸음 | [보고서 5-3](docs/report.md) |
| 막을 수 있던 헛걸음 | 서울 하루 90\~243명, 대전 하루 114\~132명 | [보고서 5-2](docs/report.md) |
| 검증한 기록 | 서울 3개월과 대전 2개월, 약 1천만 건 | [results](docs/results.md) |
| 정비 동선 | 근무 시간 안에 많이 막는 순서로 돌면 순위대로 돌 때보다 12\~17% 더 막음 | [route_backtest](docs/route_backtest.md) |

## 실시간으로 돌아가는 방식

서울 대여이력 API는 반납이 끝나면 바로 그 기록을 준다. 그래서 2026년 9월 27일부터는 클라우드 DB(Supabase)가 5분마다 직접 기록을 받아 계산하고, 앱은 그 결과를 읽기만 한다. 따로 켜 둔 서버나 컴퓨터는 없다.

10월 8일까지 실제로 돌려 본 결과, 경보가 켜진 뒤 처음 빌린 다른 사람 3,478명 중 1,035명(29.8%)이 또 바로 반납했다. 지난 기록으로 잰 32\~34%와 비슷하고, 11일 동안 날마다 24\~39% 사이였다. 5분 작업은 하루 288번 모두 성공했고 한 번에 평균 19초 걸렸다. 최신 숫자는 [웹사이트](https://zmflm0110.github.io/ridey/#live)에서 볼 수 있다.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/ops-days-dark.svg">
  <img src="docs/img/ops-days.svg" alt="9월 27일부터 10월 7일까지 날마다, 실시간 경보 뒤 다음 사람도 바로 반납한 비율. 24~39%로 평소 2.5%의 9배 이상 (analysis/ops_days.py)" width="900">
</picture>

<p align="center"><img src="docs/img/architecture.svg" alt="RIDEY 구조. 서울 API를 클라우드 DB가 5분마다 받아 SQL과 자체 모델로 계산하고, 앱이 읽고, 결과로 모델이 다시 배운다" width="900"></p>

## 자체 모델은 규칙보다 나을 때만

규칙만으로도 쓸 만하다. 그래서 모델은 규칙과 같은 조건에서 비교해 더 나은 곳에만 넣었다([model](docs/model.md)).

- 목록의 자전거마다 '다음 사람도 바로 반납할 확률'을 낸다. 나무 60그루짜리 모델(특징 7개: 연쇄, 지난 7일, 경과 시간 등)을 SQL 식으로 바꿔 DB 안에서 5분마다 계산한다.
- 확률 순으로 보여 주면 위 20대 중 진짜 고장이 세 달 모두 2.4\~4.5%p 늘었다.
- '이 중 최소 몇 대는 진짜 고장'을 90%로 보장하는 하한(분할 컨포멀)도 낸다. 시험한 달에서는 98\~100% 맞았다.
- 왜 그렇게 봤는지도 같이 보여 준다. 예: '서로 다른 12명이 연달아 반납 +36%p'.
- 3시간마다 표본을 모으고 다음 사람의 결과를 정답으로 써서 다시 배운다. 실시간 3,215개로 점검해 보니 목록 단위 예측 34.3%, 실제 34.7%였다. 경보 순간만 보면 35%와 29%로, 연쇄 2명을 조금 높게 본다. 이를 고치는 보정 층도 매번 같은 기준으로 시험하는데, 지금은 개선이 1.7%로 기준(2%)에 못 미쳐 아직 바꾸지 않았다([model_live](docs/model_live.md)).
- 서울로만 배운 모델을 대전에 그대로 써도 위 10대 기준 4.5%p 나아졌다([model_daejeon](docs/model_daejeon.md)).

## 화면

화면은 Flutter 앱(`app/`) 하나다. 같은 폰을 시민과 직원이 번갈아 쓸 수 있어서 켤 때마다 시민 모드와 직원 모드를 묻고, 지난번 고른 것을 함께 보여 준다. 처음 시민을 고르면 위치를 무엇에 쓰는지 먼저 알려 준 뒤에 위치 권한을 묻는다.

| 모드 | 탭 | 하는 일 |
|---|---|---|
| 시민 | 홈, 자전거 확인, 더보기 | 홈 지도(OpenStreetMap, 키 없이 차분한 색으로)에 서울 전체의 고장 의심 자전거가 나오고, 처음엔 내 근처 500m를 크게 보여 준다. 목록은 가까운 순. 지도 위 검색 칸에서 구·대여소·지명(학원·역)을 찾으면 그곳 기준으로 다시 보여 준다(지금 있는 곳이 아니라 갈 곳을 미리 보기). '주변 대여소 현황'은 대여소마다 탈 만한 자전거 수, 대여소를 누르면 카드(걸어서 약 몇 분, 길 찾기는 네이버 지도, 대여하기는 공식 앱). 자전거 확인은 번호('SPB-' 는 미리 적힘)·번호표 QR(QR 안의 섞인 글자를 풀어 번호를 바로 읽는다), 경보·확률·이유와 '고장 신고하기'(서울시 공식 따릉이 신고 화면으로 이어 준다. 신고는 그 화면에서 마치고, RIDEY 는 받지 않는다). 내 대여소는 지도 + 목록/검색 시트, 누르면 자리를 보여 주고 '넣기' 로만 저장 |
| 직원 | 구별 현황, 더보기 | '오늘 추천 경로': 지금 위치에서 출발해, 넘친 대여소(거치대의 1.2배 넘음)에서 자전거를 싣고 빈 대여소(25% 아래)에 내려놓으면서 고장 의심 자전거도 함께 거두는 순서(차 한 대 20대 기준, 강한 경보는 더 무겁게). '고장 의심만' 으로 바꾸면 가장 짧은 순서(가까운 이웃 + 2-opt). 경로는 실제 도로를 따라 그리고(OSRM, OpenStreetMap 도로 자료), '길안내 시작' 은 앱 안 길안내(내 위치를 따라가며 다음 갈림길·남은 거리·그곳에서 할 일). 어제 아침 목록 성적(DB 채점), 구별 현황(누르면 그 구의 대여소별 목록), 실시간·07:00 아침 목록 고르기 |

두 모드가 답하는 질문이 다르다. 시민은 '지금 내 앞의 이 자전거를 타도 되나', 직원은 '재배치하러 가는 대여소에 먼저 가져갈 자전거가 있나'다. 공단 직원은 고장을 찾아 순찰하지 않고 재배치하다 눈에 띄는 고장만 거둔다는 것을 [전화로 확인했고](docs/operations.md), 직원 모드는 그 길에 얹는 목록이다. 직원이 실제로 쓸지는 아직 확인하지 못했다.

앱은 계산하지 않고 클라우드가 낸 결과만 읽는다. 읽는 뷰는 `live_snapshot`, `live_station_status`(대여소별 거치 대수), `ops_lists`, `ops_scores`, `ops_alarm_days` 다섯 개이고 공개(publishable) 키로 읽기만 한다. 그래서 직원 모드에도 로그인이 없고, 보이는 것은 누구나 읽을 수 있는 자료뿐이다.

<table>
  <tr>
    <td align="center"><img src="docs/shots/app/onboarding.png" alt="첫 실행" width="200"><br>켤 때<br><sub>점 하나가 서울로 퍼지고 지금 고장 의심 수가 켜진다</sub></td>
    <td align="center"><img src="docs/shots/app/home.png" alt="시민 홈" width="200"><br>홈(시민)<br><sub>서울 전체 고장 의심, 내 근처부터</sub></td>
    <td align="center"><img src="docs/shots/app/check.png" alt="자전거 확인" width="200"><br>자전거 확인(시민)<br><sub>연쇄, 마지막 헛대여, 확률</sub></td>
    <td align="center"><img src="docs/shots/app/evidence.png" alt="판단 근거" width="200"><br>판단 근거(시민)<br><sub>왜 경보가 켜졌는지, 확률을 올리고 내린 이유</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/shots/app/stations.png" alt="내 대여소" width="200"><br>내 대여소(시민)<br><sub>지도에서 자리를 보고 넣기</sub></td>
    <td align="center"><img src="docs/shots/app/staff_route.png" alt="오늘 추천 경로" width="200"><br>오늘 추천 경로(직원)<br><sub>재배치와 고장 의심 수거를 한 길로</sub></td>
    <td align="center"><img src="docs/shots/app/staff_nav.png" alt="길안내" width="200"><br>길안내(직원)<br><sub>실제 도로를 따라 다음 갈림길과 할 일</sub></td>
    <td align="center"><img src="docs/shots/app/staff_list.png" alt="구별 현황" width="200"><br>구별 현황(직원)<br><sub>구마다 강한 경보 대수와 내일 헛대여 예상</sub></td>
  </tr>
</table>

사진은 2026년 11월 5일 아이폰에서 실제 자료로 찍은 시연 녹화에서 잘랐다('내 위치'는 반포종합운동장 입구로 고정). 표본 자료로 그린 화면 사진은 올릴 때마다 GitHub Actions의 `flutter` 실행에서 `ridey-screens`로 새로 만들어진다.

## 디자인

빌려서 제대로 탄 기록은 선, 빌리자마자 반납한 기록은 점으로 그린다. 서로 다른 두 사람의 점이 이어지면 경보이고, 로고 `RIDEY.`의 마침표가 그 점이다. 바탕은 잉크색과 종이색, 경보에만 주황을 쓰고 내 위치와 들를 곳 번호는 파랑으로 한다. 초록 대신 파랑을 고른 건 색각 이상이 있으면 주황과 초록이 거의 같아 보이기 때문이다(ΔE 16). 숫자는 Unbounded 글꼴, 글은 기기 기본 글꼴이다. 앱을 켜면 폰 시작 화면의 `R.`을 같은 자리에서 이어받아 R은 사라지고 마침표만 튀어 올랐다가 떨어져 서울 대여소로 퍼진다(움직임 줄이기를 켜 두면 바로 넘어간다). 사이트, 앱, 발표가 같은 규칙을 쓴다. 자세한 규칙은 [docs/brand.md](docs/brand.md)에 있다.

<p align="center"><img src="docs/brand/board.png" alt="RIDEY 브랜드 보드. 로고, 앱 아이콘, 색, 글꼴, 선과 점" width="860"></p>

## 다른 곳에도 쓸 수 있을까

- 대전 타슈: 서울 기준을 그대로 썼을 때 두 명이 포기한 뒤 다음 사람도 포기한 비율이 41.6\~43.6%였다(평소 2.9%).
- 전기차 충전기: 2026년 8월 권익위가 전기차 충전 민원주의보를 냈다(3년 사이 1.8배). 앱에는 '사용 가능'인데 실제로는 안 되는 충전기를 같은 방법으로 찾아봤다. 연달아 두 번 바로 끊긴 충전기 252대 중 다음 충전도 36.5%가 바로 끊겼다(평소 2.7%). 다만 사람을 구분할 수 없고 정답 자료가 없어서 아직은 가능성만 본 단계다([ev_validation](docs/ev_validation.md)).

## 만든 방법

| 부분 | 쓴 것 |
|---|---|
| 엔진 | 파이썬(`engine/`). 같은 규칙을 SQL로도 짰고 서로 같은 답이 나오는지 자동으로 검사한다 |
| 클라우드 | Supabase Postgres. pg_cron으로 5분마다, pg_net으로 서울 API를 받고 SQL로 연쇄와 확률을 계산한다. 키는 DB의 Vault와 맥 키체인에만 둔다 |
| 앱 | Flutter 하나로 안드로이드와 아이폰(시민 모드와 직원 모드, OpenStreetMap 지도, 번호표 QR 풀기, 끊기면 마지막 기록) |
| 검사 | 파이썬 45개, Flutter 100개(화면 촬영 22개 포함), 사이트와 QR 검사. 올릴 때마다 GitHub Actions가 돌고 APK도 여기서 만든다 |

무료 DB(메모리 0.5GB)가 10월 2일 밤 6시간 멈춘 적이 있다. 5분 작업 한 번이 145MB를 건드려서 DB 캐시가 디스크로 밀려난 탓이었다. '헛대여가 둘 이상 이어져야 경보'라는 조건으로 후보를 먼저 줄이고(답은 같다), 자전거별 기록을 색인에서 바로 읽게 고쳐 한 번에 40MB, 16\~20초로 줄였다. 옛 SQL과 새 SQL이 같은 답을 내는지는 로컬 Postgres에 6월 기록을 흘려 넣어 36시간 동안 73번 비교했다([`tools/live_sql_compare.py`](tools/live_sql_compare.py)).

## 한계

- 고장의 정답 자료가 없다. 고장 신고는 늦고 드물어서, 다음 사람도 바로 반납했는지를 정답 대신 쓴다. 현장에서 직접 확인하는 조사를 준비해 두었다([절차](docs/field_protocol.md)).
- 아무도 빌리지 않은 고장은 못 찾는다. 흔적이 있어야 찾는다.
- 번호표 QR은 번호를 글자판을 섞은 base64로 담고 있다(`SPB-00072627` → `6va03gATEBjUem2w`). 공개 문서가 없어 실제 번호표 16장으로 규칙을 찾았고 16장 모두 맞았다. 다른 형식의 번호표가 나오면 번호를 직접 넣으면 된다.
- 직원 길안내의 도로 경로(OSRM)와 지명 검색(OpenStreetMap Nominatim)은 무료 공개 서버를 쓴다. 경로를 새로 짤 때와 검색 단추를 누를 때만 부른다.
- 고장 종류는 못 맞힌다. 평균으로는 단말기 고장이 더 빨리 반납되지만, 한 대씩 맞혀 보면 10\~14%뿐이라 종류는 현장에서 봐야 한다.

## 직접 돌려 보기

인증키 없이 공개 자료만으로 모든 표를 다시 만들 수 있다.

```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python data/download.py          # 원본 자료 (약 1.7GB)
.venv/bin/python analysis/report.py        # 주요 표 (docs/results.md)
.venv/bin/python server/app.py             # 소개 사이트 (http://localhost:8765)
.venv/bin/python -m pytest -q tests        # 파이썬 테스트
```

<details>
<summary>클라우드 실시간 켜기 (Supabase, 서울 열린데이터광장 인증키)</summary>

키는 코드나 git에 넣지 않는다. 맥에서는 키체인에(`-w`로 끝내면 화면에 안 보이게 묻는다), 클라우드에서는 Supabase Vault에 둔다.

```sh
security add-generic-password -a bike-doctor -s seoul-openapi -w      # 서울 열린데이터광장
security add-generic-password -a bike-doctor -s datagokr -w           # 공공데이터포털 (충전기, 선택)
security add-generic-password -a bike-doctor -s supabase-db -w        # Supabase DB 비밀번호
```

1. Supabase 프로젝트에 `supabase/schema.sql`(쓰기 표), `staff.sql`(직원 명단과 권한), `model.sql`(모델 식), `live.sql`(5분 작업), `ev.sql`(충전기), `calib.sql`(보정) 순서로 적용한다. 클라우드에는 DB 비밀번호로 psql에서 직접 적용한다.
2. Vault에 `seoul_openapi`(필요하면 `datagokr`)를 넣고, 처음에는 `tools/supabase_live_load.py --stations --backfill 8`로 채운다.
3. 공개(publishable) 키를 `app/lib/config/ridey_config.dart`에 넣는다.

확인은 `select at, ms from live.tick_log order by at desc limit 5`로 한다. 파이썬과 같은 답인지는 `tools/supabase_live_load.py --parity`, `--parity-model`로 본다. 충전기 기록은 클라우드에 3일만 남으니 3일 안에 `tools/ev_pull.py` 다음 `analysis/ev_validate.py`를 돌린다. 모델 점검과 다시 배우기는 `tools/retrain.py`(`--deploy`는 나아졌을 때만 바꾼다).
</details>

<details>
<summary>안드로이드, 아이폰</summary>

- 안드로이드 APK는 GitHub Actions의 `flutter` 실행 화면에서 `ridey-apk`로 받는다. 테스트를 통과해야 만들어진다. 직접 만들려면 `cd app && flutter build apk --release`. `app/android/key.properties`(git에 넣지 않음)가 있으면 그 키로, 없으면 디버그 키로 서명한다.
- 아이폰은 `cd app && flutter build ios` 또는 Xcode에서 `app/ios/Runner.xcworkspace`를 열고 Team을 고른 뒤 실행한다.
- 앱 아이콘은 `node tools/make_flutter_assets.js`로 다시 만든다(`docs/brand/icon.svg`에서). 기기의 시작 화면은 잉크색 바탕만 두고, 로고는 앱이 켜지며 그린다(`app/lib/widgets/ridey_intro.dart`).
- 지도는 OpenStreetMap 기본 지도를 받아 색을 차분하게 걸러 그린다(밝은 화면은 옅은 회색, 어두운 화면은 뒤집어 어둡게). 키나 가입이 필요 없고 아이폰과 안드로이드에서 같다. 지도 오른쪽 위에 출처(© OpenStreetMap)를 표시한다.
- 같은 Actions 실행의 `ridey-screens`에는 주요 화면을 밝은 화면과 어두운 화면으로 찍은 사진이 있다. Flutter가 없는 컴퓨터에서도 디자인을 확인할 수 있다.
</details>

<details>
<summary>검사와 제출물 다시 만들기</summary>

```sh
npm i playwright marked
node tests/web/qr.test.js && node tests/web/site.test.js                         # 사이트·QR 검사
node tests/web/record_demo.js                                                    # 시연 영상 (ffmpeg 필요)
node docs/build_pdf.js                                                           # 보고서·제안서·발표 PDF
.venv/bin/python tools/build_site.py                                             # 웹사이트
(cd app && flutter test)                                                         # 이용자 앱
python tools/live_sql_compare.py --old <커밋>                                     # 클라우드 SQL을 고칠 때 옛·새 답 비교 (로컬 Postgres)
```

대회 제출 zip은 `python tools/make_submission.py --id <학번> --name <이름>`으로 만든다. APK는 Actions에서 받은 것을 `dist/RIDEY.apk`로 두면 된다.
</details>

## 폴더

| 폴더 | 내용 |
|---|---|
| [`engine/`](engine) | 헛대여, 연쇄, 경보 규칙(`core.py`), 아침 목록(`morning.py`), 충전기(`ev.py`) |
| [`supabase/`](supabase) | 5분 작업(`live.sql`), 모델 식(`model.sql`), 충전기(`ev.sql`), 쓰기 표(`schema.sql`), 직원 명단(`staff.sql`) |
| [`app/`](app/README.md) | Flutter 앱(시민 모드와 직원 모드) |
| [`analysis/`](analysis) | 검증 스크립트. 기준 고르기, 실시간 대조, 모델 학습과 비교, 공단 수거 효과, 그림 |
| [`site/`](site) | 작품 소개 웹사이트(GitHub Pages) |
| [`docs/`](docs/README.md) | 보고서, 발표, 대본, 결과 표, 조사 자료([문서 목록](docs/README.md), [스토리라인](docs/story.md)) |
| [`tools/`](tools) | 클라우드 적재와 대조, SQL 비교, 다시 배우기, 제출물 만들기 |
| [`tests/`](tests) | 파이썬, 사이트, QR 검사(앱 검사는 `app/` 안) |

대여소 목록을 새로 만들면 `analysis/export_web.py`가 `data/stations.json`을 쓰고, 이 파일을 `app/assets/data/stations.json`에 복사한다. 옛 SwiftUI 아이폰 앱, Capacitor 안드로이드 앱, 웹 데모(`web/`), 운영 대시보드(`dashboard/`)는 Flutter 앱 하나로 합치면서 지웠고, 이전 모습은 git 기록(커밋 `0a7be37` 이전)에 남아 있다.

측정 과정과 실패한 시도는 [`PLAN.md`](PLAN.md)에, 바뀐 점은 [`CHANGELOG.md`](CHANGELOG.md)에 적어 두었다.

## 자료와 참고

- 자료: 서울 열린데이터광장의 따릉이 대여이력([OA-15182](https://data.seoul.go.kr/dataList/OA-15182/F/1/datasetView.do), 실시간 API `tbCycleRentData`), 고장신고([OA-15644](https://data.seoul.go.kr/dataList/OA-15644/F/1/datasetView.do)), 대여소 정보. 공공데이터포털의 대전 타슈 대여이력과 한국환경공단 전기차 충전기 상태. 모두 공공누리 제1유형이다. 앱과 공개 화면에는 이용자 정보(생년, 성별)가 없고, 클라우드는 대여 기록을 8일만 둔다.
- 참고 연구: Kaspi, Raviv, Tzur, [Detection of Unusable Bicycles in Bike-Sharing Systems](https://www.researchgate.net/publication/290496984_Detection_of_Unusable_Bicycles_in_Bike-Sharing_Systems) (Omega, 2016), [Self-Supervised Transformer for Unusable Shared Bike Detection](https://arxiv.org/pdf/2505.00932) (2025). 비교는 [related_work](docs/related_work.md)에 있다.
- 라이브러리: 앱은 Flutter와 pub.dev 패키지를 쓰고, 지도는 [flutter_map](https://pub.dev/packages/flutter_map)으로 [OpenStreetMap](https://www.openstreetmap.org/copyright)(ODbL) 기본 지도를 그린다. QR 검사에는 [jsQR](https://github.com/cozmo/jsQR) 1.4.0(Apache-2.0)을 `tests/vendor/`에 라이선스와 함께 넣었다. 전체 목록은 [docs/credits.md](docs/credits.md). 글꼴은 Unbounded(OFL)에서 숫자와 대문자만 잘라 넣었다.
- 라이선스: 코드는 [MIT](LICENSE). 자료는 각 출처의 공공누리 제1유형(출처 표시)을 따른다.
