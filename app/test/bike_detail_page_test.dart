import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';

void main() {
  testWidgets('shows the alert without a staff field check', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: RideyTheme.light(),
        home: BikeDetailPage(
          bike: LiveBike(
            bike: 'SPB-69683',
            station: '02720',
            stationName: '힐스테이트에코',
            chain: 3,
            isHighAlert: true,
            lastDud: '10-20 14:58',
            probability: 48,
            reasons: [AlertReason(text: '서로 다른 3명이 연달아 반납', deltaPoints: 12)],
          ),
          updatedAt: DateTime.now(),
        ),
      ),
    );

    expect(find.text('고장이 의심되는 자전거예요.'), findsOneWidget);
    expect(find.textContaining('서로 다른 3명'), findsOneWidget);
    await tester.tap(find.text('판단 근거 확인하기'));
    await tester.pumpAndSettle();
    expect(find.text('판단 근거'), findsOneWidget);
    expect(find.text('서로 다른 3명이 연달아 반납'), findsOneWidget);
    expect(find.text('+12%p'), findsOneWidget);
    expect(find.text('현장에서 확인하기'), findsNothing);
    expect(find.textContaining('현장 확인'), findsNothing);
  });
}
