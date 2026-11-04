// Every visible button on every screen must be reachable on an iPhone:
// not under the status bar / Dynamic Island, and the tap must land on it.
// (A real-phone report: the back button on the bike detail page sat under the
// status bar and could not be tapped.)
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/notifications/nearby_alert_reminder.dart';
import 'package:ridey_app/features/ops/ops_list.dart';
import 'package:ridey_app/features/ops/ops_list_repository.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _top = 59.0, _bottom = 34.0, _w = 390.0, _h = 844.0;

class _Live implements LiveSnapshotRepository {
  @override
  Future<LiveSnapshot> fetch() async => LiveSnapshot(
    updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    date: '2026-11-04',
    feed: const FeedHealth(isHealthy: true),
    bikes: const [
      LiveBike(
        bike: 'SPB-69683',
        station: '02720',
        stationName: '힐스테이트에코',
        chain: 5,
        isHighAlert: true,
        lastDud: '11-04 08:02',
        probability: 48,
        reasons: [AlertReason(text: '서로 다른 5명이 연달아 반납', deltaPoints: 21)],
      ),
      LiveBike(
        bike: 'SPB-41207',
        station: '02720',
        stationName: '힐스테이트에코',
        chain: 2,
        isHighAlert: false,
        lastDud: '11-04 07:40',
        probability: 31,
      ),
    ],
  );
}

class _Stations implements StationRepository {
  @override
  Future<List<BikeStation>> fetch() async => const [
    BikeStation(
      id: '02720',
      name: '힐스테이트에코',
      district: '강서구',
      latitude: 37.5600,
      longitude: 126.8370,
    ),
  ];
}

class _Ops implements OpsListRepository {
  @override
  Future<List<OpsScore>> scores() async => const [
    OpsScore(day: '2026-11-03', listed: 79, rode: 58, firstDud: 28),
    OpsScore(day: '2026-11-02', listed: 32, rode: 26, firstDud: 10),
  ];
  @override
  Future<List<String>> days() async => const [];
  @override
  Future<OpsList> fetch(String day) async => OpsList(day: day, bikes: const []);
}

void main() {
  Future<void> open(WidgetTester tester, Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(_w * 3, _h * 3);
    tester.view.padding = const FakeViewPadding(
      top: _top * 3,
      bottom: _bottom * 3,
    );
    tester.view.viewPadding = const FakeViewPadding(
      top: _top * 3,
      bottom: _bottom * 3,
    );
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _Live(),
        stationRepository: _Stations(),
        opsListRepository: _Ops(),
        readLocation: () async => (latitude: 37.5610, longitude: 126.8350),
        enableCamera: false,
        nearbyAlertReminder: const SilentNearbyAlertReminder(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 지금 화면에 보이는 모든 눌리는 것을 검사한다.
  List<String> problems(WidgetTester tester, String screen, {Finder? within}) {
    final out = <String>[];
    final all = find.byWidgetPredicate(
      (w) =>
          (w is IconButton && w.onPressed != null) ||
          (w is ButtonStyleButton && w.onPressed != null) ||
          (w is InkWell && w.onTap != null) ||
          (w is RideyPressable && w.onTap != null) ||
          (w is ChoiceChip && w.onSelected != null),
    );
    // 떠 있는 카드(모달)가 열려 있으면 뒤쪽은 일부러 막혀 있다 — 카드 안만 본다.
    final tappables = within == null
        ? all
        : find.descendant(of: within, matching: all);
    for (final element in tappables.evaluate()) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      // 화면 밖(스크롤해야 보이는 것)은 건너뛴다.
      if (rect.bottom <= 0 ||
          rect.top >= _h ||
          rect.right <= 0 ||
          rect.left >= _w) {
        continue;
      }
      final center = rect.center;
      // 떠 있는 탭 막대 뒤로 지나가는 목록 줄은 스크롤하면 닿는다 — 탭 막대 자신만 본다.
      final underTabBar = center.dy > _h - _bottom - 76;
      final label =
          '${element.widget.runtimeType} '
          '"${_text(element)}" @(${center.dx.round()},${center.dy.round()})';
      if (rect.top < _top - 1) out.add('$screen: under the status bar: $label');
      final hit = HitTestResult();
      tester.binding.hitTestInView(hit, center, tester.view.viewId);
      final reached = hit.path.any((e) => e.target == box);
      if (!reached && !underTabBar) {
        out.add('$screen: tap does not reach: $label');
      }
    }
    return out;
  }

  /// 목록 안의 것을 화면 가운데로 끌어온다(떠 있는 탭 막대·머리에 가리지 않게).
  Future<void> center(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(finder.last), alignment: .5);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    final custom = find.byTooltip('뒤로');
    if (custom.evaluate().isNotEmpty) {
      await tester.tap(custom.last);
    } else {
      await tester.tap(find.byType(BackButton).last);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('rider screens: every button is reachable on an iPhone', (
    tester,
  ) async {
    await open(tester, {'user_mode': 'rider'});
    final found = <String>[];
    found.addAll(problems(tester, 'home'));
    await tapText(tester, '주변 대여소 현황');
    found.addAll(problems(tester, 'home stations'));
    // 지도에서 대여소를 누르면 뜨는 카드(길 찾기·대여하기 단추 포함)
    await tester.tap(find.bySemanticsLabel(RegExp('고장 의심 .*대가 있는 대여소')).first);
    await tester.pumpAndSettle();
    expect(find.text('길 찾기'), findsOneWidget);
    expect(find.textContaining('걸어서 약'), findsOneWidget);
    found.addAll(
      problems(tester, 'station card', within: find.byType(BottomSheet)),
    );
    await tester.tapAt(const Offset(_w / 2, 120));
    await tester.pumpAndSettle();

    await tapText(tester, '자전거 확인');
    found.addAll(problems(tester, 'check'));
    await tester.enterText(find.byType(TextField).first, 'spb-69683');
    await tapText(tester, '조회하기');
    found.addAll(problems(tester, 'detail'));
    // 맨 아래(고장 신고 단추)까지 내려야 '판단 근거' 가 떠 있는 탭 막대 위로 올라온다.
    await tester.scrollUntilVisible(
      find.text('고장 신고하기'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    // 찾자마자 멈추면 떠 있는 탭 막대 밑일 수 있다 — 끝까지 한 번 더 민다.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    found.addAll(problems(tester, 'detail bottom'));
    await tapText(tester, '판단 근거 자세히 보기');
    found.addAll(problems(tester, 'evidence'));
    await back(tester);
    // 내려가 있던 상세의 머리(뒤로 단추)는 목록이 다시 올라와야 생긴다.
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 800));
    await tester.pumpAndSettle();
    await back(tester);
    await tester.enterText(find.byType(TextField).first, 'spb-12345');
    await tapText(tester, '조회하기');
    found.addAll(problems(tester, 'no alert'));
    await back(tester);

    await tapText(tester, '더보기');
    found.addAll(problems(tester, 'more'));
    for (final item in ['자주 쓰는 대여소', '이용 시간과 알림', '조회 기록']) {
      await tapText(tester, item);
      found.addAll(problems(tester, item));
      await back(tester);
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });

  testWidgets('first launch: every button is reachable on an iPhone', (
    tester,
  ) async {
    await open(tester, {});
    final found = <String>[];
    found.addAll(problems(tester, 'first launch'));
    await tapText(tester, '따릉이를 이용하는 일반 시민이에요');
    found.addAll(problems(tester, 'location step'));
    // 맨 아래 단추는 홈 표시줄(아래 34pt)과 겹치면 안 된다.
    final last = tester.getRect(find.text('나중에, 대여소를 직접 고를게요'));
    if (last.bottom > _h - _bottom) {
      found.add('location step: under the home indicator');
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });

  testWidgets('staff screens: every button is reachable on an iPhone', (
    tester,
  ) async {
    await open(tester, {
      'user_mode': 'staff',
      'staff_districts': ['강서구'],
    });
    final found = <String>[];
    found.addAll(problems(tester, 'staff overview'));
    // 추천 경로 → 길안내(앱 안). 테스트엔 도로 길이 없어 직선으로 안내한다.
    expect(find.text('오늘 추천 경로'), findsOneWidget);
    // 시트를 끝까지 올리고, 그 안에서 단추가 탭 막대 위로 올 때까지 내린다.
    await tester.drag(find.text('오늘 추천 경로'), const Offset(0, -600));
    await tester.pumpAndSettle();
    await center(tester, find.text('길안내 시작'));
    // 시트를 끝까지 올리면 지도 단추는 시트 밑에 깔린다(일부러) — 시트 안만 본다.
    found.addAll(
      problems(
        tester,
        'staff route',
        within: find.byType(DraggableScrollableSheet),
      ),
    );
    await tapText(tester, '길안내 시작');
    found.addAll(problems(tester, 'staff navigation'));
    expect(find.textContaining('고장 의심 2대 수거'), findsWidgets);
    await tester.tap(find.byTooltip('길안내 끝내기'));
    await tester.pumpAndSettle();
    // 구별 현황의 구를 누르면 그 구의 대여소별 목록이 열린다.
    await tester.drag(find.text('오늘 추천 경로'), const Offset(0, -600));
    await tester.pumpAndSettle();
    await center(tester, find.text('강서구'));
    await tapText(tester, '강서구');
    found.addAll(problems(tester, 'staff district list'));
    await tapText(tester, 'SPB-69683');
    found.addAll(problems(tester, 'staff detail'));
    expect(find.text('목록으로 돌아가기'), findsOneWidget);
    await back(tester);
    await back(tester);
    await tapText(tester, '더보기');
    found.addAll(problems(tester, 'staff more'));
    expect(found, isEmpty, reason: found.join('\n'));
  });
}

String _text(Element element) {
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text) texts.add(w.data ?? '');
    if (w is Icon) texts.add('icon');
    e.visitChildren(visit);
  }

  visit(element);
  return texts.take(2).join('/');
}
