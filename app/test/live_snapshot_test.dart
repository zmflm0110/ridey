import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';

void main() {
  test('parses the public live snapshot contract', () {
    final snapshot = LiveSnapshot.fromRow({
      'at': '2026-10-20T15:00:00+09:00',
      'body': {
        'date': '2026-10-20',
        'feed': {'ok': false, 'since': '2026-10-20T14:00', 'ratio': .24},
        'bikes': [
          {
            'bike': 'SPB-69683',
            'station': '02720',
            'station_name': '힐스테이트에코',
            'chain': 3,
            'level': '빨강',
            'last_dud': '10-20 14:58',
            'p_next': 48,
            'why': [
              {'t': '서로 다른 3명이 연달아 반납', 'd': 12},
              {'t': ' ', 'd': 4},
              'skip',
            ],
          },
        ],
      },
    });

    expect(snapshot.date, '2026-10-20');
    expect(snapshot.feed.isHealthy, isFalse);
    expect(snapshot.feed.ratio, .24);
    expect(snapshot.bikes.single.bike, 'SPB-69683');
    expect(snapshot.bikes.single.isHighAlert, isTrue);
    expect(snapshot.bikes.single.probability, 48);
    expect(snapshot.bikes.single.reasons.single.text, '서로 다른 3명이 연달아 반납');
    expect(snapshot.bikes.single.reasons.single.deltaLabel, '+12%p');
  });
}
