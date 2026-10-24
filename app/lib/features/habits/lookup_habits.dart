import 'dart:convert';
import 'dart:math' as math;

import 'package:ridey_app/features/location/device_location.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lookupHabitRetention = Duration(days: 14);
const lookupGridMeters = 500.0;
const lookupHabitsKey = 'lookup_habits';

enum LookupKind { number, qr, ocr, station }

class LookupEvent {
  const LookupEvent({
    required this.kind,
    required this.at,
    this.latitude,
    this.longitude,
    this.subject,
  });

  final LookupKind kind;
  final DateTime at;
  final double? latitude;
  final double? longitude;
  final String? subject;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'at': at.toUtc().toIso8601String(),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (subject != null && subject!.isNotEmpty) 'subject': subject,
  };

  static LookupEvent? fromJson(Object? value) {
    if (value is! Map) return null;
    final kind = _kind(value['kind']);
    final at = DateTime.tryParse('${value['at']}');
    if (kind == null || at == null) return null;
    return LookupEvent(
      kind: kind,
      at: at.toLocal(),
      latitude: (value['latitude'] as num?)?.toDouble(),
      longitude: (value['longitude'] as num?)?.toDouble(),
      subject: value['subject'] as String?,
    );
  }
}

LookupKind? _kind(Object? value) {
  for (final kind in LookupKind.values) {
    if (kind.name == value) return kind;
  }
  return null;
}

/// Snaps a point onto a grid of about 500m so the saved habit is not a precise fix.
({double latitude, double longitude}) snapToGrid(
  double latitude,
  double longitude,
) {
  const metersPerDegree = 111320.0;
  final latStep = lookupGridMeters / metersPerDegree;
  final latitudeSnapped =
      ((latitude / latStep).round() * latStep * 1e5).round() / 1e5;
  final cosLat = math.cos(latitudeSnapped * math.pi / 180).abs();
  final lonStep =
      lookupGridMeters / (metersPerDegree * (cosLat < 0.01 ? 0.01 : cosLat));
  final longitudeSnapped =
      ((longitude / lonStep).round() * lonStep * 1e5).round() / 1e5;
  return (latitude: latitudeSnapped, longitude: longitudeSnapped);
}

List<LookupEvent> retainLookupEvents(List<LookupEvent> events, DateTime now) {
  final cutoff = now.subtract(lookupHabitRetention);
  return events
      .where((event) => !event.at.isBefore(cutoff))
      .toList(growable: false);
}

List<LookupEvent> decodeLookupEvents(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .map(LookupEvent.fromJson)
        .whereType<LookupEvent>()
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}

String encodeLookupEvents(List<LookupEvent> events) {
  return jsonEncode(events.map((event) => event.toJson()).toList());
}

String lookupKindLabel(LookupKind kind) {
  return switch (kind) {
    LookupKind.number => '번호 조회',
    LookupKind.qr => 'QR 조회',
    LookupKind.ocr => '번호판 조회',
    LookupKind.station => '대여소 조회',
  };
}

String formatLookupTime(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class LookupHabitStore {
  Future<List<LookupEvent>> load({DateTime? now}) async {
    final preferences = await SharedPreferences.getInstance();
    final events = retainLookupEvents(
      decodeLookupEvents(preferences.getString(lookupHabitsKey)),
      now ?? DateTime.now(),
    );
    await preferences.setString(lookupHabitsKey, encodeLookupEvents(events));
    return events;
  }

  Future<List<LookupEvent>> add(LookupEvent event, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final next = retainLookupEvents([
      ...decodeLookupEvents(
        (await SharedPreferences.getInstance()).getString(lookupHabitsKey),
      ),
      event,
    ], clock);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(lookupHabitsKey, encodeLookupEvents(next));
    return next;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(lookupHabitsKey);
  }
}

Future<void> rememberLookup({
  required LookupKind kind,
  String? subject,
  DateTime? at,
  Future<DeviceLocation?> Function()? readLocation,
  LookupHabitStore? store,
}) async {
  try {
    DeviceLocation? location;
    try {
      location = await (readLocation ?? readDeviceLocation)();
    } catch (_) {
      location = null;
    }
    final snapped = location == null
        ? null
        : snapToGrid(location.latitude, location.longitude);
    await (store ?? LookupHabitStore()).add(
      LookupEvent(
        kind: kind,
        at: at ?? DateTime.now(),
        latitude: snapped?.latitude,
        longitude: snapped?.longitude,
        subject: subject,
      ),
    );
  } catch (_) {}
}
