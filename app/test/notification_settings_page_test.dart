import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/notifications/notification_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('turns notifications on only when the user allows them', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var requested = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: RideyTheme.light(),
        home: NotificationSettingsPage(
          setEnabled: (enabled) async {
            requested = true;
            return enabled;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('꺼져 있어요'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(requested, isTrue);
    expect(find.text('켜져 있어요'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('꺼져 있어요'), findsOneWidget);
  });

  testWidgets('explains when notification permission is denied', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        theme: RideyTheme.light(),
        home: NotificationSettingsPage(setEnabled: (enabled) async => false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('알림 권한이 없어 켜지지 않았어요.'), findsOneWidget);
    expect(find.text('꺼져 있어요'), findsOneWidget);
  });
}
