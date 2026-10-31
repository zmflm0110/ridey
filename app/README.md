# RIDEY 앱

따릉이를 타기 전에 고장 의심 자전거를 보는 Flutter 앱이다. 첫 실행에서 시민 모드와 직원 모드를 고른다. 시민 모드에는 직원 화면이 없고, 직원 모드는 구별 고장 의심 목록만 읽는다.

## 화면

시민 모드: 홈, 번호 조회, QR, OCR, 대여소, 자전거 상세. 상세에는 판단 근거와 같은 대여소의 다른 의심 자전거가 있다. 홈에는 내 주변 대여소별 의심 대수가 있고, 위치를 쓸 수 없으면 저장해 둔 대여소를 보여 준다.

직원 모드: 구별 현황, 대여소별 목록(아침 목록·실시간), 더보기. 현장 판정이나 사진 업로드는 없다.

조회 기록은 이 폰에만 남는다. 최근 14일, 위치는 약 500m 격자로 줄인다. 알림도 이 폰 안에서만 만들고, 사용자가 켜야 한다. 하루 한 번, 습관 시간 15분 전부터 그 시간이 끝날 때까지, 습관 위치 1km 안에 의심 자전거가 있을 때만 보낸다.

## 실행

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

Supabase 주소와 publishable 키는 앱 설정을 따른다. secret 키는 넣지 않는다. 대여소 좌표는 `assets/data/stations.json`에 들어 있다. 다시 만들려면 저장소 루트에서 `analysis/export_web.py`를 돌린다(`data/stations.json`에도 같이 쓴다).

Android 릴리스 매니페스트에는 `INTERNET`이 있다. 알림을 쓰려면 알림 권한과, Android에서는 부팅 뒤 예약을 위한 `RECEIVE_BOOT_COMPLETED`가 필요하다. iOS 배경 갱신 시각은 기기가 정한다.
