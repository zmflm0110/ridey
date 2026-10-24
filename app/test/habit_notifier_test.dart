import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/notifications/habit_notifier.dart';
import 'package:ridey_app/features/stations/bike_station.dart';

void main() {
  final monday = DateTime(2026, 10, 26);

  LookupEvent habitAt(DateTime at) {
    return LookupEvent(
      kind: LookupKind.number,
      at: at,
      latitude: 37.5,
      longitude: 127.0,
      subject: 'SPB-00001',
    );
  }

  final events = [
    habitAt(DateTime(2026, 10, 19, 8, 5)),
    habitAt(DateTime(2026, 10, 12, 8, 40)),
  ];

  const stations = [
    BikeStation(
      id: '02720',
      name: '가까운 대여소',
      district: '강남구',
      latitude: 37.5,
      longitude: 127.0,
    ),
    BikeStation(
      id: '00102',
      name: '먼 대여소',
      district: '마포구',
      latitude: 37.56,
      longitude: 126.91,
    ),
  ];

  LiveBike bike(String id, String station) {
    return LiveBike(
      bike: id,
      station: station,
      stationName: station,
      chain: 3,
      isHighAlert: true,
      lastDud: '',
      probability: 40,
    );
  }

  String? body({
    bool enabled = true,
    DateTime? now,
    DateTime? lastSent,
    List<LiveBike>? bikes,
    List<LookupEvent>? lookups,
  }) {
    return habitNotificationBody(
      enabled: enabled,
      now: now ?? DateTime(2026, 10, 26, 8, 10),
      events: lookups ?? events,
      lastSent: lastSent,
      bikes: bikes ?? [bike('SPB-00001', '02720'), bike('SPB-00002', '00102')],
      stations: stations,
    );
  }

  test('opens from 15 minutes before the habit hour until the hour ends', () {
    const slot = HabitSlot(weekday: DateTime.monday, hour: 8);
    expect(isInsideHabitWindow(DateTime(2026, 10, 26, 7, 44), slot), isFalse);
    expect(isInsideHabitWindow(DateTime(2026, 10, 26, 7, 45), slot), isTrue);
    expect(isInsideHabitWindow(DateTime(2026, 10, 26, 8, 59), slot), isTrue);
    expect(isInsideHabitWindow(DateTime(2026, 10, 26, 9), slot), isFalse);
    expect(isInsideHabitWindow(DateTime(2026, 10, 27, 8, 10), slot), isFalse);

    const midnight = HabitSlot(weekday: DateTime.monday, hour: 0);
    expect(
      isInsideHabitWindow(DateTime(2026, 10, 25, 23, 50), midnight),
      isTrue,
    );
    expect(
      isInsideHabitWindow(DateTime(2026, 10, 25, 23, 40), midnight),
      isFalse,
    );
    expect(monday.weekday, DateTime.monday);
  });

  test('sends once inside the window when a nearby suspect bike exists', () {
    expect(body(), '현재 계신 지역에 1개의 고장 의심 자전거가 있어요');
  });

  test(
    'stays quiet when notifications are off, already sent, or none are near',
    () {
      expect(body(enabled: false), isNull);
      expect(body(lastSent: DateTime(2026, 10, 26, 7, 50)), isNull);
      expect(body(bikes: [bike('SPB-00002', '00102')]), isNull);
      expect(body(now: DateTime(2026, 10, 26, 11)), isNull);
      expect(body(lookups: [events.first]), isNull);
    },
  );
}
