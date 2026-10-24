import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const habitNotificationUniqueName = 'ridey.habit-notification';
const habitNotificationTaskName = 'habitNotification';
const habitNotificationsEnabledKey = 'habit_notifications_enabled';
const habitNotificationSentOnKey = 'habit_notification_sent_on';
const habitNotificationRadiusMeters = 1000.0;
const habitNotificationLead = Duration(minutes: 15);
const habitSlotMinimumCount = 2;

class HabitSlot {
  const HabitSlot({required this.weekday, required this.hour});

  final int weekday;
  final int hour;

  @override
  bool operator ==(Object other) =>
      other is HabitSlot && other.weekday == weekday && other.hour == hour;

  @override
  int get hashCode => Object.hash(weekday, hour);
}

class HabitNotificationStore {
  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(habitNotificationsEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(habitNotificationsEnabledKey, enabled);
  }

  Future<DateTime?> lastSent() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(habitNotificationSentOnKey);
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  Future<void> markSent(DateTime when) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      habitNotificationSentOnKey,
      habitNotificationDayKey(when),
    );
  }
}

String habitNotificationDayKey(DateTime when) {
  final local = when.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
}

bool alreadySentToday(DateTime? lastSent, DateTime now) {
  if (lastSent == null) return false;
  return habitNotificationDayKey(lastSent) == habitNotificationDayKey(now);
}

List<HabitSlot> habitSlots(
  List<LookupEvent> events, {
  int minimum = habitSlotMinimumCount,
}) {
  final counts = <HabitSlot, int>{};
  for (final event in events) {
    final local = event.at.toLocal();
    final slot = HabitSlot(weekday: local.weekday, hour: local.hour);
    counts[slot] = (counts[slot] ?? 0) + 1;
  }
  return [
    for (final entry in counts.entries)
      if (entry.value >= minimum) entry.key,
  ];
}

bool isInsideHabitWindow(
  DateTime now,
  HabitSlot slot, {
  Duration lead = habitNotificationLead,
}) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final tomorrow = today.add(const Duration(days: 1));
  DateTime? start;
  if (local.weekday == slot.weekday) {
    start = DateTime(local.year, local.month, local.day, slot.hour);
  } else if (tomorrow.weekday == slot.weekday) {
    start = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, slot.hour);
  }
  if (start == null) return false;
  final open = start.subtract(lead);
  final close = start.add(const Duration(hours: 1));
  return !local.isBefore(open) && local.isBefore(close);
}

({double latitude, double longitude})? habitLocation(List<LookupEvent> events) {
  final counts = <String, int>{};
  final latest = <String, DateTime>{};
  final points = <String, ({double latitude, double longitude})>{};
  for (final event in events) {
    final latitude = event.latitude;
    final longitude = event.longitude;
    if (latitude == null || longitude == null) continue;
    final key = '$latitude,$longitude';
    counts[key] = (counts[key] ?? 0) + 1;
    final previous = latest[key];
    if (previous == null || event.at.isAfter(previous)) {
      latest[key] = event.at;
      points[key] = (latitude: latitude, longitude: longitude);
    }
  }
  String? best;
  for (final key in counts.keys) {
    final current = best;
    if (current == null ||
        counts[key]! > counts[current]! ||
        (counts[key] == counts[current] &&
            latest[key]!.isAfter(latest[current]!))) {
      best = key;
    }
  }
  return best == null ? null : points[best];
}

int suspectBikesNear({
  required List<LiveBike> bikes,
  required List<BikeStation> stations,
  required double latitude,
  required double longitude,
  double withinMeters = habitNotificationRadiusMeters,
}) {
  final byId = {for (final station in stations) station.id: station};
  var count = 0;
  for (final bike in bikes) {
    final station = byId[bike.station];
    if (station == null) continue;
    final meters = metersBetween(
      latitude,
      longitude,
      station.latitude,
      station.longitude,
    );
    if (meters <= withinMeters) count += 1;
  }
  return count;
}

String? habitNotificationBody({
  required bool enabled,
  required DateTime now,
  required List<LookupEvent> events,
  required DateTime? lastSent,
  required List<LiveBike> bikes,
  required List<BikeStation> stations,
}) {
  if (!enabled || alreadySentToday(lastSent, now)) return null;
  final slots = habitSlots(events);
  if (!slots.any((slot) => isInsideHabitWindow(now, slot))) return null;
  final place = habitLocation(events);
  if (place == null) return null;
  final count = suspectBikesNear(
    bikes: bikes,
    stations: stations,
    latitude: place.latitude,
    longitude: place.longitude,
  );
  if (count < 1) return null;
  return '현재 계신 지역에 $count개의 고장 의심 자전거가 있어요';
}

@pragma('vm:entry-point')
void habitNotificationDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await deliverHabitNotification();
    } catch (_) {}
    return true;
  });
}

Future<void> deliverHabitNotification({
  LiveSnapshotRepository? snapshots,
  StationRepository? stations,
  HabitNotificationStore? settings,
  LookupHabitStore? habits,
  DateTime? now,
  Future<void> Function(String message)? show,
}) async {
  final clock = now ?? DateTime.now();
  final settingStore = settings ?? HabitNotificationStore();
  final habitStore = habits ?? LookupHabitStore();
  final enabled = await settingStore.isEnabled();
  final events = await habitStore.load(now: clock);
  final lastSent = await settingStore.lastSent();
  if (!enabled ||
      alreadySentToday(lastSent, clock) ||
      habitLocation(events) == null ||
      !habitSlots(events).any((slot) => isInsideHabitWindow(clock, slot))) {
    return;
  }

  final snapshot = await (snapshots ?? SupabaseLiveSnapshotRepository())
      .fetch();
  final catalog = await (stations ?? BundledStationRepository()).fetch();
  final message = habitNotificationBody(
    enabled: enabled,
    now: clock,
    events: events,
    lastSent: lastSent,
    bikes: snapshot.bikes,
    stations: catalog,
  );
  if (message == null) return;
  await (show ?? showHabitNotification)(message);
  await settingStore.markSent(clock);
}

const _notificationSettings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
);

Future<void> showHabitNotification(String message) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: _notificationSettings);
  await plugin.show(
    id: 710,
    title: 'RIDEY',
    body: message,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'habit-alerts',
        '습관 알림',
        channelDescription: '자주 확인하는 시간대에 주변 고장 의심 자전거를 알려 줘요.',
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

Future<bool> requestHabitNotificationPermission() async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(settings: _notificationSettings);
  if (defaultTargetPlatform == TargetPlatform.android) {
    final granted = await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    return granted ?? false;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final granted = await plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true);
    return granted ?? false;
  }
  return false;
}

Future<bool> setHabitNotificationsEnabled(bool enabled) async {
  final store = HabitNotificationStore();
  if (!enabled) {
    await store.setEnabled(false);
    try {
      await Workmanager().cancelByUniqueName(habitNotificationUniqueName);
    } catch (_) {}
    return false;
  }
  try {
    final allowed = await requestHabitNotificationPermission();
    if (!allowed) {
      await store.setEnabled(false);
      return false;
    }
    await Workmanager().initialize(habitNotificationDispatcher);
    await Workmanager().registerPeriodicTask(
      habitNotificationUniqueName,
      habitNotificationTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    await store.setEnabled(true);
    return true;
  } catch (_) {
    await store.setEnabled(false);
    return false;
  }
}
