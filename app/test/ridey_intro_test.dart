import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('start animation text has no missing-Material underline', (
    tester,
  ) async {
    // 두 번째 실행부터만 시작 애니메이션이 나온다(첫 실행은 서울 지도 화면이 그 장면을 맡음).
    SharedPreferences.setMockInitialValues({'user_mode': 'rider'});
    await tester.pumpWidget(
      RideyApp(
        showIntro: true,
        readLocation: () async => null,
        enableCamera: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));
    // 글자 'R' 이 Material 아래에서 그려져야 노란 밑줄이 없다.
    final letter = find.text('R').first;
    expect(
      find.ancestor(of: letter, matching: find.byType(Material)),
      findsWidgets,
    );
    final style = DefaultTextStyle.of(tester.element(letter)).style;
    expect(style.decoration, isNot(TextDecoration.underline));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
