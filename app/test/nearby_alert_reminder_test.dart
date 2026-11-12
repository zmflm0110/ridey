import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/features/notifications/nearby_alert_reminder.dart';

void main() {
  test('joins nearby alert numbers and trims a long list', () {
    expect(nearbyAlertReminderText(const []), '');
    expect(
      nearbyAlertReminderText(const ['SPB-12345', 'SPB-23456']),
      '고장 의심 자전거: SPB-12345, SPB-23456',
    );
    expect(
      nearbyAlertReminderText(const [
        'SPB-1',
        'SPB-2',
        'SPB-3',
        'SPB-4',
        'SPB-5',
      ]),
      '고장 의심 자전거: SPB-1, SPB-2, SPB-3, SPB-4 외 1대',
    );
    expect(nearbyAlertCompactText(const ['SPB-1', 'SPB-2']), '2');
  });

  testWidgets('sends the first three numbers to the Dynamic Island', (
    tester,
  ) async {
    const channel = MethodChannel('ridey/nearby_alert_test');
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    await PlatformNearbyAlertReminder(
      channel: channel,
      platform: TargetPlatform.iOS,
    ).sync(const ['SPB-1', 'SPB-2', 'SPB-3', 'SPB-4']);
    expect(calls.single.method, 'show');
    final args = calls.single.arguments as Map;
    expect(args['bikes'], ['SPB-1', 'SPB-2', 'SPB-3']);
    expect(args['compact'], '4');
    expect(args['text'], '고장 의심 자전거: SPB-1, SPB-2, SPB-3, SPB-4');
  });
}
