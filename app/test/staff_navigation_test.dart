import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/staff/pickup_plan.dart';
import 'package:ridey_app/features/staff/staff_navigation_page.dart';

void main() {
  const a = PlanStation(
    id: 'A',
    name: '가 대여소',
    latitude: 37.5,
    longitude: 127.0,
  );
  const b = PlanStation(
    id: 'B',
    name: '나 대여소',
    latitude: 37.51,
    longitude: 127.0,
  );
  const c = PlanStation(
    id: 'C',
    name: '다 대여소',
    latitude: 37.52,
    longitude: 127.0,
  );
  const bike = LiveBike(
    bike: 'SPB-12345',
    station: 'A',
    stationName: '가 대여소',
    chain: 3,
    isHighAlert: true,
    lastDud: '2026-11-06 08:00',
    probability: 60,
  );
  const plan = PickupPlan(
    stops: [
      PlanStop(station: a, leg: 0, suspects: [bike], pickUp: 3, loadAfter: 3),
      PlanStop(station: b, leg: 1100, dropOff: 3),
      PlanStop(station: c, leg: 1100, pickUp: 2, loadAfter: 2),
    ],
  );

  testWidgets('counts what was done at stops reached, not skipped ones', (
    tester,
  ) async {
    final moves = StreamController<DeviceLocation>();
    await tester.pumpWidget(
      MaterialApp(
        theme: RideyTheme.light(),
        home: StaffNavigationPage(
          plan: plan,
          start: (latitude: 37.5, longitude: 127.0),
          positions: moves.stream,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('이번 길'), findsNothing);

    // 첫 곳에 도착해서 넘김 → 거둔 1대, 실은 3대
    await tester.tap(find.text('다음 곳으로'));
    await tester.pump();
    expect(find.text('이번 길: 고장 의심 1대 거둠 · 3대 실음'), findsOneWidget);

    // 둘째 곳은 가지 않고 건너뜀 → 대수는 그대로
    await tester.tap(find.text('이곳 건너뛰기'));
    await tester.pump();
    expect(find.text('이번 길: 고장 의심 1대 거둠 · 3대 실음'), findsOneWidget);

    // 셋째 곳에 도착해서 마침
    moves.add((latitude: 37.52, longitude: 127.0));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('마치기'));
    await tester.pump();
    expect(find.text('추천 경로를 모두 돌았어요'), findsOneWidget);
    expect(find.text('이번 길: 고장 의심 1대 거둠 · 5대 실음'), findsOneWidget);
    await moves.close();
  });
}
