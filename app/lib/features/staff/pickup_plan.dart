import 'dart:math' as math;

import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';

/// 경로를 짤 때 보는 대여소 하나: 위치·거치 대수·거치대 수·고장 의심 자전거.
class PlanStation {
  const PlanStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.bikes,
    this.racks,
    this.suspects = const [],
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// 지금 세워진 자전거 수(실시간 대여소 현황). 모르면 null — 재배치는 하지 않고 고장 의심만 본다.
  final int? bikes;

  /// 거치대 수.
  final int? racks;
  final List<LiveBike> suspects;

  /// 거치대보다 많이 세워진 몫(고장 의심은 따로 거두므로 뺀다). 넘친 곳만.
  int get surplus {
    final b = bikes, r = racks;
    if (b == null || r == null || r <= 0) return 0;
    if (b <= r * overfullRatio) return 0;
    return math.max(0, b - r - suspects.length);
  }

  /// 거의 빈 곳(거치대의 [emptyRatio] 아래)을 거치대 절반까지 채우는 데 필요한 대수.
  int get deficit {
    final b = bikes, r = racks;
    if (b == null || r == null || r <= 0) return 0;
    if (b >= r * emptyRatio) return 0;
    return math.max(0, (r * fillRatio).round() - b);
  }
}

/// 넘친 곳: 거치대의 1.2배를 넘게 세워짐(2026-11-04 저녁 서울 2,737곳 중 1.5배 넘는 곳 555곳).
const overfullRatio = 1.2;

/// 빈 곳: 거치대의 25% 아래(같은 때 0대인 곳 213곳).
const emptyRatio = .25;

/// 빈 곳은 거치대의 절반까지 채운다.
const fillRatio = .5;

/// 들를 곳 하나와 거기서 할 일.
class PlanStop {
  const PlanStop({
    required this.station,
    required this.leg,
    this.suspects = const [],
    this.pickUp = 0,
    this.dropOff = 0,
    this.loadAfter = 0,
  });

  final PlanStation station;

  /// 앞 지점에서 여기까지 직선거리(m).
  final double leg;

  /// 여기서 거둘 고장 의심 자전거(정비센터로).
  final List<LiveBike> suspects;

  /// 여기서 실을 넘친 자전거 수(빈 곳에 내려놓을 것).
  final int pickUp;

  /// 여기에 내려놓을 자전거 수.
  final int dropOff;

  /// 여기를 떠날 때 차에 실린 정상 자전거 수.
  final int loadAfter;

  /// 화면에 쓸 할 일 한 줄.
  String get task => [
    if (suspects.isNotEmpty) '고장 의심 ${suspects.length}대 수거',
    if (pickUp > 0) '넘친 자전거 $pickUp대 싣기',
    if (dropOff > 0) '$dropOff대 내려놓기',
  ].join(' · ');
}

class PickupPlan {
  const PickupPlan({required this.stops, this.capacity = defaultCapacity});

  final List<PlanStop> stops;
  final int capacity;

  double get totalMeters => stops.fold(0, (m, s) => m + s.leg);
  int get suspects => stops.fold(0, (n, s) => n + s.suspects.length);
  int get pickedUp => stops.fold(0, (n, s) => n + s.pickUp);
  int get droppedOff => stops.fold(0, (n, s) => n + s.dropOff);

  /// 끝났을 때 차에 남은 정상 자전거(다음 빈 곳이 멀어서 못 내린 것).
  int get leftOnTruck => stops.isEmpty ? 0 : stops.last.loadAfter;
  bool get isEmpty => stops.isEmpty;
}

/// 재배치 차 한 대에 싣는 대수(공단 1톤 트럭 기준 어림).
const defaultCapacity = 20;

/// 재배치 + 고장 의심 수거를 한 번에: 지금 위치에서 시작해, 매번 '값어치 ÷ 거리' 가 가장 큰 다음 곳으로 간다.
/// - 고장 의심(강한 경보는 더 무겁게)은 정비센터로 가져갈 것이라 차 자리를 차지하고 내려놓지 않는다.
/// - 넘친 곳에서 실은 정상 자전거는 빈 곳에 내려놓는다(차에 실린 만큼만).
/// - 차가 꽉 차면 내려놓을 곳만 고른다.
/// 가까운 이웃 방식의 탐욕 경로라 최적은 아니지만, 매 걸음 '가까우면서 할 일이 많은 곳' 을 고른다.
PickupPlan planPickup({
  required double startLatitude,
  required double startLongitude,
  required List<PlanStation> stations,
  int capacity = defaultCapacity,
  int maxStops = 8,
  bool suspectsOnly = false,
}) {
  if (suspectsOnly) {
    return _suspectTour(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      stations: stations,
      maxStops: maxStops,
      capacity: capacity,
    );
  }
  final left = [...stations];
  final stops = <PlanStop>[];
  var lat = startLatitude, lon = startLongitude;
  var load = 0, held = 0;
  while (stops.length < maxStops && left.isNotEmpty) {
    PlanStation? best;
    var bestScore = 0.0;
    ({int sus, int take, int drop})? bestAct;
    for (final c in left) {
      final room = capacity - load - held;
      final sus = math.min(c.suspects.length, math.max(0, room));
      final take = math.min(c.surplus, math.max(0, room - sus));
      final drop = math.min(c.deficit, load);
      final strong = c.suspects.take(sus).where((b) => b.isHighAlert).length;
      final value = sus * 3.0 + strong * 2.0 + take * 1.0 + drop * 1.2;
      if (value <= 0) continue;
      final d = metersBetween(lat, lon, c.latitude, c.longitude);
      final score = value / (d / 1000 + .3);
      if (score > bestScore) {
        bestScore = score;
        best = c;
        bestAct = (sus: sus, take: take, drop: drop);
      }
    }
    if (best == null || bestAct == null) break;
    final leg = metersBetween(lat, lon, best.latitude, best.longitude);
    held += bestAct.sus;
    load += bestAct.take - bestAct.drop;
    stops.add(
      PlanStop(
        station: best,
        leg: leg,
        suspects: _ordered(best.suspects).take(bestAct.sus).toList(),
        pickUp: bestAct.take,
        dropOff: bestAct.drop,
        loadAfter: load,
      ),
    );
    left.remove(best);
    lat = best.latitude;
    lon = best.longitude;
  }
  return PickupPlan(stops: stops, capacity: capacity);
}

List<LiveBike> _ordered(List<LiveBike> bikes) => [...bikes]
  ..sort((a, b) {
    if (a.isHighAlert != b.isHighAlert) return a.isHighAlert ? -1 : 1;
    return b.chain.compareTo(a.chain);
  });

/// 고장 의심만: 가까운 이웃으로 순서를 잡고 2-opt(두 구간을 뒤집어 보며 짧아지면 바꾸기)로 다듬은 가장 짧은 길.
PickupPlan _suspectTour({
  required double startLatitude,
  required double startLongitude,
  required List<PlanStation> stations,
  required int maxStops,
  required int capacity,
}) {
  final targets = stations.where((s) => s.suspects.isNotEmpty).toList();
  if (targets.isEmpty) return PickupPlan(stops: const [], capacity: capacity);
  // 가까운 이웃
  final order = <PlanStation>[];
  final left = [...targets];
  var lat = startLatitude, lon = startLongitude;
  while (left.isNotEmpty && order.length < maxStops) {
    left.sort(
      (a, b) => metersBetween(
        lat,
        lon,
        a.latitude,
        a.longitude,
      ).compareTo(metersBetween(lat, lon, b.latitude, b.longitude)),
    );
    final next = left.removeAt(0);
    order.add(next);
    lat = next.latitude;
    lon = next.longitude;
  }
  final improved = twoOpt(startLatitude, startLongitude, order);
  final stops = <PlanStop>[];
  lat = startLatitude;
  lon = startLongitude;
  var held = 0;
  for (final s in improved) {
    final take = math.min(s.suspects.length, math.max(0, capacity - held));
    held += take;
    stops.add(
      PlanStop(
        station: s,
        leg: metersBetween(lat, lon, s.latitude, s.longitude),
        suspects: _ordered(s.suspects).take(take).toList(),
      ),
    );
    lat = s.latitude;
    lon = s.longitude;
  }
  return PickupPlan(stops: stops, capacity: capacity);
}

/// 시작점이 고정된 열린 경로의 2-opt. 더 짧아지지 않을 때까지 구간을 뒤집는다.
List<PlanStation> twoOpt(
  double startLatitude,
  double startLongitude,
  List<PlanStation> order,
) {
  if (order.length < 3) return order;
  final route = [...order];
  double d(int i, int j) {
    // i == -1 은 시작점
    final a = i < 0
        ? (startLatitude, startLongitude)
        : (route[i].latitude, route[i].longitude);
    final b = (route[j].latitude, route[j].longitude);
    return metersBetween(a.$1, a.$2, b.$1, b.$2);
  }

  var better = true;
  var rounds = 0;
  while (better && rounds < 50) {
    better = false;
    rounds++;
    for (var i = -1; i < route.length - 2; i++) {
      for (var k = i + 2; k < route.length; k++) {
        // 구간 (i, i+1) 과 (k, k+1) 을 (i, k) 와 (i+1, k+1) 로 바꾼다. 끝(k == 마지막)은 뒤 구간이 없다.
        final before = d(i, i + 1) + (k + 1 < route.length ? d(k, k + 1) : 0);
        final after =
            d(i, k) +
            (k + 1 < route.length
                ? metersBetween(
                    route[i + 1].latitude,
                    route[i + 1].longitude,
                    route[k + 1].latitude,
                    route[k + 1].longitude,
                  )
                : 0);
        if (after + .5 < before) {
          final reversed = route.sublist(i + 1, k + 1).reversed.toList();
          route.replaceRange(i + 1, k + 1, reversed);
          better = true;
        }
      }
    }
  }
  return route;
}
