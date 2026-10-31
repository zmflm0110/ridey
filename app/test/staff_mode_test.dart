import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/ops/ops_list.dart';
import 'package:ridey_app/features/ops/ops_list_repository.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLive implements LiveSnapshotRepository {
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

class _FakeStations implements StationRepository {
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

class _FakeOps implements OpsListRepository {
  @override
  Future<List<String>> days() async => const ['2026-10-19'];

  @override
  Future<OpsList> fetch(String day) async {
    return OpsList(
      day: day,
      bikes: const [
        LiveBike(
          bike: 'SPB-11111',
          station: '02720',
          stationName: '힐스테이트에코',
          chain: 2,
          isHighAlert: false,
          lastDud: '10-19 07:00',
          probability: null,
        ),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(
    RideyApp(
      liveRepository: _FakeLive(),
      stationRepository: _FakeStations(),
      opsListRepository: _FakeOps(),
      readLocation: () async => null,
      enableCamera: false,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('asks for a purpose on the first launch', (tester) async {
    await _pump(tester);

    expect(find.textContaining('어떤 목적으로 이용하실 건가요'), findsOneWidget);
    expect(find.text('따릉이를 이용하는 일반 시민이에요'), findsOneWidget);
    expect(find.text('따릉이를 수거하고 점검하는 관리 직원이에요'), findsOneWidget);

    await tester.tap(find.text('나중에 할게요'));
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('자전거 확인'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('user_mode'), 'rider');
  });

  testWidgets('opens the staff shell without rider tools', (tester) async {
    await _pump(
      tester,
      prefs: {
        'user_mode': 'staff',
        'staff_districts': ['강남구'],
      },
    );

    expect(find.text('구별 현황'), findsWidgets);
    expect(find.text('목록'), findsOneWidget);
    expect(find.text('더보기'), findsOneWidget);
    expect(find.text('홈'), findsNothing);
    expect(find.text('자전거 확인'), findsNothing);
    expect(find.text('강남구'), findsOneWidget);
    expect(find.textContaining('1대'), findsWidgets);

    await tester.tap(find.text('더보기').last);
    await tester.pumpAndSettle();
    expect(find.text('이용 목적 바꾸기'), findsOneWidget);
    expect(find.text('이용 시간과 알림'), findsNothing);
    expect(find.text('조회 기록'), findsNothing);
    expect(find.text('QR로 찍기'), findsNothing);
  });

  testWidgets('keeps assigned districts after a mode switch', (tester) async {
    await _pump(
      tester,
      prefs: {
        'user_mode': 'staff',
        'staff_districts': ['강남구'],
      },
    );

    await tester.tap(find.text('더보기').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('이용 목적 바꾸기'));
    await tester.pumpAndSettle();
    expect(find.text('시민 모드로 바꿀까요?'), findsOneWidget);
    await tester.tap(find.text('바꾸기'));
    await tester.pumpAndSettle();

    expect(find.text('홈'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('user_mode'), 'rider');
    expect(preferences.getStringList('staff_districts'), ['강남구']);
  });
}
