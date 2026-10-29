import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

void main() {
  const near = BikeStation(
    id: '02720',
    name: '힐스테이트에코',
    district: '강남구',
    latitude: 37.50,
    longitude: 127.00,
  );
  const far = BikeStation(
    id: '00102',
    name: '망원역',
    district: '마포구',
    latitude: 37.56,
    longitude: 126.91,
  );

  const bikes = [
    LiveBike(
      bike: 'SPB-00001',
      station: '02720',
      stationName: '옛 이름',
      chain: 3,
      isHighAlert: true,
      lastDud: '',
      probability: 40,
    ),
    LiveBike(
      bike: 'SPB-00002',
      station: '02720',
      stationName: '옛 이름',
      chain: 2,
      isHighAlert: false,
      lastDud: '',
      probability: 20,
    ),
    LiveBike(
      bike: 'SPB-00003',
      station: '00102',
      stationName: '망원',
      chain: 2,
      isHighAlert: false,
      lastDud: '',
      probability: 20,
    ),
  ];

  test('measures about 111km per degree of latitude', () {
    expect(metersBetween(0, 0, 1, 0), closeTo(111195, 50));
  });

  test('groups suspect bikes and keeps the nearer stations', () {
    final groups = stationAlertGroups(bikes: bikes, stations: [near, far]);
    final nearGroup = groups.singleWhere((group) => group.id == '02720');

    expect(nearGroup.name, '힐스테이트에코');
    expect(nearGroup.count, 2);
    expect(nearGroup.highAlertCount, 1);

    final nearest = nearestAlertStations(
      groups: groups,
      latitude: 37.501,
      longitude: 127.001,
    );

    expect(nearest.single.id, '02720');
    expect(nearest.single.meters, lessThan(nearbyAlertRadiusMeters));
  });

  test('uses saved stations, including ones with no alert', () {
    final saved = savedStationAlerts(
      bikes: bikes,
      stations: [near, far],
      savedIds: ['00999', '02720'],
    );

    expect(saved.map((group) => group.id), ['00999', '02720']);
    expect(saved.first.count, 0);
    expect(saved.first.name, '00999');
    expect(saved.last.count, 2);
    expect(firstBikeAt(bikes, '02720')?.bike, 'SPB-00001');
  });

  test('lists suspect bikes near the user and skips far stations', () {
    final nearby = bikesNear(
      bikes: bikes,
      stations: [near, far],
      latitude: 37.501,
      longitude: 127.001,
    );

    expect(nearby.map((item) => item.bike.bike), ['SPB-00001', 'SPB-00002']);
    expect(nearby.first.stationName, '힐스테이트에코');
    expect(nearby.first.meters, lessThan(nearbyAlertRadiusMeters));
  });
}
