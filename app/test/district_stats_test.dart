import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

void main() {
  const gangnam = BikeStation(
    id: '02720',
    name: '힐스테이트에코',
    district: '강남구',
    latitude: 37.5,
    longitude: 127.0,
  );
  const mapo = BikeStation(
    id: '00100',
    name: '망원역',
    district: '마포구',
    latitude: 37.55,
    longitude: 126.9,
  );

  test('sums expected faults and groups districts', () {
    const bikes = [
      LiveBike(
        bike: 'SPB-00001',
        station: '02720',
        stationName: '힐스테이트에코',
        chain: 3,
        isHighAlert: true,
        lastDud: '10-20 14:00',
        probability: 50,
      ),
      LiveBike(
        bike: 'SPB-00002',
        station: '02720',
        stationName: '힐스테이트에코',
        chain: 2,
        isHighAlert: false,
        lastDud: '10-20 14:01',
        probability: 20,
      ),
      LiveBike(
        bike: 'SPB-00003',
        station: '00100',
        stationName: '망원역',
        chain: 2,
        isHighAlert: false,
        lastDud: '10-20 14:02',
        probability: 10,
      ),
    ];
    final stations = {gangnam.id: gangnam, mapo.id: mapo};
    final rows = districtRows(bikes, stations);

    expect(rows.first.district, '강남구');
    expect(rows.first.bikes, 2);
    expect(rows.first.highAlerts, 1);
    expect(rows.first.expected, closeTo(0.7, 0.001));
    expect(rows.last.district, '마포구');
    expect(expectOf(bikes), closeTo(0.8, 0.001));
    expect(formatExpected(null), '–');
  });

  test('treats a missing station district as other', () {
    const bike = LiveBike(
      bike: 'SPB-00009',
      station: '99999',
      stationName: '없는 곳',
      chain: 2,
      isHighAlert: false,
      lastDud: '',
      probability: null,
    );
    expect(districtOf(bike, const {}), '기타');
    expect(expectOf([bike]), isNull);
  });
}
