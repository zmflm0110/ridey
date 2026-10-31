import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';

void main() {
  test('uses the morning list before noon when today exists', () {
    final now = DateTime.utc(2026, 10, 20, 1); // 10:00 in Seoul
    final choice = resolveWorklist(
      days: const ['2026-10-20', '2026-10-19'],
      now: now,
    );
    expect(choice.source, ListSource.morning);
    expect(choice.day, '2026-10-20');
  });

  test('falls back to live after noon', () {
    final now = DateTime.utc(2026, 10, 20, 4); // 13:00 in Seoul
    final choice = resolveWorklist(days: const ['2026-10-20'], now: now);
    expect(choice.source, ListSource.live);
    expect(choice.day, isNull);
  });
}
