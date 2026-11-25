import 'package:ridey_app/features/stations/bike_station.dart';

List<String> districtNames(Iterable<BikeStation> stations) {
  final names = {
    for (final station in stations)
      if (station.district.trim().isNotEmpty) station.district.trim(),
  };
  final list = names.toList()..sort();
  return list;
}
