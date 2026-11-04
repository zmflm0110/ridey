import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/rider/nearby_map.dart';
import 'package:ridey_app/features/rider/nearby_stations.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_map_sheet.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// 내 대여소(즐겨찾는 대여소): 지도에 내 대여소가 파란 고리로 보이고, 아래 시트에서
/// '즐겨찾기' 목록과 '대여소 검색' 을 오간다. 대여소를 누르면(목록·검색 결과·지도 어디서든) 지도가 그 자리를
/// 보여 주고, '넣기' 를 눌러야만 내 대여소에 들어간다.
///
/// 앱에 든 대여소 목록과 폰에 저장한 내 대여소는 바로 그리고, 실시간 고장 의심(네트워크)은 받는 대로 덧그린다 —
/// 전에는 실시간 자료를 다 받을 때까지 빈 화면에서 기다렸다.
class SavedStationsDestination extends StatefulWidget {
  const SavedStationsDestination({
    super.key,
    this.liveRepository,
    this.stationRepository,
    this.readLocation,
    this.store,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final Future<DeviceLocation?> Function()? readLocation;
  final SavedStationsStore? store;

  @override
  State<SavedStationsDestination> createState() =>
      _SavedStationsDestinationState();
}

class _SavedStationsDestinationState extends State<SavedStationsDestination> {
  late final _store = widget.store ?? SavedStationsStore();
  late final Future<(List<BikeStation>, List<String>)> _local = () async {
    final r = await Future.wait<Object>([
      (widget.stationRepository ?? BundledStationRepository()).fetch(),
      _store.load(),
    ]);
    return (r[0] as List<BikeStation>, r[1] as List<String>);
  }();
  LiveSnapshot? _snapshot;
  DeviceLocation? _location;

  @override
  void initState() {
    super.initState();
    // 실시간 자료와 위치는 화면을 막지 않고 뒤에서.
    (widget.liveRepository ?? SupabaseLiveSnapshotRepository())
        .fetch()
        .then((s) {
          if (mounted) setState(() => _snapshot = s);
        })
        .catchError((_) {});
    (widget.readLocation ?? readDeviceLocation)()
        .then((l) {
          if (mounted && l != null) setState(() => _location = l);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<(List<BikeStation>, List<String>)>(
        future: _local,
        builder: (context, local) {
          if (local.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (local.hasError || !local.hasData) {
            return const Center(child: Text('대여소 목록을 불러오지 못했어요.'));
          }
          final (stations, saved) = local.requireData;
          return _Favorites(
            stations: stations,
            initialSaved: saved,
            store: _store,
            snapshot: _snapshot,
            location: _location,
            readLocation: widget.readLocation,
          );
        },
      ),
    );
  }
}

class _Favorites extends StatefulWidget {
  const _Favorites({
    required this.stations,
    required this.initialSaved,
    required this.store,
    required this.snapshot,
    required this.location,
    required this.readLocation,
  });

  final List<BikeStation> stations;
  final List<String> initialSaved;
  final SavedStationsStore store;
  final LiveSnapshot? snapshot;
  final DeviceLocation? location;
  final Future<DeviceLocation?> Function()? readLocation;

  @override
  State<_Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<_Favorites> {
  late List<String> _saved = widget.initialSaved;
  late final Map<String, BikeStation> _byId = {
    for (final s in widget.stations) s.id: s,
  };
  var _searching = false;
  String _query = '';
  List<BikeStation> _results = const [];
  String? _selected;
  String? _message;
  var _view = 0;

  List<LiveBike> _bikesAt(String id) {
    final bikes = [
      for (final b in widget.snapshot?.bikes ?? const <LiveBike>[])
        if (b.station == id) b,
    ];
    bikes.sort((a, b) => b.chain.compareTo(a.chain));
    return bikes;
  }

  void _select(String id) => setState(() {
    _selected = id;
    _view++;
  });

  void _search(String value) {
    final key = value.replaceAll(RegExp(r'\s+'), '');
    setState(() {
      _query = value;
      _results = key.isEmpty
          ? const []
          : widget.stations
                .where(
                  (s) => s.name.replaceAll(RegExp(r'\s+'), '').contains(key),
                )
                .take(20)
                .toList(growable: false);
    });
  }

  void _nearby() {
    final here = widget.location;
    if (here == null) {
      setState(() => _message = '위치를 찾지 못했어요. 이름으로 찾아 주세요.');
      return;
    }
    final sorted = [...widget.stations]
      ..sort(
        (a, b) =>
            metersBetween(
              here.latitude,
              here.longitude,
              a.latitude,
              a.longitude,
            ).compareTo(
              metersBetween(
                here.latitude,
                here.longitude,
                b.latitude,
                b.longitude,
              ),
            ),
      );
    setState(() {
      _query = '';
      _results = sorted.take(10).toList(growable: false);
      _message = null;
    });
  }

  Future<void> _add(BikeStation station) async {
    if (_saved.length >= savedStationsLimit && !_saved.contains(station.id)) {
      final oldest = _byId[_saved.first];
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('내 대여소가 가득 찼어요'),
          content: Text(
            '${oldest?.name ?? '가장 먼저 저장한 대여소'}을 빼고 ${station.name}을 넣을까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('바꾸기'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final saved = await widget.store.add(station.id);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _message = '${station.name.trim()}을 내 대여소에 넣었어요.';
    });
    // 알림 시간 배우기용 기록은 화면을 기다리게 하지 않는다.
    rememberLookup(
      kind: LookupKind.station,
      subject: station.id,
      readLocation: widget.readLocation,
    );
  }

  Future<void> _remove(BikeStation station) async {
    final saved = await widget.store.remove(station.id);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _message = '${station.name.trim()}을 내 대여소에서 뺐어요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    final alerts = <String, List<LiveBike>>{};
    for (final b in widget.snapshot?.bikes ?? const <LiveBike>[]) {
      (alerts[b.station] ??= []).add(b);
    }
    final pins = [
      for (final s in widget.stations)
        NearbyMapStation(
          id: s.id,
          latitude: s.latitude,
          longitude: s.longitude,
          alertCount: alerts[s.id]?.length ?? 0,
          isHighAlert: alerts[s.id]?.any((b) => b.isHighAlert) ?? false,
        ),
    ];
    final selected = _selected == null ? null : _byId[_selected];
    final favorites = [for (final id in _saved) ?_byId[id]];
    final fit = selected != null
        ? null
        : favorites.isEmpty
        ? null
        : [for (final s in favorites) LatLng(s.latitude, s.longitude)];

    return RideyMapSheet(
      map: NearbyMap(
        fullBleed: true,
        stations: pins,
        location: widget.location,
        favoriteIds: _saved.toSet(),
        focus: selected == null
            ? null
            : (latitude: selected.latitude, longitude: selected.longitude),
        focusMeters: 300,
        fitPoints: fit,
        viewKey: '$_view|${_saved.length}',
        // 이 화면은 맨 위까지 지도라 상태 표시줄 + 뒤로 막대 아래에 단추를 둔다.
        controlsTop: MediaQuery.paddingOf(context).top + 72,
        onStationTap: _select,
      ),
      top: _TopBar(title: '내 대여소'),
      children: [
        if (selected != null) ...[
          _SelectedCard(
            station: selected,
            bikes: _bikesAt(selected.id),
            saved: _saved.contains(selected.id),
            meters: widget.location == null
                ? null
                : metersBetween(
                    widget.location!.latitude,
                    widget.location!.longitude,
                    selected.latitude,
                    selected.longitude,
                  ),
            onAdd: () => _add(selected),
            onRemove: () => _remove(selected),
            onClose: () => setState(() => _selected = null),
            snapshot: widget.snapshot,
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: RideySelectBadge(
                label: '즐겨찾기 ${_saved.length}/$savedStationsLimit',
                selected: !_searching,
                onSelected: (_) => setState(() => _searching = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RideySelectBadge(
                label: '대여소 검색',
                selected: _searching,
                onSelected: (_) => setState(() => _searching = true),
              ),
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 10),
          Text(
            _message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: c.calmText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!_searching) ...[
          if (favorites.isEmpty)
            Text(
              '자주 가는 대여소를 넣어 두면, 가기 전에 그곳의 피할 번호를 바로 보여 줘요. '
              '\'대여소 검색\' 에서 찾아 넣거나 지도에서 대여소를 눌러 보세요.',
              style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
            )
          else
            RideyListCard(
              children: [
                for (final s in favorites)
                  _FavoriteRow(
                    station: s,
                    bikes: _bikesAt(s.id),
                    loaded: widget.snapshot != null,
                    updatedAt: widget.snapshot?.updatedAt,
                    onTap: () => _select(s.id),
                    onRemove: () => _remove(s),
                  ),
              ],
            ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '대여소 이름 (예: 망원역)',
                    prefixIcon: Icon(Icons.search_rounded, color: c.muted),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RideyButton(
                label: '가까운 곳',
                icon: Icons.near_me_outlined,
                compact: true,
                onPressed: _nearby,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty && _query.trim().isNotEmpty)
            Text(
              '찾는 대여소가 없어요.',
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            )
          else if (_results.isNotEmpty)
            RideyListCard(
              children: [
                for (final s in _results)
                  RideyRow(
                    title: s.name.trim(),
                    subtitle: s.district,
                    // 줄을 누르면 지도에서 자리만 보여 주고, 넣기는 단추로만.
                    onTap: () => _select(s.id),
                    trailing: _saved.contains(s.id)
                        ? Text(
                            '넣음',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: c.calmText,
                            ),
                          )
                        : RideyButton.secondary(
                            label: '넣기',
                            compact: true,
                            onPressed: () => _add(s),
                          ),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 2, 16, 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '뒤로',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.chevron_left_rounded, size: 30),
              ),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.station,
    required this.bikes,
    required this.saved,
    required this.meters,
    required this.onAdd,
    required this.onRemove,
    required this.onClose,
    required this.snapshot,
  });

  final BikeStation station;
  final List<LiveBike> bikes;
  final bool saved;
  final double? meters;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onClose;
  final LiveSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.ridey;
    return RideyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  station.name.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          Text(
            [
              station.district,
              if (meters != null) distanceText(meters!),
              if (snapshot != null)
                bikes.isEmpty ? '지금 고장 의심 없음' : '고장 의심 ${bikes.length}대',
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bikes.isEmpty ? c.muted : c.signalText,
            ),
          ),
          const SizedBox(height: 12),
          saved
              ? RideyButton.secondary(label: '내 대여소에서 빼기', onPressed: onRemove)
              : RideyButton(label: '내 대여소에 넣기', onPressed: onAdd),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.station,
    required this.bikes,
    required this.loaded,
    required this.updatedAt,
    required this.onTap,
    required this.onRemove,
  });

  final BikeStation station;
  final List<LiveBike> bikes;
  final bool loaded;
  final DateTime? updatedAt;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final snapshotTime = updatedAt ?? DateTime.now();
    return RideyRow(
      leading: RideyIco(
        icon: Icons.location_on_outlined,
        tone: bikes.isEmpty
            ? RideyTone.ok
            : bikes.any((b) => b.isHighAlert)
            ? RideyTone.strong
            : RideyTone.normal,
      ),
      title: station.name.trim(),
      subtitle: station.district,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!loaded)
            Text(
              '받는 중',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: c.muted),
            )
          else if (bikes.isEmpty)
            Text(
              '고장 의심 없음',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: c.calmText),
            )
          else
            RideyNumber('${bikes.length}대 피하기', color: c.signalText),
          IconButton(
            tooltip: '${station.name.trim()} 내 대여소에서 빼기',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
      below: bikes.isEmpty
          ? null
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final bike in bikes)
                  RideyPressable(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            BikeDetailPage(bike: bike, updatedAt: snapshotTime),
                      ),
                    ),
                    scale: .95,
                    semanticLabel: '${bike.bike} 자세히 보기',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: bike.isHighAlert ? c.signal : c.signalSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: RideyNumber(
                        bike.bike,
                        size: 12,
                        color: bike.isHighAlert
                            ? RideyColors.ink
                            : c.signalText,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
