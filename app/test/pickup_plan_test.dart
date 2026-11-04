// 직원 추천 경로: 재배치(넘친 곳 → 빈 곳) + 고장 의심 수거, 고장 의심만일 때 가장 짧은 길.
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/places/place_search.dart';
import 'package:ridey_app/features/staff/pickup_plan.dart';
import 'package:ridey_app/features/staff/road_route.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

const _lat = 37.56;
double _east(double m) => 127.0 + m / (111320 * 0.7923);

LiveBike _bike(String id, String station, {bool high = false}) => LiveBike(
  bike: id,
  station: station,
  stationName: station,
  chain: high ? 4 : 2,
  isHighAlert: high,
  lastDud: '11-04 08:00',
  probability: null,
);

PlanStation _st(
  String id,
  double meters, {
  int? bikes,
  int? racks,
  List<LiveBike> suspects = const [],
}) => PlanStation(
  id: id,
  name: id,
  latitude: _lat,
  longitude: _east(meters),
  bikes: bikes,
  racks: racks,
  suspects: suspects,
);

void main() {
  test('overfull and empty stations: surplus and deficit', () {
    expect(_st('a', 0, bikes: 30, racks: 10).surplus, 20);
    expect(_st('a', 0, bikes: 11, racks: 10).surplus, 0); // 1.2배 안
    expect(_st('a', 0, bikes: 1, racks: 20).deficit, 9); // 절반(10)까지
    expect(_st('a', 0, bikes: 8, racks: 20).deficit, 0); // 25% 넘음
    expect(_st('a', 0).surplus, 0); // 대수 모름
  });

  test('picks up at an overfull station before dropping at an empty one', () {
    final plan = planPickup(
      startLatitude: _lat,
      startLongitude: 127.0,
      stations: [
        _st('empty', 300, bikes: 0, racks: 20),
        _st('full', 600, bikes: 30, racks: 15),
      ],
    );
    expect([for (final s in plan.stops) s.station.id], ['full', 'empty']);
    expect(plan.stops.first.pickUp, 15);
    expect(plan.stops.last.dropOff, 10);
    expect(plan.leftOnTruck, 5);
  });

  test('suspects ride with the rebalancing and take truck room', () {
    final plan = planPickup(
      startLatitude: _lat,
      startLongitude: 127.0,
      capacity: 10,
      stations: [
        _st(
          'full',
          200,
          bikes: 40,
          racks: 10,
          suspects: [
            _bike('SPB-00001', 'full', high: true),
            _bike('SPB-00002', 'full'),
          ],
        ),
      ],
    );
    final stop = plan.stops.single;
    expect(stop.suspects.first.bike, 'SPB-00001'); // 강한 경보 먼저
    expect(stop.suspects.length + stop.pickUp, 10); // 차 한 대 만큼만
    expect(stop.task, contains('고장 의심 2대 수거'));
  });

  test('suspects only: the shortest open path from where I stand', () {
    // 시작 0m, 대여소 100·900·500m — 가까운 순(100, 500, 900)이 최단.
    final plan = planPickup(
      startLatitude: _lat,
      startLongitude: 127.0,
      suspectsOnly: true,
      stations: [
        _st('b', 900, suspects: [_bike('SPB-00003', 'b')]),
        _st('a', 100, suspects: [_bike('SPB-00004', 'a')]),
        _st('c', 500, suspects: [_bike('SPB-00005', 'c')]),
        _st('none', 50), // 고장 의심 없는 곳은 안 들른다
      ],
    );
    expect([for (final s in plan.stops) s.station.id], ['a', 'c', 'b']);
    expect(plan.totalMeters, closeTo(900, 5));
  });

  test('2-opt untangles a crossing path', () {
    // 시작 (0,0), 점 A(0,1) B(1,1) C(1,0) D(0,2)... 직선 위 예: 순서 0→300→100→200 은 꼬임.
    final order = [_st('p300', 300), _st('p100', 100), _st('p200', 200)];
    final better = twoOpt(_lat, 127.0, order);
    expect([for (final s in better) s.id], ['p100', 'p200', 'p300']);
  });

  test('reads an OSRM route and says each step in Korean', () {
    const body = '''
{"code":"Ok","routes":[{"distance":1200.5,"duration":300,
 "geometry":{"type":"LineString","coordinates":[[127.0,37.5],[127.01,37.5]]},
 "legs":[{"steps":[
  {"distance":62,"name":"도신로15길","maneuver":{"type":"depart","modifier":"right","location":[127.0,37.5]}},
  {"distance":633,"name":"도신로","maneuver":{"type":"end of road","modifier":"right","location":[127.001,37.5]}},
  {"distance":30,"name":"","maneuver":{"type":"turn","modifier":"left","location":[127.002,37.5]}},
  {"distance":0,"name":"","maneuver":{"type":"roundabout","exit":2,"location":[127.003,37.5]}},
  {"distance":0,"name":"공원길","maneuver":{"type":"turn","modifier":"right","location":[127.004,37.5]}}
 ]}]}]}''';
    final route = parseOsrmRoute(body)!;
    expect(route.points, hasLength(2));
    expect(route.distance, 1200.5);
    final steps = route.legs.single;
    expect(stepText(steps[0]), '도신로15길에서 출발');
    expect(stepText(steps[1]), '길 끝에서 도신로로 우회전');
    expect(stepText(steps[2]), '좌회전');
    expect(stepText(steps[3]), '회전교차로에서 2번째 출구');
    expect(stepText(steps[4]), '공원길로 우회전'); // ㄹ 받침은 '로'
    expect(navDistance(1234), '1.2km');
    expect(navDistance(87), '90m');
    expect(parseOsrmRoute('{"code":"NoRoute"}'), isNull);
  });

  test('finds districts and stations by name without the network', () {
    const stations = [
      BikeStation(
        id: '1',
        name: '강남역 10번출구',
        district: '강남구',
        latitude: 37.49,
        longitude: 127.02,
      ),
      BikeStation(
        id: '2',
        name: '역삼역 1번출구',
        district: '강남구',
        latitude: 37.50,
        longitude: 127.03,
      ),
      BikeStation(
        id: '3',
        name: '망원역 1번출구 앞',
        district: '마포구',
        latitude: 37.55,
        longitude: 126.91,
      ),
    ];
    final gu = searchStations('강남', stations);
    expect(gu.first.kind, SearchPlaceKind.district);
    expect(gu.first.name, '강남구');
    expect(gu.first.latitude, closeTo(37.495, 1e-9));
    final station = searchStations('망원 역', stations);
    expect(station.single.stationId, '3');
    expect(searchStations('', stations), isEmpty);
  });
}
