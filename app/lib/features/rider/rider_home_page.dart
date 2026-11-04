import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ridey_app/app/ridey_actions.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/live/station_status_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/notifications/nearby_alert_reminder.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/rider/official_bike_app.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_status.dart';
import 'package:ridey_app/widgets/ridey_map_sheet.dart';
import 'package:ridey_app/widgets/station_card.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({
    super.key,
    this.repository,
    this.stationRepository,
    this.stationStatusRepository,
    this.savedStationsStore,
    this.readLocation,
    this.openOfficialApp,
    this.nearbyAlertReminder,
  });

  final LiveSnapshotRepository? repository;
  final StationRepository? stationRepository;
  final StationStatusRepository? stationStatusRepository;
  final SavedStationsStore? savedStationsStore;
  final Future<DeviceLocation?> Function()? readLocation;
  final Future<void> Function()? openOfficialApp;
  final NearbyAlertReminder? nearbyAlertReminder;

  @override
  State<RiderHomePage> createState() => _RiderHomePageState();
}

class _RiderHomePageState extends State<RiderHomePage> {
  late final LiveSnapshotRepository _repository;
  late Future<LiveSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseLiveSnapshotRepository();
    _snapshot = _repository.fetch();
  }

  Future<void> _refresh() async {
    setState(() => _snapshot = _repository.fetch());
    await _snapshot;
  }

  void _openBike(LiveBike bike, LiveSnapshot snapshot) {
    final actions = RideyActions.maybeOf(context);
    if (actions != null) {
      actions.openBike(bike, snapshot);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BikeDetailPage(
          bike: bike,
          updatedAt: snapshot.updatedAt,
          feed: snapshot.feed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiveSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        final child = switch (snapshot.connectionState) {
          ConnectionState.waiting ||
          ConnectionState.active => const _LoadingHome(),
          ConnectionState.done when snapshot.hasError => _LoadFailure(
            onRetry: _refresh,
          ),
          ConnectionState.done => _LoadedHome(
            snapshot: snapshot.requireData,
            stationRepository:
                widget.stationRepository ?? BundledStationRepository(),
            stationStatusRepository:
                widget.stationStatusRepository ??
                SupabaseStationStatusRepository(),
            savedStationsStore:
                widget.savedStationsStore ?? SavedStationsStore(),
            readLocation: widget.readLocation ?? readDeviceLocation,
            onBikeSelected: (bike) => _openBike(bike, snapshot.requireData),
            openOfficialApp: widget.openOfficialApp ?? openOfficialBikeApp,
            nearbyAlertReminder:
                widget.nearbyAlertReminder ?? PlatformNearbyAlertReminder(),
          ),
          _ => const _LoadingHome(),
        };

        return RefreshIndicator.adaptive(
          color: context.ridey.signal,
          onRefresh: _refresh,
          child: child,
        );
      },
    );
  }
}

const _pagePadding = EdgeInsets.fromLTRB(20, 4, 20, rideyTabClearance);

class _HomeArea {
  const _HomeArea({
    required this.bikes,
    required this.stations,
    required this.usingDeviceLocation,
    required this.hasSavedStations,
    this.location,
  });

  final List<NearbyBike> bikes;
  final List<NearbyStationRow> stations;
  final bool usingDeviceLocation;
  final bool hasSavedStations;
  final DeviceLocation? location;
}

class _LoadedHome extends StatefulWidget {
  const _LoadedHome({
    required this.snapshot,
    required this.stationRepository,
    required this.stationStatusRepository,
    required this.savedStationsStore,
    required this.readLocation,
    required this.onBikeSelected,
    required this.openOfficialApp,
    required this.nearbyAlertReminder,
  });

  final LiveSnapshot snapshot;
  final StationRepository stationRepository;
  final StationStatusRepository stationStatusRepository;
  final SavedStationsStore savedStationsStore;
  final Future<DeviceLocation?> Function() readLocation;
  final ValueChanged<LiveBike> onBikeSelected;
  final Future<void> Function() openOfficialApp;
  final NearbyAlertReminder nearbyAlertReminder;

  @override
  State<_LoadedHome> createState() => _LoadedHomeState();
}

class _LoadedHomeState extends State<_LoadedHome> {
  late Future<_HomeArea> _area = _load();
  var _showStations = false;
  String? _reminderKey;

  Future<_HomeArea> _load() async {
    final stations = await widget.stationRepository.fetch();
    final occupancy = await widget.stationStatusRepository.fetch();
    final location = await widget.readLocation();
    if (location != null) {
      return _HomeArea(
        bikes: bikesNear(
          bikes: widget.snapshot.bikes,
          stations: stations,
          latitude: location.latitude,
          longitude: location.longitude,
        ),
        stations: nearbyStationRows(
          stations: stations,
          bikes: widget.snapshot.bikes,
          occupancy: occupancy,
          latitude: location.latitude,
          longitude: location.longitude,
        ),
        location: location,
        usingDeviceLocation: true,
        hasSavedStations: false,
      );
    }
    final saved = await widget.savedStationsStore.load();
    return _HomeArea(
      bikes: bikesAtStations(
        bikes: widget.snapshot.bikes,
        stations: stations,
        stationIds: saved,
      ),
      stations: savedStationRows(
        stations: stations,
        bikes: widget.snapshot.bikes,
        occupancy: occupancy,
        stationIds: saved,
      ),
      usingDeviceLocation: false,
      hasSavedStations: saved.isNotEmpty,
    );
  }

  void _reloadArea() => setState(() => _area = _load());

  void _syncReminder(_HomeArea area) {
    final ids = [for (final item in area.bikes) item.bike.bike];
    final key = ids.join(',');
    if (_reminderKey == key) return;
    _reminderKey = key;
    widget.nearbyAlertReminder.sync(ids);
  }

  /// 지도에서 대여소를 누르면 그곳의 강한 경보 자전거를 먼저 연다(없으면 첫 자전거).
  /// 지도에서 대여소를 누르면 그곳 정보 카드(이름·거리·탈 만한 자전거·고장 의심 목록)를 띄운다.
  void _openStation(String stationId, _HomeArea area) {
    final row = area.stations.where((s) => s.id == stationId).firstOrNull;
    final here = [
      for (final item in area.bikes)
        if (item.bike.station == stationId) item,
    ];
    final name = row?.name ?? here.firstOrNull?.stationName ?? '대여소 $stationId';
    showStationCard(
      context,
      name: name,
      meters: row?.meters ?? here.firstOrNull?.meters,
      choosable: row?.choosableCount,
      bikes: [for (final item in here) item.bike],
      onBike: widget.onBikeSelected,
      onRent: widget.openOfficialApp,
    );
  }

  List<Widget> _stationList(_HomeArea area) {
    if (area.stations.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
          child: Text(
            area.usingDeviceLocation
                ? '이 근처 2km 안에는 대여소가 없어요.'
                : area.hasSavedStations
                ? '저장한 대여소 현황을 아직 받지 못했어요.'
                : '위치를 허용하거나 더보기에서 대여소를 저장하면 여기에 나와요.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: context.ridey.muted),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < area.stations.length; i++)
        _StationRow(
          station: area.stations[i],
          showDivider: i < area.stations.length - 1,
          onOpenOfficialApp: widget.openOfficialApp,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeArea>(
      future: _area,
      builder: (context, loaded) {
        if (loaded.connectionState != ConnectionState.done) {
          return const _LoadingHome();
        }
        if (loaded.hasError || !loaded.hasData) {
          return _LoadFailure(onRetry: _reloadArea);
        }
        final area = loaded.requireData;
        _syncReminder(area);
        final pins = <String, NearbyMapStation>{};
        for (final station in area.stations) {
          final latitude = station.latitude;
          final longitude = station.longitude;
          if (latitude == null || longitude == null) continue;
          pins[station.id] = NearbyMapStation(
            id: station.id,
            latitude: latitude,
            longitude: longitude,
            isHighAlert: station.highAlertCount > 0,
            alertCount: station.alertCount,
            parkedBikes: station.parkedBikes,
          );
        }
        for (final item in area.bikes) {
          final latitude = item.latitude;
          final longitude = item.longitude;
          if (latitude == null || longitude == null) continue;
          final current = pins[item.bike.station];
          pins[item.bike.station] = NearbyMapStation(
            id: item.bike.station,
            latitude: latitude,
            longitude: longitude,
            isHighAlert:
                item.bike.isHighAlert || (current?.isHighAlert ?? false),
            alertCount: current?.alertCount ?? 1,
            parkedBikes: current?.parkedBikes,
          );
        }

        // 대여소 자리는 언제나 보인다. '고장 의심' 탭은 고장 의심 대여소를 주황으로 두드러지게 하고 나머지는
        // 작은 흰 점으로, '대여소 현황' 탭은 모든 대여소에 탈 만한 자전거 수를 적는다.
        final shown = pins.values.toList(growable: false);
        return RideyMapSheet(
          map: NearbyMap(
            fullBleed: true,
            showCounts: _showStations,
            // 홈 문구가 '내 주변 2km' 이니 지도도 처음에 그 2km 가 다 보이게.
            radiusMeters: area.usingDeviceLocation ? 2000 : null,
            stations: shown,
            location: area.location,
            onStationTap: (id) => _openStation(id, area),
          ),
          children: _sheetChildren(context, area),
        );
      },
    );
  }

  List<Widget> _sheetChildren(BuildContext context, _HomeArea area) {
    return [
      _Headline(area: area, snapshot: widget.snapshot),
      if (!area.usingDeviceLocation)
        Align(
          alignment: Alignment.centerLeft,
          // 왼쪽 여백을 없애 제목 글자와 같은 선에 맞춘다(기본 TextButton 은 12px 안쪽으로 밀림).
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
            ),
            onPressed: _reloadArea,
            child: Text(area.hasSavedStations ? '내 위치로 보기' : '내 위치 찾기'),
          ),
        ),
      const SizedBox(height: 12),
      _HomeListTabs(
        showStations: _showStations,
        onChanged: (showStations) =>
            setState(() => _showStations = showStations),
      ),
      if (_showStations)
        ..._stationList(area)
      else if (area.bikes.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
          child: Text(
            area.usingDeviceLocation
                ? '이 근처 2km 안에는 고장 의심 자전거가 없어요.'
                : area.hasSavedStations
                ? '저장한 대여소에는 지금 고장 의심 자전거가 없어요.'
                : '위치를 허용하거나 더보기에서 대여소를 저장하면 여기에 나와요.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: context.ridey.muted),
          ),
        )
      else
        for (var i = 0; i < area.bikes.length; i++)
          _BikeRow(
            item: area.bikes[i],
            showDivider: i < area.bikes.length - 1,
            onTap: () => widget.onBikeSelected(area.bikes[i].bike),
          ),
    ];
  }
}

class _HomeListTabs extends StatelessWidget {
  const _HomeListTabs({required this.showStations, required this.onChanged});

  final bool showStations;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HomeListTab(
            label: '고장 의심 따릉이',
            selected: !showStations,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HomeListTab(
            label: '주변 대여소 현황',
            selected: showStations,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _HomeListTab extends StatelessWidget {
  const _HomeListTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    return RideyPressable(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.onSurface : c.fill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.transparent : c.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: selected ? Theme.of(context).colorScheme.surface : c.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.area, required this.snapshot});

  final _HomeArea area;
  final LiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineLarge?.copyWith(
      fontSize: 26,
      height: 1.35,
    );
    final count = area.bikes.length;
    final note = _freshness(snapshot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (area.usingDeviceLocation || area.hasSavedStations)
          Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(
                  text: area.usingDeviceLocation
                      ? '내 주변 2km에\n고장 의심 따릉이가 '
                      : '저장한 대여소에\n고장 의심 따릉이가 ',
                ),
                TextSpan(
                  text: '$count대',
                  style: TextStyle(color: context.ridey.signal),
                ),
                const TextSpan(text: ' 있어요'),
              ],
            ),
          )
        else
          Text('내 위치를 찾지 못했어요', style: style),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(
            note,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.ridey.muted,
            ),
          ),
        ],
      ],
    );
  }

  String? _freshness(LiveSnapshot snapshot) {
    final ago = rideyAgo(snapshot.updatedAt);
    if (snapshot.isOffline) return '연결 안 됨 · 마지막 기록 $ago';
    if (!snapshot.feed.isHealthy) return '자료 지연 · $ago 갱신';
    return null;
  }
}

class _BikeRow extends StatelessWidget {
  const _BikeRow({
    required this.item,
    required this.showDivider,
    required this.onTap,
  });

  final NearbyBike item;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meters = item.meters;

    return Semantics(
      button: true,
      label: '${item.bike.bike} 고장 의심 자세히 보기',
      excludeSemantics: true,
      child: RideyPressable(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: context.ridey.line))
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                // 경보 두 단계(docs/brand.md): 연쇄 3명 이상 = 꽉 찬 신호, 2명 = 옅은 신호.
                // 신호색 위 아이콘은 흰색이 아니라 잉크.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: item.bike.isHighAlert
                        ? context.ridey.signal
                        : context.ridey.signalSoft,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      Symbols.pedal_bike_rounded,
                      color: item.bike.isHighAlert
                          ? RideyColors.ink
                          : context.ridey.signalText,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.bike.bike,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.stationName} · 연쇄 ${item.bike.chain}명',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.ridey.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (meters != null)
                  Text(
                    formatDistance(meters),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.ridey.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.showDivider,
    required this.onOpenOfficialApp,
  });

  final NearbyStationRow station;
  final bool showDivider;
  final Future<void> Function() onOpenOfficialApp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choosable = station.choosableCount;
    final parked = station.parkedBikes;
    final counts = parked == null
        ? (station.alertCount > 0 ? '고장 의심 ${station.alertCount}대' : '고장 의심 없음')
        : '${station.alertCount > 0 ? '고장 의심 ${station.alertCount}대' : '고장 의심 없음'} · 탈 만한 자전거 약 $choosable대';

    // 줄마다 같은 단추를 되풀이하지 않고 줄 전체를 누르면 공식 앱이 열린다(오른쪽 '대여하기 ›' 가 그 표시).
    return RideyPressable(
      onTap: () => onOpenOfficialApp(),
      scale: .98,
      semanticLabel: '${station.name} 따릉이 앱에서 대여하기',
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: context.ridey.line))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      station.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (station.meters != null)
                    Text(
                      formatDistance(station.meters!),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.ridey.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      parked == null ? '$counts · 실시간 대수 없음' : counts,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.ridey.muted,
                      ),
                    ),
                  ),
                  Text(
                    '대여하기 ›',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _pagePadding,
      children: [
        Text(
          '실시간 목록을 받는 중',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: context.ridey.muted),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: ColoredBox(
            color: context.ridey.fill,
            child: const SizedBox(height: 312),
          ),
        ),
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _pagePadding,
      children: [
        RideyCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RideyIco(icon: Icons.cloud_off_outlined),
              const SizedBox(height: 14),
              Text('실시간 목록을 불러오지 못했어요.', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.ridey.muted,
                ),
              ),
              const SizedBox(height: 18),
              RideyButton.secondary(
                label: '다시 시도',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
