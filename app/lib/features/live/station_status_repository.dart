import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/live/station_status.dart';

abstract interface class StationStatusRepository {
  Future<List<StationOccupancy>> fetch();
}

class SupabaseStationStatusRepository implements StationStatusRepository {
  SupabaseStationStatusRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Supabase(PostgREST)는 한 번에 1,000줄까지만 준다. 서울 대여소는 2,700곳이 넘어서
  /// 한 번만 받으면 나머지 대여소가 '실시간 대수 없음' 이 된다 — 쪽을 나눠 끝까지 받는다.
  static const _page = 1000;

  @override
  Future<List<StationOccupancy>> fetch() async {
    final all = <StationOccupancy>[];
    try {
      for (var from = 0; from < 10 * _page; from += _page) {
        final response = await _client
            .get(
              RideyConfig.liveStationStatusUri,
              headers: {
                ...RideyConfig.apiHeaders,
                'Range-Unit': 'items',
                'Range': '$from-${from + _page - 1}',
              },
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode < 200 || response.statusCode >= 300) break;
        final rows = parseStationOccupancy(response.body);
        all.addAll(rows);
        if (rows.length < _page) break;
      }
    } catch (_) {
      // 받은 데까지는 쓴다.
    }
    return all;
  }
}

List<StationOccupancy> parseStationOccupancy(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((row) => StationOccupancy.fromJson(Map<String, dynamic>.from(row)))
      .where((row) => row.id.isNotEmpty)
      .toList(growable: false);
}
