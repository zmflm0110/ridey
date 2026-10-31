import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/ops/ops_list.dart';

void main() {
  test('reads morning bikes from a public ops_lists row', () {
    final list = OpsList.fromRow('2026-10-20', {
      'body': {
        'date': '2026-10-20',
        'bikes': [
          {
            'bike': 'SPB-69683',
            'station': '02720',
            'station_name': '힐스테이트에코',
            'chain': 3,
            'level': '빨강',
            'last_dud': '10-19 23:10',
          },
        ],
      },
    });

    expect(list.day, '2026-10-20');
    expect(list.bikes.single.bike, 'SPB-69683');
    expect(list.bikes.single.isHighAlert, isTrue);
    expect(list.bikes.single.probability, isNull);
  });
}
