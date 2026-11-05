import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ridey_app/app/ridey_actions.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/live/station_status_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/live/station_status.dart';
import 'package:ridey_app/features/notifications/nearby_alert_reminder.dart';
import 'package:ridey_app/features/places/place_search.dart';
import 'package:ridey_app/features/places/place_search_page.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/rider/official_bike_app.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
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

/// 홈에 필요한 것 한 묶음: 서울 대여소 전부·실시간 거치 대수·내 위치·즐겨찾는 대여소.
class _HomeData {
  const _HomeData({
    required this.stations,
    required this.parked,
    required this.favorites,
    this.location,
  });

  final List<BikeStation> stations;
  final List<StationOccupancy> parked;
  final List<String> favorites;
  final DeviceLocation? location;
}

/// 지금 보는 기준(내 위치 또는 검색한 곳)으로 줄 세운 결과.
class _HomeArea {
  const _HomeArea({
    required this.bikes,
    required this.stations,
    required this.allStations,
    this.center,
    this.place,
    this.location,
  });

  /// 서울 전체 고장 의심 — 기준점에서 가까운 순(기준이 없으면 강한 경보 먼저).
  final List<NearbyBike> bikes;

  /// '주변 대여소 현황' 목록: 기준점에서 가까운 [_stationListLimit]곳.
  final List<NearbyStationRow> stations;

  /// 지도에 찍을 서울 대여소 전부(경보 수·거치 대수 포함).
  final List<NearbyStationRow> allStations;
  final DeviceLocation? center;
  final SearchPlace? place;
  final DeviceLocation? location;
}

const _stationListLimit = 30;

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
  late Future<_HomeData> _data = _load();
  var _showStations = false;
  String? _reminderKey;

  /// 검색해서 옮겨 본 곳(학원·약속 장소). null 이면 내 위치 기준.
  SearchPlace? _place;
  var _view = 0;

  Future<_HomeData> _load() async {
    final results = await Future.wait<Object?>([
      widget.stationRepository.fetch(),
      widget.stationStatusRepository.fetch().catchError(
        (_) => const <StationOccupancy>[],
      ),
      widget.readLocation().catchError((_) => null),
      widget.savedStationsStore.load().catchError((_) => const <String>[]),
    ]);
    return _HomeData(
      stations: results[0]! as List<BikeStation>,
      parked: results[1]! as List<StationOccupancy>,
      location: results[2] as DeviceLocation?,
      favorites: results[3]! as List<String>,
    );
  }

  void _reloadArea() => setState(() {
    _data = _load();
    _place = null;
    _view++;
  });

  _HomeArea _area(_HomeData data) {
    final place = _place;
    final DeviceLocation? center = place != null
        ? (latitude: place.latitude, longitude: place.longitude)
        : data.location;
    final bikes = widget.snapshot.bikes;
    final all = nearbyStationRows(
      stations: data.stations,
      bikes: bikes,
      occupancy: data.parked,
      latitude: center?.latitude ?? 37.5665,
      longitude: center?.longitude ?? 126.9780,
      withinMeters: double.infinity,
    );
    final List<NearbyBike> suspects;
    if (center != null) {
      suspects = bikesNear(
        bikes: bikes,
        stations: data.stations,
        latitude: center.latitude,
        longitude: center.longitude,
        withinMeters: double.infinity,
      );
    } else {
      final byId = {for (final s in data.stations) s.id: s};
      suspects =
          [
            for (final bike in bikes)
              NearbyBike(
                bike: bike,
                stationName: stationDisplayName(bike, byId[bike.station]),
                latitude: byId[bike.station]?.latitude,
                longitude: byId[bike.station]?.longitude,
              ),
          ]..sort((a, b) {
            if (a.bike.isHighAlert != b.bike.isHighAlert) {
              return a.bike.isHighAlert ? -1 : 1;
            }
            return b.bike.chain.compareTo(a.bike.chain);
          });
    }
    return _HomeArea(
      bikes: suspects,
      stations: center == null
          ? const []
          : all.take(_stationListLimit).toList(growable: false),
      allStations: all,
      center: center,
      place: place,
      location: data.location,
    );
  }

  /// 다이내믹 아일랜드·알림의 '피할 번호' 는 지금 서 있는 곳(내 위치) 1km 안만 — 서울 전체를 띄우면 쓸모가 없다.
  void _syncReminder(_HomeData data) {
    final here = data.location;
    final ids = here == null
        ? const <String>[]
        : [
            for (final item in bikesNear(
              bikes: widget.snapshot.bikes,
              stations: data.stations,
              latitude: here.latitude,
              longitude: here.longitude,
              withinMeters: 1000,
            ))
              item.bike.bike,
          ];
    final key = ids.join(',');
    if (_reminderKey == key) return;
    _reminderKey = key;
    widget.nearbyAlertReminder.sync(ids);
  }

  Future<void> _search(_HomeData data) async {
    final place = await Navigator.of(context, rootNavigator: true)
        .push<SearchPlace>(
          MaterialPageRoute(
            builder: (_) => PlaceSearchPage(stations: data.stations),
          ),
        );
    if (place == null || !mounted) return;
    setState(() {
      _place = place;
      _view++;
    });
  }

  void _backToMe() => setState(() {
    _place = null;
    _view++;
  });

  /// 지도에서 대여소를 누르면 그곳 정보 카드(이름·거리·탈 만한 자전거·고장 의심 목록)를 띄운다.
  /// 카드가 닫힐 때 끝나는 Future — 그동안 지도는 그 대여소를 강조해 둔다.
  Future<void> _openStation(String stationId, _HomeArea area) {
    final row = area.allStations.where((s) => s.id == stationId).firstOrNull;
    final here = [
      for (final item in area.bikes)
        if (item.bike.station == stationId) item,
    ];
    final name = row?.name ?? here.firstOrNull?.stationName ?? '대여소 $stationId';
    final location = area.location;
    final lat = row?.latitude ?? here.firstOrNull?.latitude;
    final lon = row?.longitude ?? here.firstOrNull?.longitude;
    return showStationCard(
      context,
      name: name,
      // 거리는 언제나 '나' 에서 — 검색한 곳 기준이 아니라 실제로 걸어갈 거리.
      meters: location == null || lat == null || lon == null
          ? null
          : metersBetween(location.latitude, location.longitude, lat, lon),
      choosable: row?.choosableCount,
      bikes: [for (final item in here) item.bike],
      onBike: widget.onBikeSelected,
      onRent: widget.openOfficialApp,
      latitude: lat,
      longitude: lon,
      from: location == null
          ? null
          : (latitude: location.latitude, longitude: location.longitude),
    );
  }

  List<Widget> _stationList(_HomeArea area) {
    if (area.stations.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
          child: Text(
            '위치를 허용하거나 위에서 장소를 검색하면 가까운 대여소가 여기에 나와요.',
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
    return FutureBuilder<_HomeData>(
      future: _data,
      builder: (context, loaded) {
        if (loaded.connectionState != ConnectionState.done) {
          return const _LoadingHome();
        }
        if (loaded.hasError || !loaded.hasData) {
          return _LoadFailure(onRetry: _reloadArea);
        }
        final data = loaded.requireData;
        _syncReminder(data);
        final area = _area(data);
        final shown = [
          for (final row in area.allStations)
            if (row.latitude != null && row.longitude != null)
              NearbyMapStation(
                id: row.id,
                latitude: row.latitude!,
                longitude: row.longitude!,
                isHighAlert: row.highAlertCount > 0,
                alertCount: row.alertCount,
                parkedBikes: row.parkedBikes,
              ),
        ];
        return RideyMapSheet(
          map: NearbyMap(
            fullBleed: true,
            showCounts: true,
            stations: shown,
            location: area.location,
            focus: area.place == null
                ? null
                : (
                    latitude: area.place!.latitude,
                    longitude: area.place!.longitude,
                  ),
            viewKey: _view,
            favoriteIds: data.favorites.toSet(),
            controlsTop: 70,
            onStationTap: (id) => _openStation(id, area),
          ),
          // 지도 앱처럼 맨 위에 검색 칸 — 시트 안에 두면 목록 탭이 아래 탭 막대에 가려졌다.
          top: _SearchPill(
            place: area.place,
            onSearch: () => _search(data),
            onClear: _backToMe,
          ),
          children: _sheetChildren(context, area, data),
        );
      },
    );
  }

  List<Widget> _sheetChildren(
    BuildContext context,
    _HomeArea area,
    _HomeData data,
  ) {
    return [
      _Headline(area: area, snapshot: widget.snapshot),
      if (area.location == null && area.place == null)
        Align(
          alignment: Alignment.centerLeft,
          // 왼쪽 여백을 없애 제목 글자와 같은 선에 맞춘다(기본 TextButton 은 12px 안쪽으로 밀림).
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 44),
            ),
            onPressed: _reloadArea,
            child: const Text('내 위치 찾기'),
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
            '지금 서울에 고장 의심 자전거가 없어요.',
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

/// 시트 맨 위: '어디 근처를 볼까요?' — 누르면 검색 화면. 검색한 곳을 보고 있으면 그 이름과 '내 위치로'.
class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.place,
    required this.onSearch,
    required this.onClear,
  });

  final SearchPlace? place;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final current = place;
    return Row(
      children: [
        Expanded(
          child: RideyPressable(
            onTap: onSearch,
            semanticLabel: '장소 검색',
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: c.line),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: c.muted, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      current == null
                          ? '학원·역·동네 근처 미리 보기'
                          : '${current.name} 근처',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: current == null
                            ? c.muted
                            : theme.colorScheme.onSurface,
                        fontWeight: current == null
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (current != null) ...[
          const SizedBox(width: 8),
          Material(
            color: theme.colorScheme.surface,
            shape: StadiumBorder(side: BorderSide(color: c.line)),
            child: TextButton(onPressed: onClear, child: const Text('내 위치로')),
          ),
        ],
      ],
    );
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
    final nearest = area.bikes.firstOrNull?.meters;
    final basis = area.place != null
        ? '${area.place!.name} 기준 가까운 순'
        : area.center != null
        ? '내 위치에서 가까운 순'
        : '내 위치를 찾지 못해 강한 경보부터';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: '지금 서울에\n고장 의심 따릉이가 '),
              TextSpan(
                text: '$count대',
                style: TextStyle(color: context.ridey.signal),
              ),
              const TextSpan(text: ' 있어요'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          [
            basis,
            if (nearest != null) '가장 가까운 곳 ${formatDistance(nearest)}',
            ?note,
          ].join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.ridey.muted,
          ),
        ),
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
