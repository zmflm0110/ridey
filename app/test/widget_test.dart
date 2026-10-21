import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/app_purpose.dart';
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
  testWidgets('changes navigation destinations with the selected purpose', (
    tester,
  ) async {
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        fieldRepository: _emptyFieldRepository(),
        purposeStore: _MemoryPurposeStore(AppPurpose.rider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('타기 전에,\n확인하세요.'), findsOneWidget);
    expect(find.text('번호 확인'), findsOneWidget);

    await tester.tap(find.byTooltip('목적 전환'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('업무').last);
    await tester.pumpAndSettle();

    expect(find.text('대여소 작업'), findsOneWidget);
    expect(find.text('오늘\n처리할 일.'), findsOneWidget);

    await tester.tap(find.text('대여소 작업'));
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
        purposeStore: _MemoryPurposeStore(AppPurpose.rider),
      ),
    );
    await tester.pumpAndSettle();
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
        purposeStore: _MemoryPurposeStore(AppPurpose.rider),
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
        purposeStore: _MemoryPurposeStore(AppPurpose.worker),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('대여소 작업'));
    await tester.pumpAndSettle();

    expect(find.textContaining('현장 확인 1대'), findsOneWidget);
  });

  testWidgets('stores an onboarding purpose and lets users change it later', (
    tester,
  ) async {
    final purposeStore = _MemoryPurposeStore(null);
    await tester.pumpWidget(
      RideyApp(
        liveRepository: _FakeLiveSnapshotRepository(),
        stationRepository: _FakeStationRepository(),
        fieldRepository: _emptyFieldRepository(),
        purposeStore: purposeStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('타기 전,\n한 번 확인하세요.'), findsOneWidget);
    await tester.tap(find.text('업무 화면 보기').first);
    await tester.pumpAndSettle();

    expect(purposeStore.value, AppPurpose.worker);
    expect(find.text('오늘\n처리할 일.'), findsOneWidget);

    await tester.tap(find.byTooltip('목적 전환'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이용자').last);
    await tester.pumpAndSettle();

    expect(purposeStore.value, AppPurpose.rider);
    expect(find.text('타기 전에,\n확인하세요.'), findsOneWidget);
  });
}

class _MemoryPurposeStore implements AppPurposeStore {
  _MemoryPurposeStore(this.value);

  AppPurpose? value;

  @override
  Future<AppPurpose?> load() async => value;

  @override
  Future<void> save(AppPurpose purpose) async {
    value = purpose;
  }
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
