import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

class DistrictRow {
  const DistrictRow({
    required this.district,
    required this.bikes,
    required this.highAlerts,
    required this.expected,
  });

  final String district;
  final int bikes;
  final int highAlerts;
  final double? expected;
}

double? expectOf(Iterable<LiveBike> bikes) {
  final list = bikes.toList(growable: false);
  if (list.isEmpty || list.every((bike) => bike.probability == null)) {
    return null;
  }
  return list.fold<double>(
    0,
    (sum, bike) => sum + (bike.probability ?? 0) / 100,
  );
}

String districtOf(LiveBike bike, Map<String, BikeStation> stations) {
  final district = stations[bike.station]?.district.trim() ?? '';
  return district.isEmpty ? '기타' : district;
}

List<DistrictRow> districtRows(
  Iterable<LiveBike> bikes,
  Map<String, BikeStation> stations,
) {
  final groups = <String, List<LiveBike>>{};
  for (final bike in bikes) {
    final district = districtOf(bike, stations);
    (groups[district] ??= []).add(bike);
  }

  final rows = [
    for (final entry in groups.entries)
      DistrictRow(
        district: entry.key,
        bikes: entry.value.length,
        highAlerts: entry.value.where((bike) => bike.isHighAlert).length,
        expected: expectOf(entry.value),
      ),
  ];
  rows.sort((a, b) {
    final byCount = b.bikes.compareTo(a.bikes);
    if (byCount != 0) return byCount;
    return a.district.compareTo(b.district);
  });
  return rows;
}

List<String> districtNames(Iterable<BikeStation> stations) {
  final names = {
    for (final station in stations)
      if (station.district.trim().isNotEmpty) station.district.trim(),
  };
  final list = names.toList()..sort();
  return list;
}

String formatExpected(double? value) {
  if (value == null) return '–';
  return value.toStringAsFixed(1);
}
