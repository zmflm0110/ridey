// 시연 영상 중 '길안내' 장면만 다시 찍는다: 추천 경로를 따라 대여소 3곳에 차례로 도착해서 넘기면
// 지도의 점이 체크로 바뀌고 '이번 길' 대수가 쌓인다. 맥은 'DEMO CLIP IN/OUT' 사이를 잘라 쓴다.
// 빌드: flutter build ios --profile --target=integration_test/nav_clip_test.dart \
//   --dart-define=RIDEY_DEMO_LOCATION=37.501713,126.995476
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ridey_app/app/launch_mark.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/staff/road_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 받은 도로 경로와 그때 넣은 들를 곳(출발점 + 대여소들)을 기억한다.
class _RecordingRouter extends RoadRouter {
  RoadRoute? last;
  List<LatLng> stops = const [];

  @override
  Future<RoadRoute?> route(List<LatLng> waypoints) async {
    final got = await super.route(waypoints);
    if (got != null) {
      last = got;
      stops = waypoints;
    }
    return got;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('RIDEY navigation clip', (tester) async {
    final here =
        _parse(RideyConfig.demoLocation) ??
        (latitude: 37.501713, longitude: 126.995476);
    await LaunchMark.load();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

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

    Future<void> tap(Finder f, {int after = 900}) async {
      await until(f);
      if (f.evaluate().isEmpty) {
        debugPrint('DEMO skip tap: $f');
        return;
      }
      await tester.tap(f.last, warnIfMissed: false);
      await hold(after);
    }

    void moveTo(DeviceLocation p) {
      now = p;
      moving.add(p);
    }

    await tester.pumpWidget(
      RideyApp(
        key: UniqueKey(),
        showIntro: true,
        askRoleOnLaunch: true,
        readLocation: () async => now,
        watchLocation: () async* {
          yield now;
          yield* moving.stream;
        },
        roadRouter: router,
      ),
    );
    debugPrint('DEMO START');
    await hold(5200);
    await tap(find.text('따릉이를 수거하고 점검하는 관리 직원이에요'), after: 2500);
    await tap(find.text('서초구'), after: 700);
    await tap(find.text('이 구부터 보기'), after: 6000);
    await tap(find.text('재배치 + 고장 의심'), after: 4000);

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
    await hold(1500);
    debugPrint('DEMO CLIP IN');
    await tap(find.text('길안내 시작'), after: 2500);

    final road = router.last;
    final targets = router.stops.length > 1
        ? router.stops.sublist(1)
        : const <LatLng>[];
    var done = 0;
    if (road != null && road.points.length > 1) {
      // 도착해서 할 일을 마쳤다고 보고 넘긴다.
      Future<void> finishStop() async {
        await until(find.text('다음 곳으로'), seconds: 3);
        await hold(2200);
        await tap(find.text('다음 곳으로'), after: 2000);
        done++;
      }

      // 첫 곳이 출발점이면 바로 도착이다.
      if (targets.isNotEmpty &&
          metersBetween(
                now.latitude,
                now.longitude,
                targets.first.latitude,
                targets.first.longitude,
              ) <
              35) {
        await finishStop();
      }
      // 길을 따라 빨리 감기(멀리서는 45m, 대여소 가까이서는 10m씩). 대여소 30m 안이면 그 자리에 선다.
      var i = 0;
      var along = 0.0;
      var closest = double.infinity;
      while (done < 3 && done < targets.length && i < road.points.length - 1) {
        final target = targets[done];
        final away = metersBetween(
          now.latitude,
          now.longitude,
          target.latitude,
          target.longitude,
        );
        if (away < 30 || (closest < 90 && away > closest + 20)) {
          moveTo((latitude: target.latitude, longitude: target.longitude));
          await hold(400);
          await finishStop();
          closest = double.infinity;
          continue;
        }
        if (away < closest) closest = away;
        along += away < 160 ? 10 : 45;
        final a = road.points[i], b = road.points[i + 1];
        var d = metersBetween(a.latitude, a.longitude, b.latitude, b.longitude);
        while (along > d && i < road.points.length - 2) {
          along -= d;
          i++;
          final p = road.points[i], q = road.points[i + 1];
          d = metersBetween(p.latitude, p.longitude, q.latitude, q.longitude);
        }
        final p = road.points[i], q = road.points[i + 1];
        final t = d == 0 ? 1.0 : (along / d).clamp(0.0, 1.0);
        moveTo((
          latitude: p.latitude + (q.latitude - p.latitude) * t,
          longitude: p.longitude + (q.longitude - p.longitude) * t,
        ));
        await hold(100);
      }
    }
    debugPrint('DEMO stops done: $done');
    await hold(3000);
    await tap(find.byTooltip('길안내 끝내기'), after: 2500);
    debugPrint('DEMO CLIP OUT');
    await hold(1500);
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
