// 시연 영상용 자동 실행: 실제 폰에서 실제 자료로 앱을 사람처럼 조작한다(맥에서 화면을 녹화하는 동안).
// 실행(프로파일 모드라 배포판처럼 부드럽다):
//   flutter drive --profile --driver=test_driver/integration_test.dart \
//     --target=integration_test/demo_test.dart -d <기기> \
//     --dart-define=RIDEY_DEMO_LOCATION=37.501713,126.995476
// '내 위치' 는 RIDEY_DEMO_LOCATION 으로 고정하고, 길안내 동안에는 실제 도로 경로를 따라 움직인다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ridey_app/app/launch_mark.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/staff/road_route.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 받은 도로 경로를 기억한다(길안내 때 그 길을 따라 위치를 옮기려고).
class _RecordingRouter extends RoadRouter {
  RoadRoute? last;

  @override
  Future<RoadRoute?> route(List<LatLng> waypoints) async {
    final got = await super.route(waypoints);
    if (got != null) last = got;
    return got;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 실제 사용처럼 매 프레임 그린다(테스트 기본값은 필요할 때만 그려서 애니메이션이 끊긴다).
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('RIDEY demo', (tester) async {
    final here =
        _parse(RideyConfig.demoLocation) ??
        (latitude: 37.501713, longitude: 126.995476);
    await LaunchMark.load();
    await tester.pumpWidget(
      const ColoredBox(
        color: Color(0xFF111317),
        child: CustomPaint(painter: LaunchMarkPainter(), size: Size.infinite),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await LaunchMark.load();

    // 지금 실시간 자료에서 내 근처의 강한 경보 자전거 하나(번호 입력 장면에 쓴다).
    final snapshot = await SupabaseLiveSnapshotRepository().fetch();
    final stations = {
      for (final s in await BundledStationRepository().fetch()) s.id: s,
    };
    double away(LiveBike b) {
      final s = stations[b.station];
      if (s == null) return double.infinity;
      return metersBetween(
        here.latitude,
        here.longitude,
        s.latitude,
        s.longitude,
      );
    }

    final nearby = [...snapshot.bikes]
      ..sort((a, b) {
        if (a.isHighAlert != b.isHighAlert) return a.isHighAlert ? -1 : 1;
        return away(a).compareTo(away(b));
      });
    final pick = nearby.firstWhere(
      (b) => away(b) < 3000,
      orElse: () => nearby.first,
    );

    final router = _RecordingRouter();
    final moving = StreamController<DeviceLocation>.broadcast();
    DeviceLocation now = here;

    Future<void> hold(int ms) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> until(Finder f, {int seconds = 20}) async {
      final end = DateTime.now().add(Duration(seconds: seconds));
      while (f.evaluate().isEmpty && DateTime.now().isBefore(end)) {
        await hold(200);
      }
    }

    // 못 찾으면 그 단계만 건너뛰고 이어 간다(영상이 중간에 멈추지 않게).
    Future<void> tap(Finder f, {int after = 900}) async {
      await until(f);
      if (f.evaluate().isEmpty) {
        debugPrint('DEMO skip tap: $f');
        return;
      }
      await tester.tap(f.last, warnIfMissed: false);
      await hold(after);
    }

    // 폰 자판이 보내는 길(updateEditingValue)로 한 글자씩 넣는다 — 실제 자판이 떠 있는 채로 글자가 찍힌다.
    Future<void> type(String text) async {
      await until(find.byType(EditableText));
      final state = tester.state<EditableTextState>(
        find.byType(EditableText).last,
      );
      final runes = text.runes.toList();
      for (var i = 1; i <= runes.length; i++) {
        final value = String.fromCharCodes(runes.take(i));
        state.updateEditingValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        );
        await hold(170);
      }
    }

    Future<void> swipe(Finder f, Offset by, {int ms = 700}) async {
      await until(f, seconds: 8);
      if (f.evaluate().isEmpty) {
        debugPrint('DEMO skip swipe: $f');
        return;
      }
      await tester.timedDrag(f.first, by, Duration(milliseconds: ms));
      await hold(800);
    }

    Finder pressable(bool Function(String label) test) =>
        find.byWidgetPredicate(
          (w) => w is RideyPressable && test(w.semanticLabel ?? ''),
        );

    Widget app() => RideyApp(
      key: UniqueKey(),
      showIntro: true,
      askRoleOnLaunch: true,
      readLocation: () async => now,
      watchLocation: () async* {
        yield now;
        yield* moving.stream;
      },
      roadRouter: router,
    );

    debugPrint('DEMO START');
    // ───── 1. 켤 때: R. → 점 → 서울, 역할 묻기(첫 실행) ─────
    await tester.pumpWidget(app());
    await hold(5200);
    await tap(find.text('따릉이를 이용하는 일반 시민이에요'), after: 1600);
    await tap(find.text('위치 허용하기'), after: 3500);

    // ───── 2. 시민 홈: 내 근처, 고장 의심 목록, 대여소 현황 ─────
    await swipe(find.byType(DraggableScrollableSheet), const Offset(0, -260));
    await hold(1500);
    await swipe(find.byType(DraggableScrollableSheet), const Offset(0, 260));
    await tap(find.text('주변 대여소 현황'), after: 2500);
    await tap(find.text('고장 의심 따릉이'), after: 1500);

    // 갈 곳 미리 보기: 검색 → 역 이름
    await tap(pressable((l) => l == '장소 검색'), after: 900);
    await type('고속터미널');
    await hold(900);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(700);
    await tap(pressable((l) => l.endsWith('근처 보기')), after: 3500);
    await tap(find.text('내 위치로'), after: 2500);

    // 목록의 자전거 → 상세
    await tap(
      find
          .byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label ?? '').endsWith('고장 의심 자세히 보기'),
          )
          .first,
      after: 2500,
    );
    await tap(find.byTooltip('뒤로'), after: 1200);

    // ───── 3. 자전거 확인: 번호(숫자만) → 경보 → 근거 → 고장 신고 ─────
    await tap(find.text('자전거 확인'), after: 1200);
    await tap(find.byType(TextField), after: 600);
    await type(pick.bike.replaceFirst('SPB-', ''));
    await hold(600);
    // 자판을 내리고 조회.
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(500);
    await tap(find.text('조회하기'), after: 3000);
    await swipe(find.byType(Scrollable).last, const Offset(0, -420), ms: 1200);
    await tap(find.text('판단 근거 자세히 보기'), after: 3500);
    await swipe(find.byType(Scrollable).last, const Offset(0, -500), ms: 1400);
    await hold(1200);
    // 뒤로 단추는 맨 위에 있다 — 올려서 누른다.
    await swipe(find.byType(Scrollable).last, const Offset(0, 900), ms: 700);
    await tap(find.byTooltip('뒤로'), after: 1200);
    await swipe(find.byType(Scrollable).last, const Offset(0, -600), ms: 900);
    // '고장 신고하기' 는 보여 주기만 한다 — 누르면 서울시 사이트 로그인 화면과 폰에 저장된 계정이 뜬다.
    await hold(2500);
    await swipe(find.byType(Scrollable).last, const Offset(0, 900), ms: 800);
    await tap(find.byTooltip('뒤로'), after: 1000);

    // ───── 4. 내 대여소: 지도에서 자리 확인 → '넣기' ─────
    await tap(find.text('더보기'), after: 1200);
    await tap(find.text('자주 쓰는 대여소'), after: 2500);
    await tap(find.text('대여소 검색'), after: 900);
    await tap(find.byType(TextField), after: 300);
    await type('반포종합운동장');
    await hold(900);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(700);
    await tap(
      find
          .descendant(
            of: find.byType(RideyRow),
            matching: find.textContaining('반포종합운동장'),
          )
          .first,
      after: 2800,
    );
    await tap(find.text('내 대여소에 넣기'), after: 2500);
    await tap(find.byTooltip('뒤로'), after: 1200);

    // ───── 5. 다시 켜기 → 관리 직원 ─────
    await tester.pumpWidget(const ColoredBox(color: Color(0xFF111317)));
    await hold(700);
    await tester.pumpWidget(app());
    await hold(5200);
    await tap(find.text('따릉이를 수거하고 점검하는 관리 직원이에요'), after: 2500);
    await tap(find.text('서초구'), after: 700);
    await tap(find.text('이 구부터 보기'), after: 6000);

    // 오늘 추천 경로: 재배치 + 고장 의심 ↔ 고장 의심만
    await swipe(find.text('오늘 추천 경로'), const Offset(0, -250));
    await hold(2000);
    await tap(find.text('고장 의심만'), after: 4500);
    await tap(find.text('재배치 + 고장 의심'), after: 4500);

    // ───── 6. 길안내: 실제 도로를 따라 움직인다 ─────
    final sheet = find.descendant(
      of: find.byType(DraggableScrollableSheet),
      matching: find.byType(Scrollable),
    );
    try {
      await tester.scrollUntilVisible(
        find.text('길안내 시작'),
        120,
        scrollable: sheet.first,
      );
    } catch (_) {
      debugPrint('DEMO skip scroll');
    }
    await hold(600);
    await tap(find.text('길안내 시작'), after: 3000);
    final road = router.last;
    if (road != null) {
      final stops = [
        for (final leg in road.legs)
          if (leg.isNotEmpty) leg.last.location,
      ];
      // 빨리 감기: 길을 따라 일정한 간격(45m)으로, 1초에 10번 옮긴다.
      var stop = 0;
      var i = 0;
      var along = 0.0;
      double seg(int k) => metersBetween(
        road.points[k].latitude,
        road.points[k].longitude,
        road.points[k + 1].latitude,
        road.points[k + 1].longitude,
      );
      final last = road.points.length - 2;
      while (last >= 0 && stop < math.min(2, stops.length)) {
        along += 45;
        var d = seg(i);
        while (along > d && i < last) {
          along -= d;
          i++;
          d = seg(i);
        }
        final end = along >= d && i == last;
        if (end) along = d;
        final a = road.points[i], b = road.points[i + 1];
        final t = d == 0 ? 1.0 : along / d;
        now = (
          latitude: a.latitude + (b.latitude - a.latitude) * t,
          longitude: a.longitude + (b.longitude - a.longitude) * t,
        );
        moving.add(now);
        await hold(100);
        final target = stops[stop];
        if (metersBetween(
              now.latitude,
              now.longitude,
              target.latitude,
              target.longitude,
            ) <
            35) {
          now = (latitude: target.latitude, longitude: target.longitude);
          moving.add(now);
          await hold(3500);
          await tap(find.text('다음 곳으로'), after: 1500);
          stop++;
        }
        if (end) break;
      }
    }
    await hold(1500);
    await tap(find.byTooltip('길안내 끝내기'), after: 1500);

    // ───── 7. 구별 현황 → 구 → 자전거(타 봐야 아는 고장) → 성적 ─────
    await swipe(find.text('오늘 추천 경로'), const Offset(0, -300));
    try {
      await tester.scrollUntilVisible(
        find.text('서초구'),
        150,
        scrollable: sheet.first,
      );
    } catch (_) {
      debugPrint('DEMO skip scroll');
    }
    await hold(800);
    await tap(find.text('서초구'), after: 2500);
    await tap(find.textContaining('SPB-').first, after: 3500);
    await tap(find.text('목록으로 돌아가기'), after: 1200);
    await tap(find.byTooltip('뒤로'), after: 1500);
    await hold(3000);
    debugPrint('DEMO DONE');
  });
}

DeviceLocation? _parse(String raw) {
  final p = raw.split(',');
  if (p.length != 2) return null;
  final lat = double.tryParse(p[0].trim()), lon = double.tryParse(p[1].trim());
  if (lat == null || lon == null) return null;
  return (latitude: lat, longitude: lon);
}
