import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ridey_app/features/live/station_status_repository.dart';

void main() {
  test('reads every page, not only the first 1,000 stations', () async {
    final ranges = <String>[];
    final client = MockClient((request) async {
      final range = request.headers['Range']!;
      ranges.add(range);
      final from = int.parse(range.split('-').first);
      final count = from < 2000 ? 1000 : 37; // 2,037곳
      final rows = [
        for (var i = 0; i < count; i++)
          {
            'id': '${from + i}'.padLeft(5, '0'),
            'name': 's',
            'bikes': 1,
            'racks': 10,
          },
      ];
      return http.Response(jsonEncode(rows), 200);
    });

    final stations = await SupabaseStationStatusRepository(
      client: client,
    ).fetch();

    expect(stations, hasLength(2037));
    expect(ranges, ['0-999', '1000-1999', '2000-2999']);
  });
}
