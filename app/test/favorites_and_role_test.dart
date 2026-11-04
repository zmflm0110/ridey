// 내 대여소: 검색 결과를 누르면 지도에서 자리만 보여 주고, '넣기' 를 눌러야 들어간다.
// 켤 때마다 역할을 묻는다(지난번 고른 것은 표시만).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/seoul_hero.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/notifications/nearby_alert_reminder.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/saved_stations_page.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Live implements LiveSnapshotRepository {
  @override
  Future<LiveSnapshot> fetch() async => LiveSnapshot(
    updatedAt: DateTime.now(),
    date: '2026-11-04',
    feed: const FeedHealth(isHealthy: true),
    bikes: const [
      LiveBike(
        bike: 'SPB-11111',
        station: '00102',
        stationName: '망원역 1번출구 앞',
        chain: 3,
        isHighAlert: true,
        lastDud: '11-04 08:00',
        probability: 40,
      ),
    ],
  );
}

class _Stations implements StationRepository {
  @override
  Future<List<BikeStation>> fetch() async => const [
    BikeStation(
      id: '00102',
      name: '망원역 1번출구 앞',
      district: '마포구',
      latitude: 37.5556,
      longitude: 126.9106,
    ),
    BikeStation(
      id: '00103',
      name: '망원역 2번출구 앞',
      district: '마포구',
      latitude: 37.5549,
      longitude: 126.9108,
    ),
  ];
}

void main() {
  testWidgets('a search result shows its place; only 넣기 adds it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: RideyTheme.light(),
        home: SavedStationsDestination(
          liveRepository: _Live(),
          stationRepository: _Stations(),
          readLocation: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기 0/5'), findsOneWidget);

    await tester.tap(find.text('대여소 검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '망원');
    await tester.pumpAndSettle();
    await tester.tap(find.text('망원역 1번출구 앞').last);
    await tester.pumpAndSettle();
    // 누르기만 했을 때: 지도에 자리(선택 카드)가 나오고 아직 저장 안 됨.
    expect(find.text('내 대여소에 넣기'), findsOneWidget);
    expect(find.textContaining('고장 의심 1대'), findsOneWidget);
    expect(await SavedStationsStore().load(), isEmpty);

    await tester.tap(find.text('넣기').first);
    await tester.pumpAndSettle();
    expect(await SavedStationsStore().load(), ['00102']);
    expect(find.text('즐겨찾기 1/5'), findsOneWidget);
  });

  testWidgets('asks the role on every launch and shows the last one', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'user_mode': 'staff'});
    await tester.pumpWidget(
      RideyApp(
        askRoleOnLaunch: true,
        liveRepository: _Live(),
        stationRepository: _Stations(),
        readLocation: () async => null,
        enableCamera: false,
        nearbyAlertReminder: const SilentNearbyAlertReminder(),
      ),
    );
    // 켤 때마다 '점 하나 → 서울' 장면부터(처음 한 번만이 아니라).
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SeoulHero), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('따릉이를 이용하는 일반 시민이에요'), findsOneWidget);
    expect(find.text('지난번엔 관리 직원으로 썼어요'), findsOneWidget);
    // 시민을 고르면 위치 안내를 다시 보이지 않고 바로 홈으로.
    await tester.tap(find.text('따릉이를 이용하는 일반 시민이에요'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('위치 허용하기'), findsNothing);
    expect(find.text('자전거 확인'), findsOneWidget);
  });
}
