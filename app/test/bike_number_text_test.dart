import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/rider/bike_lookup.dart';
import 'package:ridey_app/features/rider/bike_number_text.dart';

void main() {
  test('digits: common look-alike letters become digits', () {
    expect(digitsOf('6O1 6 0'), '60160');
    expect(digitsOf('S8S29'), '58529');
    expect(digitsOf('7 2 6 2 7'), '72627');
  });

  test('a bike id needs 4 to 6 digits and the expected count', () {
    expect(bikeIdFromDigits('72627'), 'SPB-72627');
    expect(bikeIdFromDigits('3400'), 'SPB-03400');
    expect(bikeIdFromDigits('123'), isNull);
    expect(bikeIdFromDigits('7262', expected: 5), isNull);
  });

  test('digits stacked top to bottom are joined in order', () {
    Rect box(double top) => Rect.fromLTWH(300, top, 30, 40);
    expect(
      bikeIdFromStackedLines([
        ('0', box(240)),
        ('7', box(40)),
        ('3', box(90)),
        ('0', box(190)),
        ('4', box(140)),
        ('SEOUL', const Rect.fromLTWH(20, 20, 120, 30)),
      ]),
      'SPB-73400',
    );
    expect(bikeIdFromStackedLines([('7', box(40)), ('3', box(90))]), isNull);
  });

  test('bike sticker QR codes decode to the printed number', () {
    // 실제 번호표 5장(2026-11-05 사진)의 QR 내용과 옆에 찍힌 번호.
    const samples = {
      '6va03gATEBjUem2w': 'SPB-72627',
      '6va03gATEBIu4g6t': 'SPB-63951',
      '6va03gATEBITEgIT': 'SPB-60160',
      '6va03gATEB6Xeg2x': 'SPB-58529',
      '6va03gATEBjueBAT': 'SPB-73400',
    };
    for (final e in samples.entries) {
      expect(bikeIdFromQr(e.key), e.value, reason: e.key);
    }
    expect(bikeIdFromQr('https://example.com'), isNull);
    expect(bikeIdFromQr('6va03gATEBjUem2'), isNull);
    expect(bikeIdFromQr(''), isNull);
  });
}
