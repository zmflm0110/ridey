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

  test('bike sticker QR codes decode to the printed number', () {
    // 실제 번호표 사진(2026-11-05)의 QR 내용과 옆에 찍힌 번호.
    const samples = {
      '6va03gATEBjUem2w': 'SPB-72627',
      '6va03gATEBIu4g6t': 'SPB-63951',
      '6va03gATEBITEgIT': 'SPB-60160',
      '6va03gATEB6Xeg2x': 'SPB-58529',
      '6va03gATEBjueBAT': 'SPB-73400',
      // 같은 날 저녁 12장 중 QR 이 찍힌 11장(80000번대 새싹 따릉이 포함).
      '6va03gATEBIX4gIt': 'SPB-68961',
      '6va03gATEBIuEgET': 'SPB-63130',
      '6va03gATEBLteuIX': 'SPB-81768',
      '6va03gATEB6T4g2t': 'SPB-50921',
      '6va03gATEBLTeB6V': 'SPB-80454',
      '6va03gATEBIvEB2U': 'SPB-65022',
      '6va03gATEB6UEm2V': 'SPB-52224',
      '6va03gATEBLteBLx': 'SPB-81489',
      '6va03gATEBIxEgNt': 'SPB-69191',
      '6va03gATEBIU4BjT': 'SPB-62870',
      '6va03gATEBIxEBIv': 'SPB-69065',
    };
    for (final e in samples.entries) {
      expect(bikeIdFromQr(e.key), e.value, reason: e.key);
    }
    expect(bikeIdFromQr('https://example.com'), isNull);
    expect(bikeIdFromQr('6va03gATEBjUem2'), isNull);
    expect(bikeIdFromQr(''), isNull);
  });
}
