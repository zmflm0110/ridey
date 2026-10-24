import 'package:flutter/material.dart';
import 'package:ridey_app/app/legacy_preferences.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';
import 'package:ridey_app/features/rider/rider_home_page.dart';
import 'package:ridey_app/features/stations/saved_stations_page.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/liquid_navigation.dart';

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
    RideyNavigationItem('이용하기', Icons.directions_bike_outlined),
    RideyNavigationItem('번호 확인', Icons.qr_code_scanner_outlined),
    RideyNavigationItem('대여소', Icons.location_on_outlined),
    RideyNavigationItem('더보기', Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _AppHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _pages[_index],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: LiquidNavigation(
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
    ),
    SavedStationsDestination(
      key: const ValueKey('saved-stations'),
      liveRepository: widget.liveRepository,
      stationRepository: widget.stationRepository,
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
      padding: EdgeInsets.fromLTRB(24, 14, 24, 10),
      child: Row(children: [_Wordmark()]),
    );
  }
}

class _StartupPage extends StatelessWidget {
  const _StartupPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator.adaptive()),
    );
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
      padding: const EdgeInsets.fromLTRB(24, 34, 24, 130),
      children: [
        Text('더보기', style: theme.textTheme.displayLarge),
        const SizedBox(height: 12),
        Text(
          '시연, 내 기록, 설정은 실제 기능이 연결되는 순서에 맞춰 추가해요.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.ridey.muted,
          ),
        ),
        const SizedBox(height: 36),
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Icon(
              isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
            title: const Text('화면 모드'),
            subtitle: Text(isDark ? '어두운 화면 사용 중' : '밝은 화면 사용 중'),
            trailing: Switch(
              value: isDark,
              onChanged: (value) {
                onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'RIDEY',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.ridey.signal,
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: 7, height: 7),
            ),
          ),
        ],
      ),
    );
  }
}
