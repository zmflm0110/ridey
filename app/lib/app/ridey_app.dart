import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ridey_app/app/legacy_preferences.dart';
import 'package:ridey_app/app/mode_switch.dart';
import 'package:ridey_app/app/onboarding_page.dart';
import 'package:ridey_app/app/ridey_actions.dart';
import 'package:ridey_app/app/user_mode.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits_page.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/notifications/notification_settings_page.dart';
import 'package:ridey_app/features/ops/ops_list_repository.dart';
import 'package:ridey_app/features/rider/bike_check_tab.dart';
import 'package:ridey_app/features/rider/rider_home_page.dart';
import 'package:ridey_app/features/staff/staff_shell.dart';
import 'package:ridey_app/features/stations/saved_stations_page.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class RideyApp extends StatefulWidget {
  const RideyApp({
    super.key,
    this.liveRepository,
    this.stationRepository,
    this.opsListRepository,
    this.readLocation,
    this.enableCamera = true,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final OpsListRepository? opsListRepository;
  final Future<DeviceLocation?> Function()? readLocation;
  final bool enableCamera;

  @override
  State<RideyApp> createState() => _RideyAppState();
}

class _RideyAppState extends State<RideyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  UserMode? _mode;
  var _ready = false;
  final _pendingCheck = ValueNotifier<RideyCheckRequest?>(null);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await clearLegacyPreferences();
    final mode = await readUserMode();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _ready = true;
    });
  }

  Future<void> _chooseMode(UserMode mode) async {
    await writeUserMode(mode);
    if (!mounted) return;
    setState(() => _mode = mode);
  }

  @override
  void dispose() {
    _pendingCheck.dispose();
    super.dispose();
  }

  void _openBike(LiveBike bike, LiveSnapshot snapshot) {
    _pendingCheck.value = RideyCheckRequest(
      token: Object(),
      bike: bike,
      updatedAt: snapshot.updatedAt,
      feed: snapshot.feed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RideyActions(
      openBike: _openBike,
      child: MaterialApp(
        title: 'RIDEY',
        debugShowCheckedModeBanner: false,
        theme: RideyTheme.light(),
        darkTheme: RideyTheme.dark(),
        themeMode: _themeMode,
        home: !_ready
            ? const _StartupPage()
            : switch (_mode) {
                null => OnboardingPage(onChosen: _chooseMode),
                UserMode.rider => RideyShell(
                  liveRepository: widget.liveRepository,
                  stationRepository: widget.stationRepository,
                  readLocation: widget.readLocation,
                  enableCamera: widget.enableCamera,
                  themeMode: _themeMode,
                  onThemeModeChanged: (mode) =>
                      setState(() => _themeMode = mode),
                  onSwitchToStaff: () => _chooseMode(UserMode.staff),
                  pendingCheck: _pendingCheck,
                ),
                UserMode.staff => StaffShell(
                  liveRepository:
                      widget.liveRepository ?? SupabaseLiveSnapshotRepository(),
                  stationRepository:
                      widget.stationRepository ?? BundledStationRepository(),
                  opsListRepository:
                      widget.opsListRepository ?? SupabaseOpsListRepository(),
                  themeMode: _themeMode,
                  onThemeModeChanged: (mode) =>
                      setState(() => _themeMode = mode),
                  onSwitchToRider: () => _chooseMode(UserMode.rider),
                ),
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
    required this.enableCamera,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onSwitchToStaff,
    required this.pendingCheck,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final Future<DeviceLocation?> Function()? readLocation;
  final bool enableCamera;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSwitchToStaff;
  final ValueNotifier<RideyCheckRequest?> pendingCheck;

  @override
  State<RideyShell> createState() => _RideyShellState();
}

class _RideyShellState extends State<RideyShell> {
  var _index = 0;

  static const _navigationItems = [
    RideyNavigationItem('홈', Symbols.home_rounded, Symbols.home_filled_rounded),
    RideyNavigationItem('자전거 확인', Symbols.pedal_bike_rounded),
    RideyNavigationItem('더보기', Symbols.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    widget.pendingCheck.addListener(_onCheckRequest);
  }

  @override
  void didUpdateWidget(RideyShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pendingCheck != widget.pendingCheck) {
      oldWidget.pendingCheck.removeListener(_onCheckRequest);
      widget.pendingCheck.addListener(_onCheckRequest);
    }
  }

  @override
  void dispose() {
    widget.pendingCheck.removeListener(_onCheckRequest);
    super.dispose();
  }

  void _onCheckRequest() {
    if (widget.pendingCheck.value == null || !mounted) return;
    setState(() => _index = 1);
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationSettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AppHeader(onNotifications: _openNotifications),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      RiderHomePage(
                        repository: widget.liveRepository,
                        stationRepository: widget.stationRepository,
                        readLocation: widget.readLocation,
                      ),
                      BikeCheckTab(
                        repository: widget.liveRepository,
                        readLocation: widget.readLocation,
                        cameraEnabled: widget.enableCamera,
                        request: widget.pendingCheck.value,
                        onRequestHandled: () =>
                            widget.pendingCheck.value = null,
                      ),
                      _MorePage(
                        themeMode: widget.themeMode,
                        onThemeModeChanged: widget.onThemeModeChanged,
                        onSwitchToStaff: widget.onSwitchToStaff,
                        liveRepository: widget.liveRepository,
                        stationRepository: widget.stationRepository,
                        readLocation: widget.readLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RideyTabBar(
              index: _index,
              items: _navigationItems,
              onChanged: (index) => setState(() => _index = index),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.onNotifications});

  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
      child: Row(
        children: [
          const RideyWordmark(size: 26),
          const Spacer(),
          IconButton(
            tooltip: '알림',
            onPressed: onNotifications,
            icon: Icon(
              Symbols.notifications_rounded,
              color: Theme.of(context).colorScheme.onSurface,
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
    return const Scaffold(body: Center(child: RideyWordmark(size: 30)));
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage({
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onSwitchToStaff,
    required this.liveRepository,
    required this.stationRepository,
    required this.readLocation,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSwitchToStaff;
  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final Future<DeviceLocation?> Function()? readLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => theme.brightness == Brightness.dark,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, rideyTabClearance),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('더보기', style: theme.textTheme.displayLarge),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('자주 가는 곳'),
        RideyListCard(
          children: [
            RideyRow(
              leading: const RideyIco(icon: Icons.pedal_bike_outlined),
              title: '자주 쓰는 대여소',
              subtitle: '저장해 둔 곳의 고장 의심 자전거',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: context.ridey.muted,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SavedStationsDestination(
                      liveRepository: liveRepository,
                      stationRepository: stationRepository,
                      readLocation: readLocation,
                    ),
                  ),
                );
              },
            ),
            RideyRow(
              leading: const RideyIco(icon: Icons.schedule_outlined),
              title: '이용 시간과 알림',
              subtitle: '자주 확인하는 시간대에, 하루 한 번',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: context.ridey.muted,
              ),
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
        const _SectionLabel('설정'),
        RideyListCard(
          children: [
            RideyRow(
              leading: RideyIco(
                icon: isDark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
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
              leading: const RideyIco(icon: Icons.swap_horiz_rounded),
              title: '이용 목적 바꾸기',
              subtitle: '직원 모드로 전환해요',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: context.ridey.muted,
              ),
              onTap: () async {
                final confirmed = await confirmModeSwitch(
                  context,
                  next: UserMode.staff,
                );
                if (confirmed) onSwitchToStaff();
              },
            ),
          ],
        ),
        const _SectionLabel('기타'),
        RideyListCard(
          children: [
            RideyRow(
              leading: const RideyIco(icon: Icons.history_rounded),
              title: '조회 기록',
              subtitle: '최근 14일, 이 폰에만 저장돼요.',
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: context.ridey.muted,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LookupHabitsPage(),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: context.ridey.muted,
          fontSize: 13,
        ),
      ),
    );
  }
}
