import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';

void main() {
  const bike = LiveBike(
    bike: 'SPB-69683',
    station: '02720',
    stationName: '힐스테이트에코',
    chain: 3,
    isHighAlert: true,
    lastDud: '10-20 14:58',
    probability: 48,
  );

  Future<void> pump(
    WidgetTester tester, {
    List<CheckedVerdictCount> checkedVerdicts = const [],
    void Function(BuildContext context)? onFieldCheck,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: RideyTheme.light(),
        home: BikeDetailPage(
          bike: bike,
          updatedAt: DateTime.now(),
          checkedVerdicts: checkedVerdicts,
          onFieldCheck: onFieldCheck,
        ),
      ),
    );
  }

  testWidgets('hides staff actions for a rider', (tester) async {
    await pump(tester);

    expect(find.text('피하세요.'), findsOneWidget);
    expect(find.text('현장에서 확인하기'), findsNothing);
    expect(find.textContaining('현장 확인'), findsNothing);
  });

  testWidgets('shows recorded checks and calls the field callback', (
    tester,
  ) async {
    var checks = 0;
    await pump(
      tester,
      checkedVerdicts: const [
        CheckedVerdictCount(label: '타이어', count: 1),
        CheckedVerdictCount(label: '문제 없음', count: 1),
      ],
      onFieldCheck: (_) => checks++,
    );

    expect(find.text('현장 확인 2건'), findsOneWidget);
    expect(find.text('타이어 1건 · 문제 없음 1건'), findsOneWidget);

    await tester.tap(find.text('현장에서 확인하기'));
    await tester.pump();

    expect(checks, 1);
  });
}
