import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:ridey_app/app/ridey_actions.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_status.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({
    super.key,
    this.repository,
    this.stationRepository,
    this.savedStationsStore,
    this.readLocation,
  });

  final LiveSnapshotRepository? repository;
  final StationRepository? stationRepository;
  final SavedStationsStore? savedStationsStore;
  final Future<DeviceLocation?> Function()? readLocation;

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
            savedStationsStore:
                widget.savedStationsStore ?? SavedStationsStore(),
            readLocation: widget.readLocation ?? readDeviceLocation,
            onBikeSelected: (bike) => _openBike(bike, snapshot.requireData),
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
    required this.usingDeviceLocation,
    required this.hasSavedStations,
    this.location,
  });

  final List<NearbyBike> bikes;
  final bool usingDeviceLocation;
  final bool hasSavedStations;
  final DeviceLocation? location;
}

class _LoadedHome extends StatefulWidget {
  const _LoadedHome({
    required this.snapshot,
    required this.stationRepository,
    required this.savedStationsStore,
    required this.readLocation,
    required this.onBikeSelected,
  });

  final LiveSnapshot snapshot;
  final StationRepository stationRepository;
  final SavedStationsStore savedStationsStore;
  final Future<DeviceLocation?> Function() readLocation;
  final ValueChanged<LiveBike> onBikeSelected;

  @override
  State<_LoadedHome> createState() => _LoadedHomeState();
}

class _LoadedHomeState extends State<_LoadedHome> {
  late Future<_HomeArea> _area = _load();

  Future<_HomeArea> _load() async {
    final stations = await widget.stationRepository.fetch();
    final location = await widget.readLocation();
    if (location != null) {
      return _HomeArea(
        bikes: bikesNear(
          bikes: widget.snapshot.bikes,
          stations: stations,
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
      usingDeviceLocation: false,
      hasSavedStations: saved.isNotEmpty,
    );
  }

  void _reloadArea() => setState(() => _area = _load());

  void _openStation(String stationId, List<NearbyBike> bikes) {
    for (final item in bikes) {
      if (item.bike.station == stationId) {
        widget.onBikeSelected(item.bike);
        return;
      }
    }
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
        final pins = <String, NearbyMapStation>{};
        for (final item in area.bikes) {
          final latitude = item.latitude;
          final longitude = item.longitude;
          if (latitude == null || longitude == null) continue;
          pins.putIfAbsent(
            item.bike.station,
            () => NearbyMapStation(
              id: item.bike.station,
              latitude: latitude,
              longitude: longitude,
            ),
          );
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _pagePadding,
          children: [
            _Headline(area: area, snapshot: widget.snapshot),
            if (!area.usingDeviceLocation)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _reloadArea,
                  child: Text(area.hasSavedStations ? '내 위치로 보기' : '위치 허용하기'),
                ),
              ),
            const SizedBox(height: 8),
            NearbyMap(
              stations: pins.values.toList(growable: false),
              location: area.location,
              onStationTap: (id) => _openStation(id, area.bikes),
            ),
            const SizedBox(height: 8),
            if (area.bikes.isEmpty)
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
          ],
        );
      },
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
                      ? '현재 사용자님이 계신 지역에\n고장 의심 따릉이가 '
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
          Text('내 주변 고장 의심 따릉이를 보려면\n위치 권한이 필요해요', style: style),
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
      label: '${item.bike.bike} 경보 자세히 보기',
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.ridey.signal,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      Symbols.pedal_bike_rounded,
                      color: Colors.white,
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
                        item.stationName,
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
