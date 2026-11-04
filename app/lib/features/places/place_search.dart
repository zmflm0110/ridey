import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/features/stations/bike_station.dart';

/// 지도를 옮겨 볼 곳: 구, 대여소, 또는 지명(학원·역·동네).
class SearchPlace {
  const SearchPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.kind,
    this.detail,
    this.stationId,
  });

  final String name;
  final double latitude;
  final double longitude;
  final SearchPlaceKind kind;

  /// 둘째 줄(구 이름, 주소 앞부분).
  final String? detail;

  /// 대여소를 고른 경우 그 번호.
  final String? stationId;
}

enum SearchPlaceKind { district, station, place }

String _plain(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// 앱에 들어 있는 대여소 목록만으로 찾기(인터넷 없이 바로): 구 이름과 대여소 이름.
List<SearchPlace> searchStations(
  String query,
  List<BikeStation> stations, {
  int limit = 12,
}) {
  final q = _plain(query);
  if (q.isEmpty) return const [];
  final out = <SearchPlace>[];
  // 구: '강남' 이나 '강남구' 로 — 그 구 대여소들의 가운데.
  final byGu = <String, List<BikeStation>>{};
  for (final s in stations) {
    (byGu[s.district] ??= []).add(s);
  }
  for (final entry in byGu.entries) {
    final gu = entry.key;
    if (gu.isEmpty) continue;
    if (_plain(gu).startsWith(q) || q.startsWith(_plain(gu))) {
      final list = entry.value;
      final lat =
          list.map((s) => s.latitude).reduce((a, b) => a + b) / list.length;
      final lon =
          list.map((s) => s.longitude).reduce((a, b) => a + b) / list.length;
      out.add(
        SearchPlace(
          name: gu,
          latitude: lat,
          longitude: lon,
          kind: SearchPlaceKind.district,
          detail: '대여소 ${list.length}곳',
        ),
      );
    }
  }
  // 대여소: 이름이 검색어로 시작하는 곳을 먼저, 그다음 들어 있는 곳.
  final starts = <BikeStation>[];
  final contains = <BikeStation>[];
  for (final s in stations) {
    final name = _plain(s.name);
    if (name.startsWith(q)) {
      starts.add(s);
    } else if (name.contains(q)) {
      contains.add(s);
    }
  }
  for (final s in [...starts, ...contains]) {
    if (out.length >= limit) break;
    out.add(
      SearchPlace(
        name: s.name.trim(),
        latitude: s.latitude,
        longitude: s.longitude,
        kind: SearchPlaceKind.station,
        detail: s.district,
        stationId: s.id,
      ),
    );
  }
  return out;
}

/// 지명 찾기(학원가·건물·동네): OpenStreetMap 의 Nominatim. 키가 없고, 서울 안만.
/// 이용 규칙(초당 1번 이하·앱 이름 밝히기)에 맞게 검색 단추를 눌렀을 때만 부른다.
class PlaceGeocoder {
  PlaceGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<SearchPlace>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'countrycodes': 'kr',
      'accept-language': 'ko',
      // 서울 상자 안만
      'viewbox': '126.76,37.70,127.19,37.42',
      'bounded': '1',
      'limit': '8',
    });
    final response = await _client
        .get(uri, headers: {'User-Agent': 'RIDEY/1.0 (kr.bikedoctor.ridey)'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return const [];
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return const [];
    final out = <SearchPlace>[];
    for (final row in decoded.whereType<Map>()) {
      final lat = double.tryParse('${row['lat']}');
      final lon = double.tryParse('${row['lon']}');
      final display = '${row['display_name'] ?? ''}';
      if (lat == null || lon == null || display.isEmpty) continue;
      final parts = display.split(',').map((p) => p.trim()).toList();
      out.add(
        SearchPlace(
          name: '${row['name'] ?? ''}'.trim().isNotEmpty
              ? '${row['name']}'.trim()
              : parts.first,
          latitude: lat,
          longitude: lon,
          kind: SearchPlaceKind.place,
          detail: parts.skip(1).take(3).join(' '),
        ),
      );
    }
    return out;
  }
}
