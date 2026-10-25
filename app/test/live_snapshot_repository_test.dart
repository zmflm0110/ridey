import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/widgets/ridey_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _row = {
  'at': '2026-10-25T15:40:00+09:00',
  'body': {
    'date': '2026-10-25',
    'feed': {'ok': true},
    'bikes': [
      {'bike': 'SPB-12345', 'station': '00101', 'chain': 2, 'level': '주황'},
    ],
  },
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('falls back to the last snapshot when the network fails', () async {
    final online = SupabaseLiveSnapshotRepository(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode([_row])),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final fresh = await online.fetch();
    expect(fresh.isOffline, isFalse);
    expect(fresh.feed.isHealthy, isTrue);

    final offline = SupabaseLiveSnapshotRepository(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final cached = await offline.fetch();
    expect(cached.isOffline, isTrue);
    expect(cached.bikes.single.bike, 'SPB-12345');
    // A saved copy can't clear unlisted bikes, so it must not read as healthy.
    expect(cached.feed.isHealthy, isFalse);
  });

  test('still fails when nothing was ever saved', () async {
    final repository = SupabaseLiveSnapshotRepository(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(repository.fetch(), throwsA(isA<LiveSnapshotException>()));
  });

  test('says how old the data is in minutes, hours, then days', () {
    final now = DateTime(2026, 10, 25, 12);
    expect(rideyAgo(now, now: now), '방금');
    expect(rideyAgo(now.subtract(const Duration(minutes: 12)), now: now), '12분 전');
    expect(rideyAgo(now.subtract(const Duration(hours: 3)), now: now), '3시간 전');
    expect(rideyAgo(now.subtract(const Duration(days: 2)), now: now), '2일 전');
  });
}
