import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/work/work_queue.dart';

void main() {
  const bikes = [
    LiveBike(
      bike: 'SPB-00001',
      station: '001',
      stationName: '첫 대여소',
      chain: 2,
      isHighAlert: false,
      lastDud: '',
      probability: 30,
    ),
    LiveBike(
      bike: 'SPB-00002',
      station: '002',
      stationName: '둘째 대여소',
      chain: 3,
      isHighAlert: true,
      lastDud: '',
      probability: 25,
    ),
    LiveBike(
      bike: 'SPB-00003',
      station: '001',
      stationName: '첫 대여소',
      chain: 3,
      isHighAlert: true,
      lastDud: '',
      probability: 40,
    ),
  ];

  test('groups live alerts and ranks high-alert stations first', () {
    final tasks = buildStationTasks(bikes);

    expect(tasks, hasLength(2));
    expect(tasks.first.stationId, '001');
    expect(tasks.first.bikes, hasLength(2));
    expect(tasks.first.highAlertCount, 1);
    expect(tasks.first.totalChain, 5);
  });

  test('uses probability before chain when alert counts are tied', () {
    final tasks = buildStationTasks(const [
      LiveBike(
        bike: 'SPB-00004',
        station: '003',
        stationName: '셋째 대여소',
        chain: 7,
        isHighAlert: false,
        lastDud: '',
        probability: 20,
      ),
      LiveBike(
        bike: 'SPB-00005',
        station: '004',
        stationName: '넷째 대여소',
        chain: 1,
        isHighAlert: false,
        lastDud: '',
        probability: 40,
      ),
    ]);

    expect(tasks.first.stationId, '004');
  });
}
