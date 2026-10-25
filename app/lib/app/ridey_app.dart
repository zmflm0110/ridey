import 'package:flutter/material.dart';
import 'package:ridey_app/app/legacy_preferences.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits_page.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/notifications/notification_settings_page.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';
import 'package:ridey_app/features/rider/rider_home_page.dart';
import 'package:ridey_app/features/stations/saved_stations_page.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class RideyApp extends StatefulWidget {
  const RideyApp({
    super.key,
    this.liveRepository,
    this.stationRepository,
    this.readLocation,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final Future<DeviceLocation?> Function()? readLocation;

  @override
  State<RideyApp> createState() => _RideyAppState();
}

class _RideyAppState extends State<RideyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = clearLegacyPreferences();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RIDEY',
      debugShowCheckedModeBanner: false,
      theme: RideyTheme.light(),
      darkTheme: RideyTheme.dark(),
      themeMode: _themeMode,
      home: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StartupPage();
          }
          return RideyShell(
            liveRepository: widget.liveRepository,
            stationRepository: widget.stationRepository,
            readLocation: widget.readLocation,
            themeMode: _themeMode,
            onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
          );
        },
      ),
    );
  }
}

class RideyShell extends StatefulWidget {
  const RideyShell({
    super.key,
    required this.liveRepository,
    required this.stationRepository,
    required this.readLocation,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final Future<DeviceLocation?> Function()? readLocation;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<RideyShell> createState() => _RideyShellState();
}

class _RideyShellState extends State<RideyShell> {
  var _index = 0;

  static const _navigationItems = [
    RideyNavigationItem('이용하기', Icons.home_outlined, Icons.home_rounded),
    RideyNavigationItem('번호 확인', Icons.search_rounded),
    RideyNavigationItem('대여소', Icons.location_on_outlined, Icons.location_on),
    RideyNavigationItem('더보기', Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _AppHeader(),
            Expanded(
              // A tab rises 12px and fades in (web `.tab.on`); the old one just fades.
              child: AnimatedSwitcher(
                duration: RideyMotion.of(context, const Duration(milliseconds: 450)),
                reverseDuration: RideyMotion.of(context, const Duration(milliseconds: 150)),
                switchInCurve: RideyMotion.ease,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .016),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _pages[_index],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RideyTabBar(
        index: _index,
        items: _navigationItems,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }

  List<Widget> get _pages => [
    RiderHomePage(
      key: const ValueKey('rider-home'),
      repository: widget.liveRepository,
      stationRepository: widget.stationRepository,
      readLocation: widget.readLocation,
    ),
    BikeLookupDestination(
      key: const ValueKey('bike-lookup'),
      repository: widget.liveRepository,
      readLocation: widget.readLocation,
    ),
    SavedStationsDestination(
      key: const ValueKey('saved-stations'),
      liveRepository: widget.liveRepository,
      stationRepository: widget.stationRepository,
      readLocation: widget.readLocation,
    ),
    _MorePage(
      key: const ValueKey('more'),
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
    ),
  ];
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(children: [RideyWordmark(size: 22)]),
    );
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: RideyWordmark(size: 30)));
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => theme.brightness == Brightness.dark,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('더보기', style: theme.textTheme.displayLarge),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '화면 모드, 조회 기록, 알림을 여기서 관리해요.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.ridey.muted,
            ),
          ),
        ),
        const SizedBox(height: 18),
        RideyListCard(
          children: [
            RideyRow(
              leading: RideyIco(
                icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              title: '화면 모드',
              subtitle: isDark ? '어두운 화면 사용 중' : '밝은 화면 사용 중',
              trailing: Switch(
                value: isDark,
                onChanged: (value) {
                  onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ),
            RideyRow(
              leading: const RideyIco(icon: Icons.history_rounded),
              title: '조회 기록',
              subtitle: '최근 14일, 이 폰에만 저장돼요.',
              trailing: Icon(Icons.chevron_right_rounded, color: context.ridey.muted),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LookupHabitsPage(),
                  ),
                );
              },
            ),
            RideyRow(
              leading: const RideyIco(icon: Icons.notifications_none_rounded),
              title: '알림',
              subtitle: '자주 확인하는 시간대에만, 하루 한 번',
              trailing: Icon(Icons.chevron_right_rounded, color: context.ridey.muted),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          '자료: 서울 열린데이터광장 따릉이 대여이력·대여소 정보. '
          '경보 규칙: 서로 다른 사람이 3분·300m 안 반납을 2번 이상 이어서 함.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            color: context.ridey.muted,
          ),
        ),
      ],
    );
  }
}
