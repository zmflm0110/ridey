// 직원의 '들를 순서'·아침 목록 성적.
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/ops/ops_list.dart';
import 'package:ridey_app/features/ops/ops_list_repository.dart';
import 'package:ridey_app/features/reports/citizen_reports.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 내 위치에서 동쪽으로 한 줄: A(300m) — B(600m) — C(900m), 강한 경보 D 는 서쪽 400m.
const _here = (latitude: 37.5600, longitude: 127.0000);
double _east(double m) => 127.0 + m / (111320 * 0.7923);

LiveBike _bike(String id, String station, {bool high = false}) => LiveBike(
  bike: id,
  station: station,
  stationName: station,
  chain: 2,
  isHighAlert: high,
  lastDud: '11-04 08:00',
  probability: null,
);

class _Live implements LiveSnapshotRepository {
  _Live(this.bikes);
  final List<LiveBike> bikes;
  @override
  Future<LiveSnapshot> fetch() async => LiveSnapshot(
    updatedAt: DateTime(2026, 11, 4, 9),
    date: '2026-11-04',
    bikes: bikes,
    feed: const FeedHealth(isHealthy: true),
  );
}

class _Stations implements StationRepository {
  @override
  Future<List<BikeStation>> fetch() async => [
    for (final (id, m) in [
      ('A', 300.0),
      ('B', 600.0),
      ('C', 900.0),
      ('D', -400.0),
    ])
      BikeStation(
        id: id,
        name: id,
        district: '강서구',
        latitude: 37.56,
        longitude: _east(m),
      ),
  ];
}

class _Reports implements CitizenReportRepository {
  @override
  Future<bool> submit({required String bike, String? station}) async => true;
  @override
  Future<Map<String, ReportCount>> counts() async => const {
    // 경보 목록에 있는 자전거에 신고 2건, 목록에 없는 자전거(대여소 C)에 신고 1건.
    '1': ReportCount(bike: '1', count: 2, station: 'A'),
    'SPB-77777': ReportCount(bike: 'SPB-77777', count: 1, station: 'C'),
  };
}

class _Ops implements OpsListRepository {
  @override
  Future<List<String>> days() async => const [];
  @override
  Future<OpsList> fetch(String day) async => OpsList(day: day, bikes: const []);
  @override
  Future<List<OpsScore>> scores() async => const [
    OpsScore(day: '2026-11-03', listed: 79, rode: 58, firstDud: 28),
    OpsScore(day: '2026-11-02', listed: 32, rode: 26, firstDud: 10),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<StaffSession> start(List<LiveBike> bikes) async {
    final s = StaffSession(
      liveRepository: _Live(bikes),
      opsRepository: _Ops(),
      stationRepository: _Stations(),
      now: DateTime(2026, 11, 4, 9),
      readLocation: () async => _here,
    );
    await s.start();
    return s;
  }

  test('visits the nearest next station each time', () async {
    final s = await start([_bike('1', 'C'), _bike('2', 'A'), _bike('3', 'B')]);
    final order = s.visitOrder();
    expect([for (final o in order) o.station.id], ['A', 'B', 'C']);
    expect(order.first.leg, closeTo(300, 5));
    expect(order[1].leg, closeTo(300, 5));
  });

  test('a strong alert a little farther away comes first', () async {
    final s = await start([_bike('1', 'A'), _bike('2', 'D', high: true)]);
    // D 는 400m 지만 강한 경보라 400×0.6=240 < 300
    expect(s.visitOrder().first.station.id, 'D');
  });

  test('citizen reports reach the staff list and the route', () async {
    final s = StaffSession(
      liveRepository: _Live([_bike('1', 'A')]),
      opsRepository: _Ops(),
      stationRepository: _Stations(),
      now: DateTime(2026, 11, 4, 9),
      readLocation: () async => _here,
      reportRepository: _Reports(),
    );
    await s.start();
    expect(s.reportsFor('1'), 2);
    // 경보 목록에 없던 신고 자전거도 목록에 '시민 신고' 로 들어온다.
    expect(s.visibleBikes.map((b) => b.bike), contains('SPB-77777'));
    // 고장 의심만 경로: 신고 자전거가 있는 C 도 들른다.
    s.setSuspectsOnly(true);
    expect([for (final stop in s.plan.stops) stop.station.id], ['A', 'C']);
    expect(s.planStations().firstWhere((p) => p.id == 'A').reports, 2);
  });

  test('loads the morning list scores', () async {
    final s = await start(const []);
    expect(s.scores.first.hitRate, closeTo(28 / 58, 1e-9));
    expect(pooledHitRate(s.scores), closeTo(38 / 84, 1e-9));
  });

  test('reads a score row and skips a broken one', () {
    expect(
      OpsScore.fromRow({
        'day': '2026-11-03',
        'listed': 79,
        'rode': 58,
        'first_dud': 28,
      })?.firstDud,
      28,
    );
    expect(OpsScore.fromRow({'day': '2026-11-03', 'listed': 79}), isNull);
    expect(
      const OpsScore(day: 'x', listed: 3, rode: 0, firstDud: 0).hitRate,
      isNull,
    );
  });

  test('walking time is a rough, rounded estimate', () {
    expect(walkMinutes(10), 1);
    expect(walkMinutes(500), 10); // 500×1.3÷67 ≈ 9.7
    expect(distanceText(468), '468m');
    expect(distanceText(1900), '1.9km');
  });
}
