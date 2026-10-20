import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';

void main() {
  const bikes = [
    LiveBike(
      bike: 'SPB-69683',
      station: '02720',
      stationName: '힐스테이트에코',
      chain: 3,
      isHighAlert: true,
      lastDud: '10-20 14:58',
      probability: 48,
    ),
  ];

  test('normalizes bike number formats used by the existing app', () {
    expect(normalizeBikeId('spb 9683'), 'SPB-09683');
    expect(normalizeBikeId('SPB-69683'), 'SPB-69683');
    expect(normalizeBikeId('69683'), isNull);
  });

  test('finds a bike after normalization', () {
    expect(findBike(bikes, 'spb-69683'), same(bikes.single));
    expect(findBike(bikes, 'SPB-12345'), isNull);
  });
}
