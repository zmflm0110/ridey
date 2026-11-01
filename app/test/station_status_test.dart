import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/station_status.dart';
import 'package:ridey_app/features/live/station_status_repository.dart';

void main() {
  test('reads the five-digit station id from a bikeList name', () {
    expect(stationIdFromBikeListName('102. 망원역 1번출구 앞'), '00102');
    expect(stationIdFromBikeListName('2720.힐스테이트에코'), '02720');
    expect(stationIdFromBikeListName('망원역'), isNull);
  });

  test('parses occupancy rows and skips a blank id', () {
    final rows = parseStationOccupancy('''
      [
        {"id":"00102","name":"102. 망원역 1번출구 앞","bikes":5,"racks":15,"lat":37.5,"lon":126.9,"at":"2026-11-01T12:00:00"},
        {"id":"","name":"없음","bikes":1,"racks":1}
      ]
    ''');

    expect(rows, hasLength(1));
    expect(rows.single.id, '00102');
    expect(rows.single.bikes, 5);
    expect(rows.single.racks, 15);
    expect(rows.single.latitude, 37.5);
  });
}
