import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';

void main() {
  test('keeps at most five saved stations and preserves duplicate entries', () {
    expect(addSavedStation(const ['a', 'b', 'c', 'd', 'e'], 'f'), [
      'b',
      'c',
      'd',
      'e',
      'f',
    ]);
    expect(addSavedStation(const ['a', 'b'], 'a'), ['a', 'b']);
  });

  test('removes a saved station without changing order', () {
    expect(removeSavedStation(const ['a', 'b', 'c'], 'b'), ['a', 'c']);
  });
}
