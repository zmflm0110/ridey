// Renders the main screens to PNG for design review — the CI 'screens' job
// uploads them. Skipped unless RIDEY_SCREENS (output folder) and RIDEY_FONT
// (Korean font files, ':'-separated) are set, so plain `flutter test` ignores it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridey_app/app/ridey_app.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _out = Platform.environment['RIDEY_SCREENS'];
const _frame = ValueKey('screen-frame');

const _stations = [
  BikeStation(
    id: '02720',
    name: '힐스테이트에코',
    district: '강서구',
    latitude: 37.5600,
    longitude: 126.8370,
  ),
  BikeStation(
    id: '01105',
    name: '마곡나루역 2번 출구',
    district: '강서구',
    latitude: 37.5668,
    longitude: 126.8272,
  ),
  BikeStation(
    id: '01160',
    name: '발산역 1번 출구',
    district: '강서구',
    latitude: 37.5585,
    longitude: 126.8380,
  ),
  BikeStation(
    id: '00207',
    name: '망원역 1번 출구 앞',
    district: '마포구',
    latitude: 37.5560,
    longitude: 126.9100,
  ),
];

LiveBike _bike(
  String id,
  String station,
  String name,
  int chain,
  int? p, {
  List<AlertReason> why = const [],
}) => LiveBike(
  bike: id,
  station: station,
  stationName: name,
  chain: chain,
  isHighAlert: chain >= 3,
  lastDud: '10-25 15:${10 + chain}',
  probability: p,
  reasons: why,
);

class _Live implements LiveSnapshotRepository {
  @override
  Future<LiveSnapshot> fetch() async => LiveSnapshot(
    updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    date: '2026-10-25',
    feed: const FeedHealth(isHealthy: true),
    bikes: [
      _bike(
        'SPB-69683',
        '02720',
        '힐스테이트에코',
        5,
        48,
        why: const [
          AlertReason(text: '서로 다른 5명이 연달아 반납', deltaPoints: 21),
          AlertReason(text: '마지막 반납 뒤 40분째 그대로', deltaPoints: 6),
          AlertReason(text: '평소 많이 타는 대여소', deltaPoints: -3),
        ],
      ),
      _bike('SPB-41207', '02720', '힐스테이트에코', 2, 31),
      _bike('SPB-50579', '01105', '마곡나루역 2번 출구', 3, 39),
      _bike('SPB-74511', '01160', '발산역 1번 출구', 2, 27),
      _bike('SPB-30260', '00207', '망원역 1번 출구 앞', 4, 44),
      _bike('SPB-62508', '00207', '망원역 1번 출구 앞', 2, null),
    ],
  );
}

class _Stations implements StationRepository {
  @override
  Future<List<BikeStation>> fetch() async => _stations;
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await load('Roboto', Platform.environment['RIDEY_FONT']!.split(':'));
  await load('MaterialIcons', [Platform.environment['RIDEY_ICONS']!]);
  await load('RideyNumbers', ['assets/fonts/unbounded-ridey-800.ttf']);
}

void main() {
  setUpAll(() async {
    if (_out != null) await _loadFonts();
  });

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'my_stations': ['02720', '00207'],
    }),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_frame),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  Future<void> open(
    WidgetTester tester, {
    bool dark = false,
    double height = 844,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = Size(390 * 3, height * 3);
    tester.platformDispatcher.platformBrightnessTestValue = dark
        ? Brightness.dark
        : Brightness.light;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _frame,
        child: RideyApp(
          liveRepository: _Live(),
          stationRepository: _Stations(),
          readLocation: () async => (latitude: 37.5610, longitude: 126.8350),
          enableCamera: false,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> lookup(WidgetTester tester, String number) async {
    await tester.tap(find.text('자전거 확인'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, number);
    await tester.tap(find.text('조회하기'));
    await settle(tester);
  }

  for (final dark in [false, true]) {
    final tag = dark ? '_dark' : '';

    testWidgets('home$tag', (tester) async {
      await open(tester, dark: dark);
      await shot(tester, '01_home$tag');
    }, skip: _out == null);

    testWidgets('home full$tag', (tester) async {
      await open(tester, dark: dark, height: 2300);
      await shot(tester, '02_home_full$tag');
    }, skip: _out == null);

    testWidgets('lookup$tag', (tester) async {
      await open(tester, dark: dark);
      await tester.tap(find.text('자전거 확인'));
      await shot(tester, '03_lookup$tag');
      await tester.enterText(find.byType(TextField).first, 'spb-12345');
      await tester.tap(find.text('조회하기'));
      await shot(tester, '04_lookup_none$tag');
    }, skip: _out == null);

    testWidgets('detail$tag', (tester) async {
      await open(tester, dark: dark, height: 1500);
      await lookup(tester, 'spb-69683');
      await shot(tester, '05_detail$tag');
    }, skip: _out == null);

    testWidgets('stations$tag', (tester) async {
      await open(tester, dark: dark, height: 1100);
      await tester.tap(find.text('더보기'));
      await settle(tester);
      await tester.tap(find.text('자주 쓰는 대여소'));
      await shot(tester, '06_stations$tag');
    }, skip: _out == null);

    testWidgets('more$tag', (tester) async {
      await open(tester, dark: dark);
      await tester.tap(find.text('더보기'));
      await shot(tester, '07_more$tag');
    }, skip: _out == null);
  }
}
