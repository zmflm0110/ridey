import 'dart:math' as math;

import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/station_status.dart';
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

/// One suspect bike placed at its station, with distance when the user location is known.
class NearbyBike {
  const NearbyBike({
    required this.bike,
    required this.stationName,
    this.latitude,
    this.longitude,
    this.meters,
  });

  final LiveBike bike;
  final String stationName;
  final double? latitude;
  final double? longitude;
  final double? meters;
}

String stationDisplayName(LiveBike bike, BikeStation? station) {
  if (station != null && station.name.isNotEmpty) return station.name;
  if (bike.stationName.isNotEmpty) return bike.stationName;
  return bike.station;
}

/// Suspect bikes whose station is within [withinMeters] of the user, nearest first.
List<NearbyBike> bikesNear({
  required List<LiveBike> bikes,
  required List<BikeStation> stations,
  required double latitude,
  required double longitude,
  double withinMeters = nearbyAlertRadiusMeters,
}) {
  final byId = {for (final station in stations) station.id: station};
  final nearby = <NearbyBike>[];
  for (final bike in bikes) {
    final station = byId[bike.station];
    final lat = station?.latitude;
    final lon = station?.longitude;
    if (lat == null || lon == null) continue;
    final meters = metersBetween(latitude, longitude, lat, lon);
    if (meters > withinMeters) continue;
    nearby.add(
      NearbyBike(
        bike: bike,
        stationName: stationDisplayName(bike, station),
        latitude: lat,
        longitude: lon,
        meters: meters,
      ),
    );
  }
  nearby.sort((a, b) {
    final byMeters = a.meters!.compareTo(b.meters!);
    if (byMeters != 0) return byMeters;
    return a.bike.bike.compareTo(b.bike.bike);
  });
  return nearby;
}

/// Suspect bikes at the saved stations, in the order those stations were saved.
List<NearbyBike> bikesAtStations({
  required List<LiveBike> bikes,
  required List<BikeStation> stations,
  required List<String> stationIds,
}) {
  final byId = {for (final station in stations) station.id: station};
  final wanted = stationIds.toSet();
  final order = {for (var i = 0; i < stationIds.length; i++) stationIds[i]: i};
  final listed = <NearbyBike>[];
  for (final bike in bikes) {
    if (!wanted.contains(bike.station)) continue;
    final station = byId[bike.station];
    listed.add(
      NearbyBike(
        bike: bike,
        stationName: stationDisplayName(bike, station),
        latitude: station?.latitude,
        longitude: station?.longitude,
      ),
    );
  }
  listed.sort((a, b) {
    final byStation = (order[a.bike.station] ?? 0).compareTo(
      order[b.bike.station] ?? 0,
    );
    if (byStation != 0) return byStation;
    return a.bike.bike.compareTo(b.bike.bike);
  });
  return listed;
}

/// Nearby (or saved) station with live rack counts and RIDEY alert counts.
class NearbyStationRow {
  const NearbyStationRow({
    required this.id,
    required this.name,
    required this.alertCount,
    required this.highAlertCount,
    this.parkedBikes,
    this.latitude,
    this.longitude,
    this.meters,
  });

  final String id;
  final String name;
  final int alertCount;
  final int highAlertCount;
  final int? parkedBikes;
  final double? latitude;
  final double? longitude;
  final double? meters;

  /// Estimate: parked bikes minus RIDEY alerts. Null when occupancy is unknown.
  int? get choosableCount {
    final parked = parkedBikes;
    if (parked == null) return null;
    return math.max(0, parked - alertCount);
  }
}

List<NearbyStationRow> nearbyStationRows({
  required List<BikeStation> stations,
  required List<LiveBike> bikes,
  required List<StationOccupancy> occupancy,
  required double latitude,
  required double longitude,
  double withinMeters = nearbyAlertRadiusMeters,
}) {
  final alerts = {
    for (final group in stationAlertGroups(bikes: bikes, stations: stations))
      group.id: group,
  };
  final byOcc = {for (final row in occupancy) row.id: row};
  final rows = <NearbyStationRow>[];
  for (final station in stations) {
    final meters = metersBetween(
      latitude,
      longitude,
      station.latitude,
      station.longitude,
    );
    if (meters > withinMeters) continue;
    final alert = alerts[station.id];
    rows.add(
      NearbyStationRow(
        id: station.id,
        name: station.name.isNotEmpty ? station.name : station.id,
        alertCount: alert?.count ?? 0,
        highAlertCount: alert?.highAlertCount ?? 0,
        parkedBikes: byOcc[station.id]?.bikes,
        latitude: station.latitude,
        longitude: station.longitude,
        meters: meters,
      ),
    );
  }
  rows.sort((a, b) => a.meters!.compareTo(b.meters!));
  return rows;
}

List<NearbyStationRow> savedStationRows({
  required List<BikeStation> stations,
  required List<LiveBike> bikes,
  required List<StationOccupancy> occupancy,
  required List<String> stationIds,
}) {
  final byId = {for (final station in stations) station.id: station};
  final alerts = {
    for (final group in stationAlertGroups(bikes: bikes, stations: stations))
      group.id: group,
  };
  final byOcc = {for (final row in occupancy) row.id: row};
  return [
    for (final id in stationIds)
      NearbyStationRow(
        id: id,
        name: byId[id]?.name.isNotEmpty == true ? byId[id]!.name : id,
        alertCount: alerts[id]?.count ?? 0,
        highAlertCount: alerts[id]?.highAlertCount ?? 0,
        parkedBikes: byOcc[id]?.bikes,
        latitude: byId[id]?.latitude,
        longitude: byId[id]?.longitude,
      ),
  ];
}

/// 걸어서 걸리는 시간(분) 어림: 직선거리 × 1.3(길이 굽는 몫) ÷ 분당 67m(시속 4km). 최소 1분.
/// 길찾기 서버 없이 쓰는 어림이라 화면에는 '약' 을 붙인다.
int walkMinutes(double meters) => math.max(1, (meters * 1.3 / 67).round());

/// 거리 글자: 1km 아래는 m, 위는 소수 한 자리 km.
String distanceText(double meters) => meters < 1000
    ? '${meters.round()}m'
    : '${(meters / 1000).toStringAsFixed(1)}km';
