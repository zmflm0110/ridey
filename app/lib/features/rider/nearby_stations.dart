import 'dart:math' as math;

import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

const nearbyAlertRadiusMeters = 2000.0;
const nearbyAlertLimit = 5;

class StationAlertGroup {
  const StationAlertGroup({
    required this.id,
    required this.name,
    required this.count,
    required this.highAlertCount,
    this.latitude,
    this.longitude,
    this.meters,
  });

  final String id;
  final String name;
  final int count;
  final int highAlertCount;
  final double? latitude;
  final double? longitude;
  final double? meters;

  StationAlertGroup withMeters(double meters) {
    return StationAlertGroup(
      id: id,
      name: name,
      count: count,
      highAlertCount: highAlertCount,
      latitude: latitude,
      longitude: longitude,
      meters: meters,
    );
  }
}

double metersBetween(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lon2 - lon1) * math.pi / 180;
  final a =
      math.pow(math.sin(dPhi / 2), 2) +
      math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda / 2), 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

List<StationAlertGroup> stationAlertGroups({
  required List<LiveBike> bikes,
  required List<BikeStation> stations,
}) {
  final byId = {for (final station in stations) station.id: station};
  final grouped = <String, StationAlertGroup>{};

  for (final bike in bikes) {
    final station = byId[bike.station];
    final current = grouped[bike.station];
    final name = station != null && station.name.isNotEmpty
        ? station.name
        : (bike.stationName.isNotEmpty ? bike.stationName : bike.station);
    grouped[bike.station] = StationAlertGroup(
      id: bike.station,
      name: name,
      count: (current?.count ?? 0) + 1,
      highAlertCount:
          (current?.highAlertCount ?? 0) + (bike.isHighAlert ? 1 : 0),
      latitude: station?.latitude,
      longitude: station?.longitude,
    );
  }

  return grouped.values.toList(growable: false);
}

List<StationAlertGroup> nearestAlertStations({
  required List<StationAlertGroup> groups,
  required double latitude,
  required double longitude,
  double withinMeters = nearbyAlertRadiusMeters,
  int limit = nearbyAlertLimit,
}) {
  final ranked =
      groups
          .where(
            (group) =>
                group.count > 0 &&
                group.latitude != null &&
                group.longitude != null,
          )
          .map(
            (group) => group.withMeters(
              metersBetween(
                latitude,
                longitude,
                group.latitude!,
                group.longitude!,
              ),
            ),
          )
          .where((group) => group.meters! <= withinMeters)
          .toList()
        ..sort((left, right) => left.meters!.compareTo(right.meters!));
  return ranked.take(limit).toList(growable: false);
}

List<StationAlertGroup> savedStationAlerts({
  required List<LiveBike> bikes,
  required List<BikeStation> stations,
  required List<String> savedIds,
}) {
  final grouped = {
    for (final group in stationAlertGroups(bikes: bikes, stations: stations))
      group.id: group,
  };
  final byId = {for (final station in stations) station.id: station};

  return [
    for (final id in savedIds)
      grouped[id] ??
          StationAlertGroup(
            id: id,
            name: byId[id]?.name.isNotEmpty == true ? byId[id]!.name : id,
            count: 0,
            highAlertCount: 0,
            latitude: byId[id]?.latitude,
            longitude: byId[id]?.longitude,
          ),
  ];
}

LiveBike? firstBikeAt(List<LiveBike> bikes, String stationId) {
  LiveBike? fallback;
  for (final bike in bikes) {
    if (bike.station != stationId) continue;
    if (bike.isHighAlert) return bike;
    fallback ??= bike;
  }
  return fallback;
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}
