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

  @override
  Future<List<StationOccupancy>> fetch() async {
    try {
      final response = await _client
          .get(
            RideyConfig.liveStationStatusUri,
            headers: RideyConfig.apiHeaders,
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      return parseStationOccupancy(response.body);
    } catch (_) {
      return const [];
    }
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
