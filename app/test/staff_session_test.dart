import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/ops/ops_list.dart';
import 'package:ridey_app/features/ops/ops_list_repository.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_districts.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

LiveBike _bike(String id) => LiveBike(
  bike: id,
  station: '02720',
  stationName: '힐스테이트에코',
  chain: 2,
  isHighAlert: false,
  lastDud: '10-20 14:58',
  probability: null,
);

class _Live implements LiveSnapshotRepository {
  @override
  Future<LiveSnapshot> fetch() async => LiveSnapshot(
    updatedAt: DateTime.utc(2026, 10, 20, 6),
    date: '2026-10-20',
    bikes: [_bike('SPB-00001')],
    feed: const FeedHealth(isHealthy: false),
    isOffline: true,
  );
}

class _Ops implements OpsListRepository {
  Completer<OpsList>? pending;
  var fail = false;

  @override
  Future<List<String>> days() async => const ['2026-10-20'];

  @override
  Future<OpsList> fetch(String day) {
    if (fail) return Future.error(Exception('timeout'));
    pending = Completer<OpsList>();
    return pending!.future;
  }
}

class _Stations implements StationRepository {
  @override
  Future<List<BikeStation>> fetch() async => const [
    BikeStation(
      id: '02720',
      name: '힐스테이트에코',
      district: '강서구',
      latitude: 37.56,
      longitude: 126.83,
    ),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 서울 15:00 — 아침 목록이 기본이 아닌 시간
  final afternoon = DateTime.utc(2026, 10, 20, 6);

  StaffSession session(_Ops ops) => StaffSession(
    liveRepository: _Live(),
    opsRepository: ops,
    stationRepository: _Stations(),
    districtsStore: const StaffDistrictsStore(),
    now: afternoon,
  );

  test('a failed switch keeps the old source label with its bikes', () async {
    final ops = _Ops()..fail = true;
    final s = session(ops);
    await s.reload();
    expect(s.source, ListSource.live);
    expect(s.bikes.single.bike, 'SPB-00001');

    await s.setSource(ListSource.morning);
    expect(s.error, isNotNull);
    expect(s.source, ListSource.live);
    expect(s.bikes.single.bike, 'SPB-00001');
  });

  test('a late reply from an older switch is dropped', () async {
    final ops = _Ops();
    final s = session(ops);
    final morning = s.setSource(ListSource.morning);
    await Future<void>.delayed(Duration.zero);
    final first = ops.pending!;
    await s.setSource(ListSource.live);
    first.complete(OpsList(day: '2026-10-20', bikes: [_bike('SPB-99999')]));
    await morning;
    expect(s.source, ListSource.live);
    expect(s.bikes.single.bike, 'SPB-00001');
  });

  test('keeps the data age and feed state for the detail page', () async {
    final s = session(_Ops());
    await s.setSource(ListSource.live);
    expect(s.updatedAt, DateTime.utc(2026, 10, 20, 6));
    expect(s.feed?.isHealthy, isFalse);
  });

  test('leaving the list clears a district picked on the overview', () {
    final s = session(_Ops())..focusDistrict('강남구');
    s.clearFocus();
    expect(s.focusedDistrict, isNull);
  });
}
