import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/features/field/field_verdict.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';

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
  Future<List<BikeStation>> fetch() async => const [];
}

void main() {
  testWidgets('switches between the shared app destinations', (tester) async {
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        fieldRepository: _emptyFieldRepository(),
      ),
    );

    expect(find.text('타기 전에,\n확인하세요.'), findsOneWidget);
    expect(find.text('업무'), findsOneWidget);

    await tester.tap(find.text('업무'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 먼저\n볼 곳.'), findsOneWidget);

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('화면 모드'), findsOneWidget);
  });

  testWidgets('changes the app appearance from settings', (tester) async {
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        fieldRepository: _emptyFieldRepository(),
      ),
    );
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Switch))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('opens an alert detail from a bike number', (tester) async {
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        fieldRepository: _emptyFieldRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('자전거 번호로 확인'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'spb-69683');
    await tester.tap(find.text('경보 기록 확인'));
    await tester.pumpAndSettle();

    expect(find.text('타지 마세요.'), findsOneWidget);
    expect(find.text('왜 경보가 켜졌나요?'), findsOneWidget);
  });

  testWidgets('shows field verification status without changing queue order', (
    tester,
  ) async {
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        fieldRepository: FieldVerificationRepository(
          remote: _FakeFieldRemote(),
          queue: _MemoryFieldQueue(),
        ),
      ),
    );
    await tester.tap(find.text('업무'));
    await tester.pumpAndSettle();

    expect(find.textContaining('현장 확인 1대'), findsOneWidget);
  });
}

FieldVerificationRepository _emptyFieldRepository() {
  return FieldVerificationRepository(
    remote: _FakeFieldRemote(),
    queue: _MemoryFieldQueue(),
  );
}

class _FakeFieldRemote implements FieldVerificationRemote {
  @override
  Future<CheckedVerdicts> fetchChecked() async => {
    'SPB-69683': {FieldVerdict.tire: 1},
  };

  @override
  Future<void> record(FieldVerificationRecord record) async {}
}

class _MemoryFieldQueue implements FieldVerificationQueue {
  @override
  Future<List<FieldVerificationRecord>> load() async => const [];

  @override
  Future<void> save(List<FieldVerificationRecord> records) async {}
}
