import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/live/station_status.dart';
import 'package:ridey_app/features/live/station_status_repository.dart';
import 'package:ridey_app/features/notifications/nearby_alert_reminder.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLiveSnapshotRepository implements LiveSnapshotRepository {
  @override
  Future<LiveSnapshot> fetch() async {
    return LiveSnapshot(
      updatedAt: DateTime(2026, 10, 20, 15),
      date: '2026-10-20',
      bikes: const [
        LiveBike(
          bike: 'SPB-69683',
          station: '02720',
          stationName: '힐스테이트에코',
          chain: 3,
          isHighAlert: true,
          lastDud: '10-20 14:58',
          probability: 48,
        ),
      ],
      feed: const FeedHealth(isHealthy: true),
    );
  }
}

class _FakeStationStatusRepository implements StationStatusRepository {
  @override
  Future<List<StationOccupancy>> fetch() async => const [
    StationOccupancy(id: '02720', name: '힐스테이트에코', bikes: 4, racks: 10),
  ];
}

class _FakeStationRepository implements StationRepository {
  @override
  Future<List<BikeStation>> fetch() async => const [
    BikeStation(
      id: '02720',
      name: '힐스테이트에코',
      district: '강남구',
      latitude: 37.5,
      longitude: 127.0,
    ),
  ];
}

const _staffLabels = ['업무', '현장 기록', '목적 전환', '대여소 작업', '오늘의 작업'];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'app_purpose': 'worker',
      'field_verification_queue': '[]',
      'my_stations': ['02720'],
      'user_mode': 'rider',
    });
  });

  Future<void> pumpRidey(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        stationStatusRepository: _FakeStationStatusRepository(),
        readLocation: () async => null,
        enableCamera: false,
        openOfficialApp: () async {},
        nearbyAlertReminder: const SilentNearbyAlertReminder(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows only rider tabs', (tester) async {
    await pumpRidey(tester);

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('자전거 확인'), findsOneWidget);
    expect(find.text('더보기'), findsOneWidget);
    expect(find.text('이용하기'), findsNothing);
    expect(find.text('번호 확인'), findsNothing);
    expect(find.textContaining('저장한 대여소에'), findsOneWidget);
    expect(find.textContaining('1대'), findsOneWidget);
    expect(find.text('SPB-69683'), findsOneWidget);
    expect(find.textContaining('힐스테이트에코'), findsOneWidget);
    expect(find.text('고장 의심 따릉이'), findsOneWidget);
    expect(find.text('주변 대여소 현황'), findsOneWidget);
    for (final label in _staffLabels) {
      expect(find.text(label), findsNothing);
    }

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_purpose'), isNull);
    expect(preferences.getString('field_verification_queue'), isNull);
    expect(preferences.getStringList('my_stations'), ['02720']);
    expect(preferences.getString('user_mode'), 'rider');
  });

  testWidgets('keeps a bike lookup in on-device history', (tester) async {
    await pumpRidey(tester);
    await tester.tap(find.text('자전거 확인'));
    await tester.pumpAndSettle();
    expect(find.text('조회하기'), findsOneWidget);
    expect(find.text('QR로 찍기'), findsOneWidget);
    expect(find.text('자전거 번호 직접 입력하기'), findsNothing);
    await tester.enterText(find.byType(TextField), 'spb-69683');
    await tester.tap(find.text('조회하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('경보가 켜졌어요.'), findsOneWidget);
    await tester.ensureVisible(find.text('다른 자전거 확인하기'));
    await tester.tap(find.text('다른 자전거 확인하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('조회 기록'));
    await tester.pumpAndSettle();

    expect(find.text('번호 조회'), findsOneWidget);
    expect(find.textContaining('SPB-69683'), findsOneWidget);
    expect(find.textContaining('위치 없음'), findsOneWidget);

    await tester.tap(find.text('기록 지우기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('아직 조회 기록이 없어요.'), findsOneWidget);
    expect(find.text('번호 조회'), findsNothing);
  });

  testWidgets('changes the app appearance from settings', (tester) async {
    await pumpRidey(tester);
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('전송 대기 중인 현장 확인'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Switch))).brightness,
      Brightness.dark,
    );
    for (final label in _staffLabels) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('opens an alert detail from a bike number', (tester) async {
    await pumpRidey(tester);

    await tester.tap(find.text('자전거 확인'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spb-69683');
    await tester.tap(find.text('조회하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('경보가 켜졌어요.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('판단 근거 자세히 보기'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(BikeDetailPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('판단 근거 자세히 보기'));
    await tester.pumpAndSettle();
    expect(find.text('왜 경보가 켜졌나요?'), findsOneWidget);
    expect(find.text('현장에서 확인하기'), findsNothing);
  });

  testWidgets('labels a missing alert as no repeated-return signal', (
    tester,
  ) async {
    await pumpRidey(tester);

    await tester.tap(find.text('자전거 확인'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spb-12345');
    await tester.tap(find.text('조회하기'));
    await tester.pumpAndSettle();

    expect(find.text('경보 없음'), findsOneWidget);
    expect(find.textContaining('안전이 확인된 것은 아니니'), findsOneWidget);
    expect(find.text('따릉이 앱에서 대여하기'), findsOneWidget);
  });

  testWidgets('lists nearby stations instead of bike numbers', (tester) async {
    await pumpRidey(tester);
    await tester.tap(find.text('주변 대여소 현황'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1대'), findsWidgets);
    expect(find.text('SPB-69683'), findsNothing);
    expect(find.textContaining('고장 의심 1 / 선택 가능 약 3'), findsOneWidget);
    expect(find.text('따릉이 앱에서 대여하기'), findsOneWidget);
  });

  testWidgets('opens saved stations from the rider tab', (tester) async {
    await pumpRidey(tester);
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자주 쓰는 대여소'));
    await tester.pumpAndSettle();

    expect(find.text('내 대여소'), findsOneWidget);
    expect(find.text('힐스테이트에코'), findsOneWidget);
    for (final label in _staffLabels) {
      expect(find.text(label), findsNothing);
    }
  });
}
