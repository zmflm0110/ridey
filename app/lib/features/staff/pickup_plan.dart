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

  /// 경로 점수: 할 일의 값어치 합 ÷ (거리 km + 들른 곳마다 0.3). 같은 품으로 일을 많이 할수록 높다.
  double get score {
    if (stops.isEmpty) return 0;
    final value = stops.fold(0.0, (v, s) => v + _stopValue(s));
    return value / (totalMeters / 1000 + _stopKm * stops.length);
  }
}

/// 재배치 차 한 대에 싣는 대수(공단 1톤 트럭 기준 어림).
const defaultCapacity = 20;

/// 빔 서치 폭: 걸음마다 남겨 두는 후보 경로 수. 1 이면 매번 1등 하나만 고르는 탐욕과 같다.
const defaultBeamWidth = 5;

/// 한 곳 들르는 품을 거리로 친 값(km). 가까운 곳을 여러 번 들르기보다 할 일 많은 곳 한 번이 낫게.
const _stopKm = .3;

/// 할 일의 값어치: 고장 의심 3(강한 경보는 2 더), 넘친 자전거 싣기 1, 빈 곳에 내려놓기 1.2.
double _value({
  required int suspects,
  required int strong,
  required int pickUp,
  required int dropOff,
}) => suspects * 3.0 + strong * 2.0 + pickUp * 1.0 + dropOff * 1.2;

double _stopValue(PlanStop s) => _value(
  suspects: s.suspects.length,
  strong: s.suspects.where((b) => b.isHighAlert).length,
  pickUp: s.pickUp,
  dropOff: s.dropOff,
);

/// 재배치 + 고장 의심 수거를 한 번에 도는 순서.
///
/// 빔 서치: 지금 위치에서 한 곳씩 늘려 가며, 걸음마다 경로 점수([PickupPlan.score])가 높은
/// [beamWidth]개만 남긴다. 한 번에 1등 하나만 고르면 처음 고른 곳 때문에 뒤가 꼬여도 되돌릴 수 없는데,
/// 여러 개를 함께 들고 가면 그런 길을 피할 수 있다. 남은 경로는 2-opt(두 구간을 뒤집어 다시 걸어 보기)로
/// 다듬는다. 순서가 바뀌면 싣고 내리는 대수도 바뀌므로 처음부터 다시 계산한다.
/// 매번 '값어치 ÷ 거리'가 가장 큰 다음 곳으로 가는 탐욕 경로도 후보로 함께 견줘, 그보다 점수가 낮거나
/// 고장 의심을 덜 거두는 길은 내지 않는다.
///
/// - 고장 의심(강한 경보는 더 무겁게)은 정비센터로 가져갈 것이라 차 자리를 차지하고 내려놓지 않는다.
/// - 넘친 곳에서 실은 정상 자전거는 빈 곳에 내려놓는다(차에 실린 만큼만).
/// - 차가 꽉 차면 내려놓을 곳만 고른다.
/// 모든 순서를 다 보지는 않으므로 최적이라는 보장은 없다.
PickupPlan planPickup({
  required double startLatitude,
  required double startLongitude,
  required List<PlanStation> stations,
  int capacity = defaultCapacity,
  int maxStops = 8,
  bool suspectsOnly = false,
  int beamWidth = defaultBeamWidth,
}) {
  if (suspectsOnly) {
    return _suspectTour(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      stations: stations,
      maxStops: maxStops,
      capacity: capacity,
      beamWidth: beamWidth,
    );
  }
  final start = _Route.start(startLatitude, startLongitude, capacity);
  var best = _twoOptRoute(_greedy(start, stations, maxStops));
  // 재배치 점수를 올리려고 고장 의심을 덜 거두는 길은 버린다 — 고장 의심 수거가 RIDEY 의 몫이다.
  final atLeast = best.held;
  if (beamWidth > 1) {
    for (final route in _beam(start, stations, maxStops, beamWidth)) {
      final tidy = _twoOptRoute(route);
      if (tidy.held >= atLeast && tidy.score > best.score) best = tidy;
    }
  }
  return PickupPlan(stops: best.stops, capacity: capacity);
}

/// 한 곳에서 할 일: 거둘 고장 의심, 실을 대수, 내려놓을 대수, 값어치, 앞 지점에서 온 거리(m).
typedef _Step = ({int sus, int take, int drop, double value, double leg});

/// 만드는 중인 재배치 경로. [then]은 자신을 바꾸지 않고 한 곳을 더한 새 경로를 준다.
class _Route {
  _Route.start(this.startLatitude, this.startLongitude, this.capacity)
    : latitude = startLatitude,
      longitude = startLongitude,
      stops = const [],
      visited = const {},
      load = 0,
      held = 0,
      value = 0,
      meters = 0;

  _Route._({
    required this.startLatitude,
    required this.startLongitude,
    required this.capacity,
    required this.latitude,
    required this.longitude,
    required this.stops,
    required this.visited,
    required this.load,
    required this.held,
    required this.value,
    required this.meters,
  });

  final double startLatitude;
  final double startLongitude;
  final int capacity;

  /// 지금 서 있는 곳(마지막으로 들른 대여소).
  final double latitude;
  final double longitude;
  final List<PlanStop> stops;
  final Set<String> visited;

  /// 차에 실린 정상 자전거(빈 곳에 내려놓을 것)와 고장 의심(내려놓지 않음).
  final int load;
  final int held;
  final double value;
  final double meters;

  double get score =>
      stops.isEmpty ? 0 : value / (meters / 1000 + _stopKm * stops.length);

  /// 같은 곳들을 돌아 같은 곳에서 같은 짐으로 끝나는 경로는 앞으로 할 수 있는 일이 같다 — 하나만 남긴다.
  String get key {
    final ids = visited.toList()..sort();
    return '${ids.join(',')}>${stops.last.station.id}/$load/$held';
  }

  /// 다음 곳 [s]에서 할 일. 할 일이 없으면 null.
  _Step? stepTo(PlanStation s) {
    final room = math.max(0, capacity - load - held);
    final sus = math.min(s.suspects.length, room);
    final take = math.min(s.surplus, room - sus);
    final drop = math.min(s.deficit, load);
    if (sus + take + drop == 0) return null;
    final strong = _ordered(
      s.suspects,
    ).take(sus).where((b) => b.isHighAlert).length;
    return (
      sus: sus,
      take: take,
      drop: drop,
      value: _value(suspects: sus, strong: strong, pickUp: take, dropOff: drop),
      leg: metersBetween(latitude, longitude, s.latitude, s.longitude),
    );
  }

  _Route then(PlanStation s, _Step step) {
    final loadAfter = load + step.take - step.drop;
    return _Route._(
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      capacity: capacity,
      latitude: s.latitude,
      longitude: s.longitude,
      stops: [
        ...stops,
        PlanStop(
          station: s,
          leg: step.leg,
          suspects: _ordered(s.suspects).take(step.sus).toList(),
          pickUp: step.take,
          dropOff: step.drop,
          loadAfter: loadAfter,
        ),
      ],
      visited: {...visited, s.id},
      load: loadAfter,
      held: held + step.sus,
      value: value + step.value,
      meters: meters + step.leg,
    );
  }
}

/// 탐욕: 매번 '값어치 ÷ (거리 km + 0.3)'이 가장 큰 다음 곳으로 간다.
_Route _greedy(_Route start, List<PlanStation> stations, int maxStops) {
  var route = start;
  while (route.stops.length < maxStops) {
    PlanStation? best;
    _Step? bestStep;
    var bestScore = 0.0;
    for (final s in stations) {
      if (route.visited.contains(s.id)) continue;
      final step = route.stepTo(s);
      if (step == null) continue;
      final score = step.value / (step.leg / 1000 + _stopKm);
      if (score > bestScore) {
        bestScore = score;
        best = s;
        bestStep = step;
      }
    }
    if (best == null || bestStep == null) break;
    route = route.then(best, bestStep);
  }
  return route;
}

/// 빔 서치: 걸음마다 지금 남은 경로들에 한 곳씩 더해 보고, 경로 점수가 높은 [width]개만 남긴다.
List<_Route> _beam(
  _Route start,
  List<PlanStation> stations,
  int maxStops,
  int width,
) {
  var beam = [start];
  for (var step = 0; step < maxStops; step++) {
    final next = <String, _Route>{};
    for (final route in beam) {
      for (final s in stations) {
        if (route.visited.contains(s.id)) continue;
        final at = route.stepTo(s);
        if (at == null) continue;
        final child = route.then(s, at);
        final same = next[child.key];
        if (same == null || child.score > same.score) next[child.key] = child;
      }
    }
    if (next.isEmpty) break;
    beam = (next.values.toList()..sort((a, b) => b.score.compareTo(a.score)))
        .take(width)
        .toList();
  }
  return beam;
}

/// 재배치 경로의 2-opt: 두 구간을 뒤집은 순서로 처음부터 다시 걸어 보고, 거두는 고장 의심이 줄지 않고
/// 점수가 오르면 바꾼다.
/// 뒤집은 순서에서 할 일이 없어지는 곳이 생기면(예: 싣기 전에 내려놓기) 그 순서는 버린다.
_Route _twoOptRoute(_Route route) {
  var best = route;
  var improved = true;
  for (var round = 0; improved && round < 50; round++) {
    improved = false;
    final order = [for (final s in best.stops) s.station];
    search:
    for (var i = 0; i < order.length - 1; i++) {
      for (var k = i + 1; k < order.length; k++) {
        final tried = _walk(best, [
          ...order.sublist(0, i),
          ...order.sublist(i, k + 1).reversed,
          ...order.sublist(k + 1),
        ]);
        if (tried != null &&
            tried.held >= best.held &&
            tried.score > best.score + 1e-9) {
          best = tried;
          improved = true;
          break search;
        }
      }
    }
  }
  return best;
}

/// [order] 대로 출발점부터 다시 걷는다. 할 일이 없는 곳이 끼면 null.
_Route? _walk(_Route like, List<PlanStation> order) {
  var route = _Route.start(
    like.startLatitude,
    like.startLongitude,
    like.capacity,
  );
  for (final s in order) {
    final step = route.stepTo(s);
    if (step == null) return null;
    route = route.then(s, step);
  }
  return route;
}

List<LiveBike> _ordered(List<LiveBike> bikes) => [...bikes]
  ..sort((a, b) {
    if (a.isHighAlert != b.isHighAlert) return a.isHighAlert ? -1 : 1;
    return b.chain.compareTo(a.chain);
  });

/// 고장 의심만 도는 길을 만드는 중의 상태.
class _Tour {
  const _Tour(this.order, this.latitude, this.longitude, this.meters);

  final List<PlanStation> order;
  final double latitude;
  final double longitude;
  final double meters;

  String get key {
    final ids = [for (final s in order) s.id]..sort();
    return '${ids.join(',')}>${order.last.id}';
  }
}

/// 고장 의심만: 빔 서치로 짧은 순서 후보를 [beamWidth]개 만들고 2-opt로 다듬어 가장 짧은 길을 고른다.
/// 폭 1 은 '매번 가장 가까운 곳'(가까운 이웃)이고, 그 길도 늘 후보에 든다.
/// 가까운 이웃 길보다 고장 의심을 적게 거두는 후보는 버린다.
PickupPlan _suspectTour({
  required double startLatitude,
  required double startLongitude,
  required List<PlanStation> stations,
  required int maxStops,
  required int capacity,
  required int beamWidth,
}) {
  final targets = stations.where((s) => s.suspects.isNotEmpty).toList();
  if (targets.isEmpty) return PickupPlan(stops: const [], capacity: capacity);
  List<_Tour> search(int width) {
    var beam = [_Tour(const [], startLatitude, startLongitude, 0)];
    for (var step = 0; step < maxStops; step++) {
      final next = <String, _Tour>{};
      for (final tour in beam) {
        final done = {for (final s in tour.order) s.id};
        for (final s in targets) {
          if (done.contains(s.id)) continue;
          final child = _Tour(
            [...tour.order, s],
            s.latitude,
            s.longitude,
            tour.meters +
                metersBetween(
                  tour.latitude,
                  tour.longitude,
                  s.latitude,
                  s.longitude,
                ),
          );
          final same = next[child.key];
          if (same == null || child.meters < same.meters) {
            next[child.key] = child;
          }
        }
      }
      if (next.isEmpty) break;
      beam =
          (next.values.toList()..sort((a, b) => a.meters.compareTo(b.meters)))
              .take(width)
              .toList();
    }
    return beam;
  }

  int collected(List<PlanStation> order) =>
      math.min(capacity, order.fold(0, (n, s) => n + s.suspects.length));

  var best = twoOpt(startLatitude, startLongitude, search(1).first.order);
  final atLeast = collected(best);
  var bestMeters = _length(startLatitude, startLongitude, best);
  if (beamWidth > 1) {
    for (final tour in search(beamWidth)) {
      final order = twoOpt(startLatitude, startLongitude, tour.order);
      final meters = _length(startLatitude, startLongitude, order);
      if (collected(order) >= atLeast && meters < bestMeters - .5) {
        best = order;
        bestMeters = meters;
      }
    }
  }

  final stops = <PlanStop>[];
  var lat = startLatitude, lon = startLongitude;
  var held = 0;
  for (final s in best) {
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

double _length(
  double startLatitude,
  double startLongitude,
  List<PlanStation> order,
) {
  var lat = startLatitude, lon = startLongitude, sum = 0.0;
  for (final s in order) {
    sum += metersBetween(lat, lon, s.latitude, s.longitude);
    lat = s.latitude;
    lon = s.longitude;
  }
  return sum;
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
