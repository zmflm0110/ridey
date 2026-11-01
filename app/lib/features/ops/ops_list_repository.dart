import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/config/ridey_config.dart';
import 'package:ridey_app/features/ops/ops_list.dart';

abstract interface class OpsListRepository {
  Future<List<String>> days();
  Future<OpsList> fetch(String day);
}

class SupabaseOpsListRepository implements OpsListRepository {
  SupabaseOpsListRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<List<String>> days() async {
    final rows = await _get(RideyConfig.opsListDaysUri);
    return rows
        .map((row) => opsListDay(row['day']))
        .where((day) => day.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<OpsList> fetch(String day) async {
    final rows = await _get(RideyConfig.opsListDayUri(day));
    if (rows.isEmpty) {
      throw const FormatException('그 날짜의 아침 목록이 없습니다.');
    }
    return OpsList.fromRow(day, rows.first);
  }

  Future<List<Map<String, dynamic>>> _get(Uri uri) async {
    final response = await _client
        .get(uri, headers: RideyConfig.apiHeaders)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpsListException(response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('아침 목록을 읽을 수 없습니다.');
    }
    return decoded
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }
}

class OpsListException implements Exception {
  const OpsListException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'OpsListException($statusCode)';
}
