import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';

void main() {
  testWidgets('switches between the shared app destinations', (tester) async {
    await tester.pumpWidget(const RideyApp());

    expect(find.text('타기 전에,\n확인하세요.'), findsOneWidget);
    expect(find.text('업무'), findsOneWidget);

    await tester.tap(find.text('업무'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 먼저\n볼 곳.'), findsOneWidget);

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    expect(find.text('화면 모드'), findsOneWidget);
  });

  testWidgets('changes the app appearance from settings', (tester) async {
    await tester.pumpWidget(const RideyApp());
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(Switch))).brightness,
      Brightness.dark,
    );
  });
}
