import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/saved_stations_page.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_status.dart';
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

  Future<void> _openLookup(LiveSnapshot snapshot) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BikeLookupPage(
          snapshot: snapshot,
          repository: _repository,
          readLocation: widget.readLocation,
        ),
      ),
    );
  }

  void _openDetail(LiveBike bike, LiveSnapshot snapshot) {
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

  Future<void> _openSavedStations(LiveSnapshot snapshot) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavedStationsPage(
          snapshot: snapshot,
          readLocation: widget.readLocation,
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
            onLookup: () => _openLookup(snapshot.requireData),
            onBikeSelected: (bike) => _openDetail(bike, snapshot.requireData),
            onSavedStations: () => _openSavedStations(snapshot.requireData),
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

const _pagePadding = EdgeInsets.fromLTRB(16, 4, 16, 28);

class _LoadedHome extends StatefulWidget {
  const _LoadedHome({
    required this.snapshot,
    required this.stationRepository,
    required this.savedStationsStore,
    required this.readLocation,
    required this.onLookup,
    required this.onBikeSelected,
    required this.onSavedStations,
  });

  final LiveSnapshot snapshot;
  final StationRepository stationRepository;
  final SavedStationsStore savedStationsStore;
  final Future<DeviceLocation?> Function() readLocation;
  final VoidCallback onLookup;
  final ValueChanged<LiveBike> onBikeSelected;
  final VoidCallback onSavedStations;

  @override
  State<_LoadedHome> createState() => _LoadedHomeState();
}

class _LoadedHomeState extends State<_LoadedHome> {
  late final Future<List<BikeStation>> _stations = widget.stationRepository
      .fetch();
  String? _district;
  var _showAll = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;

    return FutureBuilder<List<BikeStation>>(
      future: _stations,
      builder: (context, loaded) {
        final stations = loaded.data ?? const <BikeStation>[];
        final guOf = {for (final s in stations) s.id: _shortGu(s.district)};
        final districts = _districtCounts(snapshot.bikes, guOf);
        final bikes = _district == null
            ? snapshot.bikes
            : snapshot.bikes
                  .where((bike) => guOf[bike.station] == _district)
                  .toList(growable: false);
        final shown = _showAll ? bikes : bikes.take(5).toList(growable: false);

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: _pagePadding,
          children: [
            RideyEnter(child: _Hero(snapshot: snapshot)),
            if (districts.isNotEmpty)
              _DistrictStories(
                total: snapshot.bikes.length,
                districts: districts,
                selected: _district,
                onSelected: (gu) => setState(() {
                  _district = gu;
                  _showAll = false;
                }),
              ),
            const SizedBox(height: 12),
            RideyEnter(
              index: 2,
              child: _CheckBikeCard(
                onLookup: widget.onLookup,
                onSavedStations: widget.onSavedStations,
              ),
            ),
            _NearbyStationsSection(
              snapshot: snapshot,
              stations: _stations,
              savedStationsStore: widget.savedStationsStore,
              readLocation: widget.readLocation,
              onBikeSelected: widget.onBikeSelected,
            ),
            RideySectionTitle(
              '지금 피할 자전거',
              note: _district == null ? '경보가 먼저 켜진 순서' : '$_district · 먼저 켜진 순서',
            ),
            if (shown.isEmpty)
              const _NoAlerts()
            else
              RideyListCard(
                key: ValueKey('alerts-$_district-$_showAll'),
                children: [
                  for (final bike in shown)
                    _BikeAlertRow(
                      bike: bike,
                      onTap: () => widget.onBikeSelected(bike),
                    ),
                ],
              ),
            if (bikes.length > shown.length) ...[
              const SizedBox(height: 10),
              RideyButton.secondary(
                label: '${bikes.length - shown.length}대 더 보기',
                onPressed: () => setState(() => _showAll = true),
              ),
            ],
          ],
        );
      },
    );
  }
}

String _shortGu(String district) =>
    district.endsWith('구') && district.length > 2
    ? district.substring(0, district.length - 1)
    : district;

List<(String, int)> _districtCounts(
  List<LiveBike> bikes,
  Map<String, String> guOf,
) {
  final counts = <String, int>{};
  for (final bike in bikes) {
    final gu = guOf[bike.station];
    if (gu == null || gu.isEmpty) continue;
    counts[gu] = (counts[gu] ?? 0) + 1;
  }
  final out = [for (final e in counts.entries) (e.key, e.value)];
  out.sort((a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1));
  return out;
}

/// The ink card with the big signal-orange number (web `.hero`).
class _Hero extends StatelessWidget {
  const _Hero({required this.snapshot});

  final LiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final high = snapshot.bikes.where((bike) => bike.isHighAlert).length;
    final low = snapshot.bikes.length - high;
    final ago = rideyAgo(snapshot.updatedAt);
    final feed = snapshot.feed;
    final live = !snapshot.isOffline && feed.isHealthy;
    final status = snapshot.isOffline
        ? '연결 안 됨 · 마지막 기록 $ago'
        : feed.isHealthy
        ? '실시간 · $ago 갱신(5분마다)'
        : '자료 지연 · $ago 갱신';
    final ratio = feed.ratio == null ? null : (feed.ratio! * 100).round();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.ridey.hero,
        border: Border.all(color: context.ridey.heroLine),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: RideyDotGrid(color: RideyColors.heroText)),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (live)
                      const RideyPing(color: RideyColors.heroSignal)
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: RideyColors.heroMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        status,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: RideyColors.heroMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '지금 서울에\n고장 의심 따릉이가',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: RideyColors.heroText,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    letterSpacing: -0.57,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RideyCountUp(
                      value: snapshot.bikes.length,
                      style: context
                          .rideyNumbers(theme.textTheme.displayLarge)
                          ?.copyWith(
                            fontSize: 88,
                            height: 1.05,
                            letterSpacing: -4.4,
                            color: RideyColors.heroSignal,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '대 있어요',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: RideyColors.heroText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '연쇄 3명+ $high · 2명 $low · 고장 확정은 아니에요',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: RideyColors.heroMuted,
                  ),
                ),
                if (!feed.isHealthy && !snapshot.isOffline) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: RideyColors.heroText.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      ratio == null
                          ? '대여 기록이 늦어지고 있어요. 새 경보가 늦을 수 있어요.'
                          : '대여 기록이 평소의 $ratio%만 올라오고 있어요. 새 경보가 늦을 수 있어요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: RideyColors.heroText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// District pills under the hero (web `.stories`): tap one to filter the list.
class _DistrictStories extends StatelessWidget {
  const _DistrictStories({
    required this.total,
    required this.districts,
    required this.selected,
    required this.onSelected,
  });

  final int total;
  final List<(String, int)> districts;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(String?, String)>[
      (null, '전체 $total'),
      for (final (gu, n) in districts) (gu, '$gu $n'),
    ];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (gu, label) = items[i];
          return RideyEnter(
            index: i + 1,
            offset: 6,
            child: _Story(
              label: label,
              on: gu == selected,
              onTap: () => onSelected(gu),
            ),
          );
        },
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paper = Theme.of(context).scaffoldBackgroundColor;
    return Semantics(
      selected: on,
      child: RideyPressable(
        onTap: onTap,
        scale: .95,
        child: AnimatedContainer(
          duration: RideyMotion.of(context, const Duration(milliseconds: 250)),
          curve: RideyMotion.ease,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: on ? scheme.onSurface : scheme.surface,
            border: Border.all(
              color: on ? scheme.onSurface : context.ridey.line,
            ),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: on ? paper : context.ridey.body,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckBikeCard extends StatelessWidget {
  const _CheckBikeCard({required this.onLookup, required this.onSavedStations});

  final VoidCallback onLookup;
  final VoidCallback onSavedStations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RideyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('타기 전,\n확인하세요.', style: theme.textTheme.displayLarge),
          const SizedBox(height: 6),
          Text(
            '번호를 확인하면 경보가 켜졌는지 바로 알려 드려요.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              color: context.ridey.muted,
            ),
          ),
          const SizedBox(height: 16),
          RideyButton(
            label: '자전거 확인하기',
            icon: Icons.qr_code_scanner_rounded,
            onPressed: onLookup,
          ),
          const SizedBox(height: 10),
          RideyButton.secondary(
            label: '내 대여소의 주의 번호 보기',
            icon: Icons.bookmark_outline_rounded,
            onPressed: onSavedStations,
          ),
        ],
      ),
    );
  }
}

class _BikeAlertRow extends StatelessWidget {
  const _BikeAlertRow({required this.bike, required this.onTap});

  final LiveBike bike;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final station = bike.stationName.isEmpty ? bike.station : bike.stationName;
    return RideyRow(
      semanticLabel: '${bike.bike} 경보 자세히 보기',
      leading: RideyIco(
        icon: Icons.directions_bike_rounded,
        tone: bike.isHighAlert ? RideyTone.strong : RideyTone.normal,
      ),
      title: bike.bike,
      subtitle: '$station · 서로 다른 ${bike.chain}명이 바로 반납',
      trailing: RideyNumber(
        bike.probability == null ? '${bike.chain}명' : '${bike.probability}%',
        color: bike.isHighAlert
            ? context.ridey.signalText
            : context.ridey.muted,
      ),
      onTap: onTap,
    );
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _pagePadding,
      children: [
        Container(
          height: 238,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.ridey.hero,
            border: Border.all(color: context.ridey.heroLine),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              const Positioned.fill(
                child: RideyDotGrid(color: RideyColors.heroText),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '실시간 목록을 받는 중',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: RideyColors.heroMuted,
                      ),
                    ),
                    const Spacer(),
                    const LinearProgressIndicator(
                      color: RideyColors.heroSignal,
                      backgroundColor: Color(0x22F7F5F0),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final RefreshCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _pagePadding,
      children: [
        RideyPopIn(
          child: RideyCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RideyIco(icon: Icons.cloud_off_outlined),
                const SizedBox(height: 14),
                Text(
                  '실시간 목록을 불러오지 못했어요.',
                  style: theme.textTheme.headlineLarge,
                ),
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
        ),
      ],
    );
  }
}

class _NoAlerts extends StatelessWidget {
  const _NoAlerts();

  @override
  Widget build(BuildContext context) {
    return RideyCard(
      child: Text(
        '지금 목록에 경보가 없어요. 고장이 없다는 뜻은 아니에요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
      ),
    );
  }
}

class _NearbyStationsSection extends StatefulWidget {
  const _NearbyStationsSection({
    required this.snapshot,
    required this.stations,
    required this.savedStationsStore,
    required this.readLocation,
    required this.onBikeSelected,
  });

  final LiveSnapshot snapshot;
  final Future<List<BikeStation>> stations;
  final SavedStationsStore savedStationsStore;
  final Future<DeviceLocation?> Function() readLocation;
  final ValueChanged<LiveBike> onBikeSelected;

  @override
  State<_NearbyStationsSection> createState() => _NearbyStationsSectionState();
}

class _NearbyPlace {
  const _NearbyPlace({required this.usingLocation, required this.groups});

  final bool usingLocation;
  final List<StationAlertGroup> groups;
}

class _NearbyStationsSectionState extends State<_NearbyStationsSection> {
  late Future<_NearbyPlace> _place;

  @override
  void initState() {
    super.initState();
    _place = _load();
  }

  @override
  void didUpdateWidget(covariant _NearbyStationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) _place = _load();
  }

  Future<_NearbyPlace> _load() async {
    final results = await Future.wait([
      widget.stations,
      widget.savedStationsStore.load(),
      widget.readLocation(),
    ]);
    final stations = results[0] as List<BikeStation>;
    final savedIds = results[1] as List<String>;
    final location = results[2] as DeviceLocation?;
    if (location != null) {
      return _NearbyPlace(
        usingLocation: true,
        groups: nearestAlertStations(
          groups: stationAlertGroups(
            bikes: widget.snapshot.bikes,
            stations: stations,
          ),
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      );
    }
    return _NearbyPlace(
      usingLocation: false,
      groups: savedStationAlerts(
        bikes: widget.snapshot.bikes,
        stations: stations,
        savedIds: savedIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_NearbyPlace>(
      future: _place,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 30),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final place = snapshot.requireData;
        final radiusKm = (nearbyAlertRadiusMeters / 1000).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RideySectionTitle(
              place.usingLocation ? '내 주변 대여소' : '내 대여소',
              note: place.usingLocation ? '${radiusKm}km 안 · 가까운 순' : '위치 없이 저장한 곳',
            ),
            if (place.groups.isEmpty)
              RideyCard(
                child: Text(
                  place.usingLocation
                      ? '${radiusKm}km 안에 고장 의심 자전거가 없어요.'
                      : '저장한 대여소가 없어요. 대여소 탭에서 추가할 수 있어요.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
                ),
              )
            else
              RideyListCard(
                children: [
                  for (var i = 0; i < place.groups.length; i++)
                    _NearbyStationRow(
                      rank: place.usingLocation ? i + 1 : null,
                      group: place.groups[i],
                      onTap: () {
                        final bike = firstBikeAt(
                          widget.snapshot.bikes,
                          place.groups[i].id,
                        );
                        if (bike != null) widget.onBikeSelected(bike);
                      },
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _NearbyStationRow extends StatelessWidget {
  const _NearbyStationRow({
    required this.rank,
    required this.group,
    required this.onTap,
  });

  final int? rank;
  final StationAlertGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = group.meters;
    final rankNumber = rank;
    return RideyRow(
      leading: rankNumber == null
          ? const RideyIco(icon: Icons.bookmark_outline_rounded)
          : SizedBox(
              width: 24,
              child: Center(
                child: RideyNumber(
                  '$rankNumber',
                  color: rankNumber <= 3
                      ? context.ridey.signalText
                      : context.ridey.muted,
                ),
              ),
            ),
      title: group.name,
      subtitle: [
        if (distance != null) formatDistance(distance),
        if (group.highAlertCount > 0) '강한 경보 ${group.highAlertCount}대',
        if (group.count == 0) '고장 의심 없음',
      ].join(' · '),
      trailing: RideyNumber(
        '${group.count}대',
        color: group.count == 0
            ? context.ridey.muted
            : Theme.of(context).colorScheme.onSurface,
      ),
      onTap: group.count == 0 ? null : onTap,
    );
  }
}
