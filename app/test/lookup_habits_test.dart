import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('snaps nearby points onto the same 500m cell', () {
    final origin = snapToGrid(37.500, 127.000);
    final nearby = snapToGrid(37.501, 127.001);
    final far = snapToGrid(37.510, 127.000);

    expect(nearby.latitude, origin.latitude);
    expect(nearby.longitude, origin.longitude);
    expect((far.latitude - origin.latitude).abs(), greaterThan(0.004));
  });

  test('drops lookup events older than 14 days', () {
    final now = DateTime.utc(2026, 10, 25, 12);
    final kept = retainLookupEvents([
      LookupEvent(
        kind: LookupKind.number,
        at: now.subtract(const Duration(days: 13)),
      ),
      LookupEvent(
        kind: LookupKind.qr,
        at: now.subtract(const Duration(days: 14, seconds: 1)),
      ),
    ], now);

    expect(kept, hasLength(1));
    expect(kept.single.kind, LookupKind.number);
  });

  test('stores a snapped lookup and clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LookupHabitStore();
    final at = DateTime.utc(2026, 10, 25, 3, 10);

    await rememberLookup(
      kind: LookupKind.number,
      subject: 'SPB-69683',
      at: at,
      readLocation: () async => (latitude: 37.501, longitude: 127.001),
      store: store,
    );

    final events = await store.load(now: at.add(const Duration(hours: 1)));
    expect(events, hasLength(1));
    expect(events.single.kind, LookupKind.number);
    expect(events.single.subject, 'SPB-69683');
    expect(events.single.latitude, isNotNull);
    expect(events.single.latitude, snapToGrid(37.501, 127.001).latitude);

    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('ignores a corrupt habit payload', () {
    expect(decodeLookupEvents('{'), isEmpty);
    expect(
      decodeLookupEvents('[{"kind":"nope","at":"2026-10-25T00:00:00Z"}]'),
      isEmpty,
    );
  });
}
