import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

abstract interface class StationRepository {
  Future<List<BikeStation>> fetch();
}

const stationsAssetPath = 'assets/data/stations.json';

List<BikeStation> parseStations(String raw) {
  final decoded = jsonDecode(raw);
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

class BundledStationRepository implements StationRepository {
  BundledStationRepository({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  @override
  Future<List<BikeStation>> fetch() async {
    final raw = await (_bundle ?? rootBundle).loadString(stationsAssetPath);
    return parseStations(raw);
  }
}
