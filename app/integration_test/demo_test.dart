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
import 'package:flutter_map/flutter_map.dart';
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
    final slotStart = DateTime(
      clock.year,
      clock.month,
      clock.day,
      clock.hour,
    ).subtract(const Duration(days: 7));
    for (final m in const [1, 2]) {
      await LookupHabitStore().add(
        LookupEvent(
          kind: LookupKind.number,
          at: slotStart.add(Duration(minutes: m)),
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

    var myGu = '서초구';
    var nearestGu = double.infinity;
    for (final s in stations.values) {
      final d = metersBetween(
        here.latitude,
        here.longitude,
        s.latitude,
        s.longitude,
      );
      if (d < nearestGu && s.district.isNotEmpty) {
        nearestGu = d;
        myGu = s.district;
      }
    }
    debugPrint('DEMO gu $myGu pick ${pick.bike}');

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

    // 두 손가락으로 지도를 돌린다(실제 손가락처럼 조금씩). 돌린 뒤 '북쪽 위로' 로 되돌린다.
    Future<void> rotateMap(double degrees) async {
      final maps = find.byType(FlutterMap);
      await until(maps, seconds: 5);
      if (maps.evaluate().isEmpty) {
        debugPrint('DEMO skip rotate');
        return;
      }
      final box = tester.getRect(maps.first);
      final c = Offset(box.center.dx, box.top + box.height * 0.32);
      const r = 95.0;
      final g1 = await tester.startGesture(
        c + const Offset(-r, 0),
        pointer: 41,
      );
      final g2 = await tester.startGesture(c + const Offset(r, 0), pointer: 42);
      const steps = 40;
      for (var i = 1; i <= steps; i++) {
        final a = degrees * math.pi / 180 * i / steps;
        final o = Offset(math.cos(a) * r, math.sin(a) * r);
        await g1.moveTo(c - o);
        await g2.moveTo(c + o);
        await hold(28);
      }
      await g1.up();
      await g2.up();
      await hold(1800);
      await tap(find.byTooltip('북쪽 위로'), after: 1500, seconds: 3);
    }

    Widget app() => _TouchMarks(
      child: RideyApp(
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
    // ───── 1. 켤 때: R. → 점 → 서울, 이용 목적 묻기 ─────
    await tester.pumpWidget(app());
    await hold(5200);
    await tap(find.text('따릉이를 이용하는 일반 시민이에요'), after: 1600);
    await tap(find.text('위치 허용하기'), after: 3500);

    // ───── 2. 시민 홈: 바텀시트, 지도 두 손가락으로 돌리기 → 북쪽 위로, 고장 의심 ↔ 대여소 현황 ─────
    await swipe(find.byType(DraggableScrollableSheet), const Offset(0, -260));
    await hold(1200);
    await swipe(find.byType(DraggableScrollableSheet), const Offset(0, 260));
    await rotateMap(70);
    await tap(find.text('주변 대여소 현황'), after: 2200);
    await tap(find.text('고장 의심 따릉이'), after: 1400);

    // ───── 3. 가기 전에 미리: 검색 → 역 이름 → 그 근처 → 내 위치로 ─────
    await tap(pressable((l) => l == '장소 검색'), after: 900);
    await type('고속터미널');
    await hold(900);
    FocusManager.instance.primaryFocus?.unfocus();
    await hold(700);
    await tap(pressable((l) => l.endsWith('근처 보기')), after: 3500);
    await tap(find.text('내 위치로'), after: 2500);

    // ───── 4. 눈앞의 자전거: 화면 모드를 어둡게 → (여기에 친구가 찍은 실제 QR 장면이 들어간다)
    //        → 번호 → 경보 → 판단 근거 → '고장 신고하기'(보여 주기만) → 다시 밝게 ─────
    await tap(find.text('더보기'), after: 1500);
    await tapRow('화면 모드', after: 300);
    await tap(find.byType(Switch), after: 1800);
    await tap(find.text('자전거 확인'), after: 600);
    debugPrint('DEMO QR CUT');
    await hold(2500);
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
    await hold(2800);
    await swipe(find.byType(Scrollable).last, const Offset(0, 900), ms: 800);
    await back(after: 1000);

    await tap(find.text('더보기'), after: 1500);
    await tapRow('화면 모드', after: 300);
    await tap(find.byType(Switch), after: 1800);

    // ───── 5. 대여소 카드: 걸어서 몇 분 → 길 찾기(지도 앱) ─────
    await tap(find.text('홈'), after: 2000);
    await tapPin();
    await hold(1800);
    await tap(find.text('길 찾기'), after: 300);
    await awayAndBack('길 찾기');
    await hold(800);
    await tapPin();
    await hold(1500);
    // '대여하기' → 따릉이 앱이 열린다. 따릉이 앱 안의 장면(대여소 고르기 → 타기 → 결제 직전)은
    // 사람이 직접 찍은 영상을 이 자리에 붙인다.
    debugPrint('DEMO RENT CUT');
    await tap(find.text('대여하기'), after: 300);
    await awayAndBack('대여하기');
    await hold(800);

    // ───── 6. 내 대여소: 지도에서 누르기 → 넣기, 검색으로 넣기 ─────
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
    await back(after: 1500);

    // ───── 7. 이용 시간과 알림: 켜기 → 실제 알림 받기 → 조회 기록 ─────
    await tapRow('이용 시간과 알림', after: 1800);
    await tap(find.byType(Switch), after: 2500);
    await back(after: 1200);
    // 백그라운드 작업(15분마다)이 하는 확인을 지금 한 번 돌린다 — 조건이 맞으면 진짜 알림이 뜬다.
    // 실제 알림 화면은 따로 찍은 스크린샷을 이 자리에 넣는다.
    await hold(1500);
    await tapRow('조회 기록', after: 3500);
    await back(after: 1200);

    // ───── 8. 알림 · 다이내믹 아일랜드: 따로 찍은 스크린샷을 이 자리에 넣는다 ─────
    debugPrint('DEMO NOTICE CUT');

    // ───── 9. 이용 목적 바꾸기 → 관리 직원, 담당 구 고르기 ─────
    await tapRow('이용 목적 바꾸기', after: 1500);
    await tap(find.text('바꾸기'), after: 3000);
    await tap(find.text(myGu), after: 700);
    await tap(find.text('이 구부터 보기'), after: 6000);
    await rotateMap(-60);

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
    // 손가락으로 천천히 끌어 내려가며 '길안내 시작' 을 찾는다(순간 이동처럼 보이지 않게).
    for (var k = 0; k < 6; k++) {
      final b = find.text('길안내 시작');
      if (b.evaluate().isNotEmpty) {
        final r = tester.getRect(b.first);
        final h =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        if (r.bottom < h - 120) break;
      }
      if (sheet.evaluate().isEmpty) break;
      await tester.timedDrag(
        sheet.first,
        const Offset(0, -260),
        const Duration(milliseconds: 1100),
      );
      await hold(700);
    }
    await hold(1200);
    await tap(find.text('길안내 시작'), after: 600);
    debugPrint('DEMO NAV IN');
    await hold(1900);
    // 길을 따라 빨리 감기(멀리서는 45m, 대여소 가까이서는 10m씩). 대여소 30m 안이면 그 자리에 서서
    // '다음 곳으로' 를 누른다 — 지도의 점이 체크로 바뀌고 '이번 길' 대수가 쌓인다. 세 곳까지.
    final road = router.last;
    final targets = router.stops.length > 1
        ? router.stops.sublist(1)
        : const <LatLng>[];
    var done = 0;
    if (road != null && road.points.length > 1) {
      Future<void> finishStop() async {
        await until(find.text('다음 곳으로'), seconds: 3);
        await hold(2200);
        await tap(find.text('다음 곳으로'), after: 2000);
        done++;
      }

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
          now = (latitude: target.latitude, longitude: target.longitude);
          moving.add(now);
          await hold(400);
          await finishStop();
          closest = double.infinity;
          continue;
        }
        if (away < closest) closest = away;
        along += away < 160 ? 10 : 45;
        var d = metersBetween(
          road.points[i].latitude,
          road.points[i].longitude,
          road.points[i + 1].latitude,
          road.points[i + 1].longitude,
        );
        while (along > d && i < road.points.length - 2) {
          along -= d;
          i++;
          d = metersBetween(
            road.points[i].latitude,
            road.points[i].longitude,
            road.points[i + 1].latitude,
            road.points[i + 1].longitude,
          );
        }
        final p = road.points[i], q = road.points[i + 1];
        final f = d == 0 ? 1.0 : (along / d).clamp(0.0, 1.0);
        now = (
          latitude: p.latitude + (q.latitude - p.latitude) * f,
          longitude: p.longitude + (q.longitude - p.longitude) * f,
        );
        moving.add(now);
        await hold(100);
      }
    }
    await hold(1500);
    debugPrint('DEMO NAV OUT');
    await hold(1500);
    await tap(find.byTooltip('길안내 끝내기'), after: 1500);
    now = here;
    moving.add(now);

    // ───── 11. 구별 현황 → 구 → 자전거(타 봐야 아는 고장) ─────
    await swipe(find.text('오늘 추천 경로'), const Offset(0, -300));
    try {
      await tester.scrollUntilVisible(
        find.text(myGu),
        150,
        scrollable: sheet.first,
      );
    } catch (_) {
      debugPrint('DEMO skip scroll');
    }
    await hold(800);
    await tap(find.text(myGu), after: 2500);
    await tap(find.textContaining('SPB-').first, after: 3500);
    await tap(find.text('목록으로 돌아가기'), after: 1200);
    await back(after: 1500);
    await hold(2500);
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

/// 누른 자리를 보여 주는 표시(화면 녹화의 '터치 표시' 처럼). 시연 영상에서만 쓴다.
class _TouchMarks extends StatefulWidget {
  const _TouchMarks({required this.child});

  final Widget child;

  @override
  State<_TouchMarks> createState() => _TouchMarksState();
}

class _TouchMarksState extends State<_TouchMarks> {
  final Map<int, Offset> _down = {};
  final List<(Offset, DateTime)> _fading = [];
  Timer? _timer;

  static const _fade = Duration(milliseconds: 450);

  void _tick() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = DateTime.now();
      _fading.removeWhere((f) => now.difference(f.$2) > _fade);
      if (_fading.isEmpty && _down.isEmpty) {
        _timer?.cancel();
        _timer = null;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _down[e.pointer] = e.position;
        _tick();
      },
      onPointerMove: (e) {
        if (_down.containsKey(e.pointer)) _down[e.pointer] = e.position;
      },
      onPointerUp: (e) {
        final at = _down.remove(e.pointer) ?? e.position;
        _fading.add((at, DateTime.now()));
        _tick();
      },
      onPointerCancel: (e) => _down.remove(e.pointer),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TouchPainter(
                    down: _down.values.toList(),
                    fading: [
                      for (final f in _fading)
                        (
                          f.$1,
                          (DateTime.now().difference(f.$2).inMilliseconds /
                                  _fade.inMilliseconds)
                              .clamp(0.0, 1.0),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TouchPainter extends CustomPainter {
  _TouchPainter({required this.down, required this.fading});

  final List<Offset> down;
  final List<(Offset, double)> fading;

  void _mark(Canvas canvas, Offset at, double radius, double alpha) {
    canvas.drawCircle(
      at,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.55 * alpha),
    );
    canvas.drawCircle(
      at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.28 * alpha),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in down) {
      _mark(canvas, p, 24, 1);
    }
    for (final (p, t) in fading) {
      _mark(canvas, p, 24 + 14 * t, 1 - t);
    }
  }

  @override
  bool shouldRepaint(_TouchPainter old) => true;
}
