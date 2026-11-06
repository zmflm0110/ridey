# RIDEY

타기 전에, 고장 난 따릉이를 먼저 알려 주는 앱.

사람들은 고장 신고 대신 빌리자마자 반납하는 경우가 많다. RIDEY는 서울시 공개 대여 기록에서 서로 다른 사람이 연달아 바로 반납한 자전거를 찾아, 시민에게는 타기 전 확인을, 직원에게는 재배치 길에 얹을 목록을 준다.

## 구조

| 폴더 | 내용 |
|---|---|
| [`app/`](app) | Flutter 앱. 시민 모드와 직원 모드 |
| [`engine/`](engine) | 헛대여·연쇄·경보 규칙, 아침 목록, 정비 동선 |
| [`supabase/`](supabase) | 5분마다 서울 API를 받아 경보와 확률을 계산하는 SQL |
| [`server/`](server) | 서울 API 수집, 아침 목록, 실시간 파이썬 구현(SQL과 같은 답인지 검사) |
| [`analysis/`](analysis) | 규칙 검증·모델 학습. 공개 자료만으로 표를 다시 만들 수 있다 |
| [`tools/`](tools) | 클라우드 적재, SQL 대조, 모델 다시 배우기, 대여소 목록 갱신 |
| [`tests/`](tests) | 파이썬 검사. 앱 검사는 `app/test` |
| [`data/`](data) | 대여소 목록, 원본 내려받기 스크립트 |

앱은 계산하지 않는다. 클라우드가 낸 공개 뷰(`live_snapshot`, `ops_lists`, `ops_scores`, `ops_alarm_days`)를 읽기만 한다.

## 규칙

- **헛대여:** 같은 대여소에 3분 안에, 300m 미만으로 반납
- **경보:** 서로 다른 사람 헛대여 2연속. 3명 이상이면 강한 경보
- 같은 사람의 재시도는 한 번으로 센다(생년·성별, 없으면 반납 2분 안 재대여)

기준은 2026년 1월 기록으로만 정하고, 3월·6월과 대전 타슈에는 그대로 적용했다.

## 실행

### 앱

```sh
cd app
flutter pub get
flutter test
flutter run
```

안드로이드 APK: `cd app && flutter build apk --release`  
나온 파일: `app/build/app/outputs/flutter-apk/app-release.apk`

아이폰: `cd app && flutter build ios`, 또는 Xcode에서 `app/ios/Runner.xcworkspace`를 열고 Team을 고른 뒤 실기기에 설치.

### 분석·검사

```sh
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python data/download.py          # 원본 자료 (약 1.7GB)
.venv/bin/python analysis/report.py        # 핵심 표
.venv/bin/python -m pytest -q tests
cd app && flutter test
```

클라우드(Supabase)를 직접 켜려면 `supabase/`의 SQL을 적용하고, 키는 코드에 넣지 않는다. 공개 키만 `app/lib/config/ridey_config.dart`에 둔다. 자세한 적재는 `tools/supabase_live_load.py`를 본다.

## 자료와 라이선스

서울 열린데이터광장 따릉이 대여이력·고장신고·대여소 정보, 공공데이터포털 대전 타슈 대여이력(공공누리 제1유형). 코드는 [MIT](LICENSE). 라이브러리·글꼴·지도 출처는 [CREDITS.md](CREDITS.md).
