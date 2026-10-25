import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
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
    });
  });

  Future<void> pumpRidey(WidgetTester tester) async {
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        readLocation: () async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows only rider tabs', (tester) async {
    await pumpRidey(tester);

    expect(find.text('이용하기'), findsOneWidget);
    expect(find.text('번호 확인'), findsOneWidget);
    expect(find.text('대여소'), findsOneWidget);
    expect(find.text('더보기'), findsOneWidget);
    expect(find.text('타기 전,\n확인하세요.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('내 대여소'), 400);
    expect(find.text('내 대여소'), findsOneWidget);
    expect(find.text('힐스테이트에코'), findsOneWidget);
    expect(find.text('1대'), findsOneWidget);
    for (final label in _staffLabels) {
      expect(find.text(label), findsNothing);
    }

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_purpose'), isNull);
    expect(preferences.getString('field_verification_queue'), isNull);
    expect(preferences.getStringList('my_stations'), ['02720']);
  });

  testWidgets('keeps a bike lookup in on-device history', (tester) async {
    await pumpRidey(tester);
    await tester.tap(find.text('자전거 확인하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spb-69683');
    await tester.tap(find.text('경보 기록 확인'));
    await tester.pumpAndSettle();

    expect(find.text('피하세요.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
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

    await tester.tap(find.text('자전거 확인하기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spb-69683');
    await tester.tap(find.text('경보 기록 확인'));
    await tester.pumpAndSettle();

    expect(find.text('피하세요.'), findsOneWidget);
    expect(find.text('왜 경보가 켜졌나요?'), findsOneWidget);
    expect(find.text('현장에서 확인하기'), findsNothing);
  });

  testWidgets('labels a missing alert as no repeated-return signal', (
    tester,
  ) async {
    await pumpRidey(tester);

    await tester.tap(find.text('번호 확인'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spb-12345');
    await tester.tap(find.text('경보 기록 확인'));
    await tester.pumpAndSettle();

    expect(find.text('경보 없음'), findsOneWidget);
    expect(find.textContaining('안전이 확인된 것은 아니니'), findsOneWidget);
  });

  testWidgets('opens saved stations from the rider tab', (tester) async {
    await pumpRidey(tester);
    await tester.tap(find.text('대여소'));
    await tester.pumpAndSettle();

    expect(find.text('내 대여소'), findsOneWidget);
    expect(find.text('힐스테이트에코'), findsOneWidget);
    for (final label in _staffLabels) {
      expect(find.text(label), findsNothing);
    }
  });
}
