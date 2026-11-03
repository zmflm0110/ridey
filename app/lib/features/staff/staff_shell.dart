import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/ops/ops_list_repository.dart';
import 'package:ridey_app/features/staff/staff_district_picker.dart';
import 'package:ridey_app/features/staff/staff_list_page.dart';
import 'package:ridey_app/features/staff/staff_more_page.dart';
import 'package:ridey_app/features/staff/staff_overview_page.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class StaffShell extends StatefulWidget {
  const StaffShell({
    super.key,
    required this.liveRepository,
    required this.stationRepository,
    required this.opsListRepository,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onSwitchToRider,
    this.now,
  });

  final LiveSnapshotRepository liveRepository;
  final StationRepository stationRepository;
  final OpsListRepository opsListRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSwitchToRider;
  final DateTime? now;

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  late final StaffSession _session = StaffSession(
    liveRepository: widget.liveRepository,
    opsRepository: widget.opsListRepository,
    stationRepository: widget.stationRepository,
    now: widget.now,
  );
  var _index = 0;
  var _askingDistricts = false;

  static const _navigationItems = [
    RideyNavigationItem('구별 현황', Symbols.map_rounded),
    RideyNavigationItem('목록', Symbols.list_alt_rounded),
    RideyNavigationItem('더보기', Symbols.apps_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    _session.start();
  }

  @override
  void dispose() {
    _session
      ..removeListener(_onSession)
      ..dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
    final shouldAsk =
        _session.assigned == null &&
        !_session.loading &&
        !_askingDistricts &&
        _session.catalogDistricts.isNotEmpty;
    if (!shouldAsk) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _session.assigned != null || _askingDistricts) return;
      _askDistricts();
    });
  }

  Future<void> _askDistricts() async {
    _askingDistricts = true;
    final next = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => StaffDistrictPickerPage(
          districts: _session.catalogDistricts,
          allowSkip: true,
        ),
      ),
    );
    _askingDistricts = false;
    await _session.saveDistricts(next ?? const []);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // 시민 모드 머리(로고 + 알림 단추 48px)와 같은 높이·여백이라야 모드를 바꿔도 로고가 제자리에 있다.
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 8, 4),
                      child: SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: RideyWordmark(size: 26),
                        ),
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: [
                          StaffOverviewPage(
                            session: _session,
                            onOpenDistrict: (district) {
                              _session.focusDistrict(district);
                              setState(() => _index = 1);
                            },
                          ),
                          StaffListPage(session: _session),
                          StaffMorePage(
                            session: _session,
                            themeMode: widget.themeMode,
                            onThemeModeChanged: widget.onThemeModeChanged,
                            onSwitchToRider: widget.onSwitchToRider,
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
                  onChanged: (index) {
                    if (index != 1) _session.clearFocus();
                    setState(() => _index = index);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
