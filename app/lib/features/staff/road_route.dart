import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// 길안내 한 걸음(OSRM step): 어디서 무엇을 하고 어느 길로 들어가는지.
class RouteStep {
  const RouteStep({
    required this.distance,
    required this.type,
    required this.location,
    this.modifier,
    this.name = '',
    this.exit,
  });

  /// 이 걸음이 시작되는 지점에서 다음 걸음까지(m).
  final double distance;

  /// OSRM maneuver.type — depart, turn, new name, continue, merge, fork, end of road,
  /// on ramp, off ramp, roundabout, rotary, arrive ...
  final String type;
  final String? modifier;

  /// 들어가는 길 이름(없으면 빈칸).
  final String name;

  /// 회전교차로에서 나갈 출구 번호.
  final int? exit;

  /// 이 걸음의 동작이 일어나는 곳.
  final LatLng location;
}

/// 도로를 따라간 길: 선(지도에 그림)과 들를 곳 사이 구간(legs)마다의 걸음.
class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.legs,
    required this.distance,
    required this.duration,
  });

  final List<LatLng> points;
  final List<List<RouteStep>> legs;

  /// 전체 거리(m)와 걸리는 시간(초, 차 기준).
  final double distance;
  final double duration;
}

/// 차로 도는 재배치 경로를 도로를 따라 받는다 — OSRM(OpenStreetMap 도로 자료, 키 없음).
/// 공개 서버라 '길안내 시작' 이나 경로를 새로 짤 때만 한 번 부른다. 못 받으면 null(직선으로 보여 준다).
class RoadRouter {
  RoadRouter({http.Client? client, this.host = 'router.project-osrm.org'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String host;

  Future<RoadRoute?> route(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return null;
    final coords = waypoints
        .map(
          (p) =>
              '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    final uri = Uri.https(host, '/route/v1/driving/$coords', {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'true',
    });
    try {
      final response = await _client
          .get(uri, headers: {'User-Agent': 'RIDEY/1.0 (kr.bikedoctor.ridey)'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      return parseOsrmRoute(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }
}

RoadRoute? parseOsrmRoute(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map || decoded['code'] != 'Ok') return null;
  final routes = decoded['routes'];
  if (routes is! List || routes.isEmpty) return null;
  final r = routes.first as Map;
  final coords = (r['geometry'] as Map?)?['coordinates'];
  if (coords is! List) return null;
  final points = [
    for (final c in coords.whereType<List>())
      if (c.length >= 2)
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
  ];
  final legs = <List<RouteStep>>[];
  for (final leg in (r['legs'] as List? ?? const []).whereType<Map>()) {
    final steps = <RouteStep>[];
    for (final step in (leg['steps'] as List? ?? const []).whereType<Map>()) {
      final m = step['maneuver'] as Map? ?? const {};
      final loc = m['location'];
      if (loc is! List || loc.length < 2) continue;
      steps.add(
        RouteStep(
          distance: (step['distance'] as num?)?.toDouble() ?? 0,
          type: '${m['type'] ?? ''}',
          modifier: m['modifier'] as String?,
          name: '${step['name'] ?? ''}'.trim(),
          exit: (m['exit'] as num?)?.toInt(),
          location: LatLng(
            (loc[1] as num).toDouble(),
            (loc[0] as num).toDouble(),
          ),
        ),
      );
    }
    legs.add(steps);
  }
  return RoadRoute(
    points: points,
    legs: legs,
    distance: (r['distance'] as num?)?.toDouble() ?? 0,
    duration: (r['duration'] as num?)?.toDouble() ?? 0,
  );
}

/// 걸음을 한국어 안내 한 줄로: "동일로로 좌회전", "회전교차로에서 2번째 출구".
String stepText(RouteStep step) {
  final road = step.name.isEmpty ? '' : '${step.name}${_ro(step.name)} ';
  final turn = switch (step.modifier) {
    'left' => '좌회전',
    'right' => '우회전',
    'slight left' => '왼쪽 방향',
    'slight right' => '오른쪽 방향',
    'sharp left' => '크게 좌회전',
    'sharp right' => '크게 우회전',
    'uturn' => '유턴',
    _ => '직진',
  };
  return switch (step.type) {
    'depart' => step.name.isEmpty ? '출발' : '${step.name}에서 출발',
    'arrive' => '도착',
    'roundabout' ||
    'rotary' => step.exit == null ? '회전교차로 진입' : '회전교차로에서 ${step.exit}번째 출구',
    'merge' => '$road합류',
    'on ramp' => '$road진입로로 $turn',
    'off ramp' => '$road나가는 길로 $turn',
    'fork' => '갈림길에서 $road$turn',
    'end of road' => '길 끝에서 $road$turn',
    'continue' || 'new name' => step.name.isEmpty ? '직진' : '${step.name} 따라 직진',
    _ => '$road$turn',
  }.trim();
}

/// 받침이 있으면 '으로', 없거나 ㄹ 받침이면 '로'(동일로 → 동일로로, 강남대로 → 강남대로로, 올림픽길 → 올림픽길로).
String _ro(String word) {
  if (word.isEmpty) return '로';
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '로';
  final jong = (code - 0xAC00) % 28;
  return (jong == 0 || jong == 8) ? '로' : '으로';
}

/// 남은 거리 글자: 1km 아래는 10m 단위.
String navDistance(double meters) => meters < 1000
    ? '${(meters / 10).round() * 10}m'
    : '${(meters / 1000).toStringAsFixed(1)}km';
