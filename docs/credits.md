# 출처 (에셋, 라이브러리, 자료)

대회 규칙에 따라 에셋과 엔진의 출처, 그리고 내려받은 원본을 함께 낸다. 제출 zip의 `5_출처/` 폴더에 아래 원본을 그대로 넣는다(`tools/make_submission.py`가 만든다).

상용 엔진은 쓰지 않았다. 아이콘, 색, 화면 같은 디자인 에셋은 모두 직접 만들었다.

| 무엇 | 어디에 썼나 | 라이선스 | 받은 곳 | zip 안 위치 |
|---|---|---|---|---|
| Leaflet 1.9.4 | 웹 데모와 운영 화면의 지도 | BSD-2-Clause | https://leafletjs.com/download.html, https://github.com/Leaflet/Leaflet/releases/tag/v1.9.4 | `5_출처/leaflet-1.9.4/` |
| jsQR 1.4.0 | 웹 데모의 QR 읽기 | Apache-2.0 | https://github.com/cozmo/jsQR, https://www.npmjs.com/package/jsqr | `5_출처/jsqr-1.4.0/` |
| Flutter SDK 3.47 | 이용자 앱(안드로이드와 아이폰을 한 코드로) | BSD-3-Clause | https://flutter.dev | `5_출처/flutter.txt` |
| Flutter 패키지: camera, mobile_scanner, google_mlkit_text_recognition, geolocator, shared_preferences, http, workmanager, flutter_local_notifications, cupertino_icons | 이용자 앱의 카메라, QR, 번호판 글자 인식, 위치, 폰 저장, 알림 | BSD-3, MIT, Apache-2.0(꾸러미마다 LICENSE 포함) | https://pub.dev(버전과 sha256은 `app/pubspec.lock`) | `5_출처/pub/` |
| Next.js 16, React 19, Supabase JS(@supabase/ssr, supabase-js) | 직원용 운영 화면 | MIT | https://www.npmjs.com(버전, 주소, 무결성 값은 `dashboard/package-lock.json`) | `5_출처/npm/` |
| OpenStreetMap 지도 타일 | 지도 바탕(인터넷으로 불러오고 화면 오른쪽 아래에 출처 표시) | © OpenStreetMap 기여자, ODbL | https://www.openstreetmap.org/copyright | `5_출처/openstreetmap.txt` |
| 서울 열린데이터광장: 따릉이 대여이력(OA-15182, API tbCycleRentData), 고장신고(OA-15644), 대여소 정보 | 엔진, 검증, 실시간 | 공공누리 제1유형(출처 표시) | https://data.seoul.go.kr | `5_출처/공공데이터.txt` |
| 공공데이터포털: 대전 타슈 대여이력, 한국환경공단 전기차 충전소 정보 | 다른 도시 검증, 충전기 실험 | 공공누리 제1유형 | https://www.data.go.kr | `5_출처/공공데이터.txt` |
| Supabase(DB, 5분마다 서울 API를 받아 경보 계산과 채점), GitHub Actions(백업, 충전기 자료 모으기, 앱 빌드) | 클라우드 | 무료 요금제 | https://supabase.com, https://github.com/features/actions | `5_출처/클라우드.txt` |
| Python pandas, NumPy, scikit-learn, matplotlib | 대여 기록 분석과 자체 모델 학습(그래디언트 부스팅). 앱에는 들어가지 않고, 학습한 나무를 SQL로 옮겨 DB에 넣었다 | BSD-3-Clause 등 | https://pypi.org | `4_소스/requirements.txt` |

## 직접 만든 것

- 로고 'RIDEY.'와 앱 아이콘 'R.'은 `tools/make_brand.py`가 코드로 그린다(`web/icon.svg`). PNG는 `tools/make_icons.js`와 `tools/make_flutter_assets.js`가 만든다.
- 색과 화면 디자인: `web/style.css`, `app/lib/design/ridey_theme.dart`, `dashboard/app/globals.css`.
- 엔진, 서버, 분석 코드, 자체 모델(학습 `analysis/train_model.py`, DB 식 `supabase/model.sql`).

## 글꼴

- 숫자와 로고 글자는 Unbounded(SIL Open Font License 1.1, https://fonts.google.com/specimen/Unbounded)에서 숫자, 대문자, 기호만 잘라 넣었다. `web/fonts`, `app/assets/fonts`, `dashboard/public/fonts`에 있고, 라이선스 파일 `OFL-Unbounded.txt`가 같은 폴더에 있다.
- 한글은 기기 기본 글꼴을 쓴다(아이폰 Apple SD Gothic Neo, 안드로이드 Noto Sans CJK).
- 소개 웹사이트(`site/`)만 한글 Pretendard(SIL Open Font License 1.1, https://github.com/orioncactus/pretendard)를 인터넷으로 불러온다.
