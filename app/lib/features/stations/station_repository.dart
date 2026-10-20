import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridey_app/features/stations/bike_station.dart';

abstract interface class StationRepository {
  Future<List<BikeStation>> fetch();
}

class GitHubStationRepository implements StationRepository {
  GitHubStationRepository({http.Client? client})
    : _client = client ?? http.Client();

  static final _uri = Uri.parse(
    'https://raw.githubusercontent.com/zmflm0110/ridey/master/web/data/stations.json',
  );

  final http.Client _client;

  @override
  Future<List<BikeStation>> fetch() async {
    final response = await _client
        .get(_uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StationRepositoryException(response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('대여소 목록 형식이 올바르지 않습니다.');
    }
    return decoded
        .whereType<Map>()
        .map(
          (station) => BikeStation.fromJson(Map<String, dynamic>.from(station)),
        )
        .toList(growable: false);
  }
}

class StationRepositoryException implements Exception {
  const StationRepositoryException(this.statusCode);

  final int statusCode;
}
