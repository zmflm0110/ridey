// 시연 영상용 자동 실행: 실제 폰에서 실제 자료로 앱을 사람처럼 조작한다(맥에서 화면을 녹화하는 동안).
// 실행(프로파일 모드라 배포판처럼 부드럽다):
//   flutter build ios --profile --target=integration_test/demo_test.dart \
//     --dart-define=RIDEY_DEMO_LOCATION=37.501713,126.995476
//   xcrun devicectl device install app ... && xcrun devicectl device process launch --console ...
// '내 위치' 는 RIDEY_DEMO_LOCATION 으로 고정하고, 길안내 동안에는 실제 도로 경로를 따라 움직인다.
// 다른 앱(지도·따릉이)으로 넘어갈 때 'DEMO AWAY' 를 찍는다 — 맥에서 그 줄을 보고 RIDEY 를 다시 앞으로 부른다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ridey_app/app/launch_mark.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/notifications/habit_notifier.dart';
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
    // 알림 권한은 녹화 앞부분(잘라 냄)에서 미리 받는다 — 처음 깔았을 때만 묻는다.
    debugPrint('DEMO PERMISSION');
    await requestHabitNotificationPermission();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await LaunchMark.load();

    // 이용 시간: 지난주 이 요일·이 시간에 이 근처에서 두 번 확인했다고 둔다(실제로 쓰던 사람처럼).
    // 오늘 시연에서 하는 확인까지 더해져 '자주 확인하는 시간' 이 된다.
    final grid = snapToGrid(here.latitude, here.longitude);
    final clock = DateTime.now();
    for (final m in const [3, 9]) {
      await LookupHabitStore().add(
        LookupEvent(
          kind: LookupKind.number,
          at: clock.subtract(Duration(days: 7, minutes: m)),
          latitude: grid.latitude,
          longitude: grid.longitude,
          subject: 'SPB-5629$m',
        ),
      );
    }

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
    Future<void> tap(Finder f, {int after = 900, int seconds = 20}) async {
      await until(f, seconds: seconds);
      if (f.evaluate().isEmpty) {
        debugPrint('DEMO skip tap: $f');
        return;
      }
      await tester.tap(f.last, warnIfMissed: false);
      await hold(after);
    }

    Future<void> tapAt(Offset at, {int after = 900}) async {
      await tester.tapAt(at);
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

    Finder labelled(bool Function(String label) test) => find.byWidgetPredicate(
      (w) => w is Semantics && test(w.properties.label ?? ''),
    );

    // 지도 위에 보이는 대여소 점 하나(시트·검색 칸에 가리지 않은 곳, 화면 가운데에 가까운 것).
    Offset? visiblePin({bool alert = true}) {
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      final pins = labelled(
        (l) => alert
            ? l.startsWith('고장 의심 ') && l.endsWith('대여소')
            : l.endsWith('대여소'),
      );
      Offset? me;
      for (final e
          in find
              .byWidgetPredicate((w) => w.runtimeType.toString() == '_UserDot')
              .evaluate()) {
        final box = e.renderObject;
        if (box is RenderBox && box.hasSize && box.attached) {
          me = box.localToGlobal(box.size.center(Offset.zero));
        }
      }
      Offset? best;
      for (final e in pins.evaluate()) {
        final box = e.renderObject;
        if (box is! RenderBox || !box.hasSize || !box.attached) continue;
        final c = box.localToGlobal(box.size.center(Offset.zero));
        if (c.dx < 40 || c.dx > size.width - 40) continue;
        if (c.dy < 170 || c.dy > size.height * 0.42) continue;
        if (me != null && (c - me).distance < 70) continue;
        final mid = Offset(size.width / 2, size.height * 0.3);
        if (best == null || (c - mid).distance < (best - mid).distance) {
          best = c;
        }
      }
      return best;
    }

    Future<void> tapPin({bool alert = true, int after = 2200}) async {
      final end = DateTime.now().add(const Duration(seconds: 8));
      Offset? at;
      while ((at = visiblePin(alert: alert)) == null &&
          DateTime.now().isBefore(end)) {
        await hold(300);
      }
      at ??= visiblePin(alert: false);
      if (at == null) {
        debugPrint('DEMO skip pin');
        return;
      }
      await tapAt(at, after: after);
    }

    // 다른 앱으로 넘어갔다가(맥이 RIDEY 를 다시 앞으로 부른다) 돌아올 때까지 기다린다.
    Future<void> awayAndBack(String what) async {
      final end = DateTime.now().add(const Duration(seconds: 6));
      while (binding.lifecycleState == AppLifecycleState.resumed &&
          DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (binding.lifecycleState == AppLifecycleState.resumed) {
        debugPrint('DEMO stayed: $what');
        return;
      }
      debugPrint('DEMO AWAY $what');
      while (binding.lifecycleState != AppLifecycleState.resumed) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      debugPrint('DEMO BACK $what');
      await hold(1500);
    }

    Future<void> back({int after = 1200}) async {
      final button = find.byTooltip('뒤로');
      await until(button, seconds: 2);
      if (button.evaluate().isNotEmpty) {
        await tester.tap(button.last, warnIfMissed: false);
        await hold(after);
        return;
      }
      for (final nav
          in tester
              .stateList<NavigatorState>(find.byType(Navigator))
              .toList()
              .reversed) {
        if (nav.canPop()) {
          nav.pop();
          await hold(after);
          return;
        }
      }
      debugPrint('DEMO skip back');
    }

    // 더보기 화면의 줄(제목으로 찾음). 보이지 않으면 내려서 찾는다.
    Future<void> tapRow(String title, {int after = 1500}) async {
      final f = find.text(title);
      try {
        await tester.scrollUntilVisible(
          f,
          120,
          scrollable: find.byType(Scrollable).last,
        );
      } catch (_) {}
      await tap(f, after: after);
    }

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
    // ───── 1. 켤 때: R. → 점 → 서울, 이용 목적 묻기 ─────
    await tester.pumpWidget(app());
    await hold(5200);
    await tap(find.text('따릉이를 이용하는 일반 시민이에요'), after: 1600);
    await tap(find.text('위치 허용하기'), after: 3500);

    // ───── 2. 시민 홈: 바텀시트 올리고 내리기, 고장 의심 ↔ 대여소 현황 ─────
    await swipe(find.byType(DraggableScrollableSheet), const Offset(0, -260));
    await hold(1500);
    await swipe(find.byType(DraggableScrollableSheet), const Offset(0, 260));
    await tap(find.text('주변 대여소 현황'), after: 2500);
    await tap(find.text('고장 의심 따릉이'), after: 1500);

    // ───── 3. 지도의 대여소 누르기 → 카드 → 길 찾기(지도 앱) / 대여하기(따릉이 앱) ─────
    await tapPin();
    await hold(1500);
    await tap(find.text('길 찾기'), after: 300);
    await awayAndBack('길 찾기');
    await tapPin();
    await hold(1000);
    await tap(find.text('대여하기'), after: 300);
    await awayAndBack('대여하기');

    // ───── 4. 갈 곳 미리 보기: 검색 → 역 이름 → 그 근처 ─────
    await tap(pressable((l) => l == '장소 검색'), after: 900);
    await type('고속터미널');
    await hold(900);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(700);
    await tap(pressable((l) => l.endsWith('근처 보기')), after: 3500);
    await tap(find.text('내 위치로'), after: 2500);

    // 목록의 자전거 → 상세
    await tap(labelled((l) => l.endsWith('고장 의심 자세히 보기')).first, after: 2500);
    await back(after: 1200);

    // ───── 5. 자전거 확인: QR 하나만(번호판 읽기는 없음), 번호 → 경보 → 근거 ─────
    await tap(find.text('자전거 확인'), after: 1800);
    debugPrint(
      'DEMO plate button: ${find.textContaining('번호판').evaluate().length}, '
      'QR: ${find.text('QR로 찍기').evaluate().length}',
    );
    await tap(find.byType(TextField), after: 600);
    await type(pick.bike.replaceFirst('SPB-', ''));
    await hold(600);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(500);
    await tap(find.text('조회하기'), after: 3000);
    await swipe(find.byType(Scrollable).last, const Offset(0, -420), ms: 1200);
    await tap(find.text('판단 근거 자세히 보기'), after: 3500);
    await swipe(find.byType(Scrollable).last, const Offset(0, -500), ms: 1400);
    await hold(1200);
    await swipe(find.byType(Scrollable).last, const Offset(0, 900), ms: 700);
    await back(after: 1200);
    await swipe(find.byType(Scrollable).last, const Offset(0, -600), ms: 900);
    // '고장 신고하기' 는 보여 주기만 한다 — 누르면 서울시 사이트 로그인 화면과 폰에 저장된 계정이 뜬다.
    await hold(2500);
    await swipe(find.byType(Scrollable).last, const Offset(0, 900), ms: 800);
    await back(after: 1000);

    // ───── 6. 자주 쓰는 대여소: 지도에서 누르기 → 바텀시트 카드 → 넣기, 검색으로 넣기 ─────
    await tap(find.text('더보기'), after: 1500);
    await tapRow('자주 쓰는 대여소', after: 3000);
    await tapPin(alert: false, after: 2500);
    await tap(find.text('내 대여소에 넣기'), after: 2200);
    await tap(find.byTooltip('닫기'), after: 1200);
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
    await tap(find.text('내 대여소에 넣기'), after: 2200);
    await tap(find.textContaining('즐겨찾기 '), after: 2500);
    await back(after: 1500);

    // ───── 7. 이용 시간과 알림: 습관 알림 켜기 → 조회 기록(이용 시간) → 실제 알림 ─────
    await tapRow('이용 시간과 알림', after: 1800);
    await tap(find.byType(Switch), after: 2500);
    await back(after: 1200);
    // 백그라운드 작업(15분마다)이 하는 확인을 지금 한 번 돌린다 — 조건이 맞으면 진짜 알림이 뜬다.
    await deliverHabitNotification();
    debugPrint(
      'DEMO notification sent: ${await HabitNotificationStore().lastSent()}',
    );
    await hold(6000);
    await tapRow('조회 기록', after: 3500);
    await back(after: 1200);

    // ───── 8. 화면 모드: 어두운 화면 → 홈 → 밝은 화면 ─────
    await tapRow('화면 모드', after: 300);
    await tap(find.byType(Switch), after: 2200);
    await tap(find.text('홈'), after: 3500);
    await tap(find.text('더보기'), after: 1500);
    await tapRow('화면 모드', after: 300);
    await tap(find.byType(Switch), after: 2000);

    // ───── 9. 이용 목적 바꾸기 → 관리 직원, 담당 구 고르기 ─────
    await tapRow('이용 목적 바꾸기', after: 1500);
    await tap(find.text('바꾸기'), after: 3000);
    await tap(find.text('서초구'), after: 700);
    await tap(find.text('이 구부터 보기'), after: 6000);

    // 오늘 추천 경로: 재배치 + 고장 의심 ↔ 고장 의심만
    await swipe(find.text('오늘 추천 경로'), const Offset(0, -250));
    await hold(2000);
    await tap(find.text('고장 의심만'), after: 4500);
    await tap(find.text('재배치 + 고장 의심'), after: 4500);

    // ───── 10. 길안내: 실제 도로를 따라 움직인다 ─────
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
      while (last >= 0 && stop < math.min(1, stops.length)) {
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
    now = here;
    moving.add(now);

    // ───── 11. 구별 현황 → 구 → 자전거(타 봐야 아는 고장) ─────
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
    await back(after: 1500);

    // ───── 12. 직원 더보기: 담당 구 바꾸기(강남구 더하기) → 화면 모드 → 시민으로 ─────
    await tap(find.text('더보기'), after: 1500);
    await tapRow('담당 구', after: 1800);
    await tap(find.text('강남구'), after: 900);
    await tap(find.text('이 구부터 보기'), after: 2500);
    await tap(find.text('구별 현황'), after: 3500);
    await tap(find.text('더보기'), after: 1500);
    await tapRow('화면 모드', after: 300);
    await tap(find.byType(Switch), after: 2500);
    await tap(find.byType(Switch), after: 1800);
    await tapRow('이용 목적 바꾸기', after: 1500);
    await tap(find.text('바꾸기'), after: 4000);
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
