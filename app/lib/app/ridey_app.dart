import 'package:flutter/material.dart';
import 'package:ridey_app/app/app_purpose.dart';
import 'package:ridey_app/app/purpose_onboarding_page.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/field/field_records_page.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';
import 'package:ridey_app/features/rider/rider_home_page.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/stations/saved_stations_page.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/features/work/work_home_page.dart';
import 'package:ridey_app/features/work/worker_overview_page.dart';
import 'package:ridey_app/widgets/liquid_navigation.dart';

class RideyApp extends StatefulWidget {
  const RideyApp({
    super.key,
    this.liveRepository,
    this.stationRepository,
    this.fieldRepository,
    this.purposeStore,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final FieldVerificationRepository? fieldRepository;
  final AppPurposeStore? purposeStore;

  @override
  State<RideyApp> createState() => _RideyAppState();
}

class _RideyAppState extends State<RideyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final AppPurposeStore _purposeStore;
  late Future<AppPurpose?> _purpose;

  @override
  void initState() {
    super.initState();
    _purposeStore = widget.purposeStore ?? SharedPreferencesAppPurposeStore();
    _purpose = _purposeStore.load();
  }

  Future<void> _selectPurpose(AppPurpose purpose) async {
    await _purposeStore.save(purpose);
    if (!mounted) return;
    setState(() {
      _purpose = Future.value(purpose);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RIDEY',
      debugShowCheckedModeBanner: false,
      theme: RideyTheme.light(),
      darkTheme: RideyTheme.dark(),
      themeMode: _themeMode,
      home: FutureBuilder<AppPurpose?>(
        future: _purpose,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StartupPage();
          }
          final purpose = snapshot.data;
          if (purpose == null) {
            return PurposeOnboardingPage(onSelected: _selectPurpose);
          }
          return RideyShell(
            purpose: purpose,
            liveRepository: widget.liveRepository,
            stationRepository: widget.stationRepository,
            fieldRepository: widget.fieldRepository,
            themeMode: _themeMode,
            onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
            onPurposeChanged: _selectPurpose,
          );
        },
      ),
    );
  }
}

class RideyShell extends StatefulWidget {
  const RideyShell({
    super.key,
    required this.purpose,
    required this.liveRepository,
    required this.stationRepository,
    required this.fieldRepository,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onPurposeChanged,
  });

  final AppPurpose purpose;
  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final FieldVerificationRepository? fieldRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppPurpose> onPurposeChanged;

  @override
  State<RideyShell> createState() => _RideyShellState();
}

class _RideyShellState extends State<RideyShell> {
  late int _index;
  late final FieldVerificationRepository _fieldRepository;

  @override
  void initState() {
    super.initState();
    _index = 0;
    _fieldRepository = widget.fieldRepository ?? FieldVerificationRepository();
    _syncPendingVerifications();
  }

  @override
  void didUpdateWidget(covariant RideyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.purpose != widget.purpose) {
      _index = 0;
    }
  }

  Future<void> _syncPendingVerifications() async {
    await _fieldRepository.sync();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final navigationItems = _navigationItems;
    final pages = _pages;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _AppHeader(
              label: navigationItems[_index].label,
              purpose: widget.purpose,
              onPurposeChanged: widget.onPurposeChanged,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: pages[_index],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: LiquidNavigation(
        index: _index,
        items: navigationItems,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }

  List<RideyNavigationItem> get _navigationItems {
    return switch (widget.purpose) {
      AppPurpose.rider => const [
        RideyNavigationItem('이용하기', Icons.directions_bike_outlined),
        RideyNavigationItem('번호 확인', Icons.qr_code_scanner_outlined),
        RideyNavigationItem('대여소', Icons.location_on_outlined),
        RideyNavigationItem('더보기', Icons.more_horiz_rounded),
      ],
      AppPurpose.worker => const [
        RideyNavigationItem('업무', Icons.assignment_outlined),
        RideyNavigationItem('대여소 작업', Icons.route_outlined),
        RideyNavigationItem('현장 기록', Icons.fact_check_outlined),
        RideyNavigationItem('더보기', Icons.more_horiz_rounded),
      ],
    };
  }

  List<Widget> get _pages {
    final more = _MorePage(
      key: const ValueKey('more'),
      themeMode: widget.themeMode,
      onThemeModeChanged: widget.onThemeModeChanged,
      fieldRepository: _fieldRepository,
    );
    return switch (widget.purpose) {
      AppPurpose.rider => [
        RiderHomePage(
          key: const ValueKey('rider-home'),
          repository: widget.liveRepository,
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
        more,
      ],
      AppPurpose.worker => [
        WorkerOverviewPage(
          key: const ValueKey('worker-overview'),
          repository: widget.liveRepository,
          onOpenStationTasks: () => setState(() => _index = 1),
        ),
        WorkHomePage(
          key: const ValueKey('station-tasks'),
          liveRepository: widget.liveRepository,
          stationRepository: widget.stationRepository,
          fieldRepository: _fieldRepository,
        ),
        FieldRecordsPage(
          key: const ValueKey('field-records'),
          repository: _fieldRepository,
        ),
        more,
      ],
    };
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.label,
    required this.purpose,
    required this.onPurposeChanged,
  });

  final String label;
  final AppPurpose purpose;
  final ValueChanged<AppPurpose> onPurposeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      child: Row(
        children: [
          const _Wordmark(),
          const Spacer(),
          PopupMenuButton<AppPurpose>(
            tooltip: '목적 전환',
            onSelected: onPurposeChanged,
            itemBuilder: (context) => AppPurpose.values
                .map(
                  (item) => PopupMenuItem(
                    value: item,
                    child: Row(
                      children: [
                        Icon(
                          item == AppPurpose.rider
                              ? Icons.directions_bike_outlined
                              : Icons.assignment_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(item.label),
                        const Spacer(),
                        if (item == purpose) const Icon(Icons.check_rounded),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: Semantics(
              button: true,
              label: '$label · 현재 ${purpose.label}, 목적 전환',
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: context.ridey.line),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(purpose.label, style: theme.textTheme.labelMedium),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.unfold_more_rounded,
                      size: 16,
                      color: context.ridey.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

class _MorePage extends StatefulWidget {
  const _MorePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.fieldRepository,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final FieldVerificationRepository fieldRepository;

  @override
  State<_MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<_MorePage> {
  late Future<int> _pendingCount;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    _pendingCount = widget.fieldRepository.pendingCount();
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await widget.fieldRepository.sync();
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _pendingCount = widget.fieldRepository.pendingCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                widget.onThemeModeChanged(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<int>(
          future: _pendingCount,
          builder: (context, snapshot) {
            final pending = snapshot.data ?? 0;
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('전송 대기 중인 현장 확인'),
                subtitle: Text(
                  pending == 0 ? '기기에 보관된 기록이 없어요.' : '$pending건을 전송할 수 있어요.',
                ),
                trailing: TextButton(
                  onPressed: pending == 0 || _syncing ? null : _sync,
                  child: _syncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('동기화'),
                ),
              ),
            );
          },
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
