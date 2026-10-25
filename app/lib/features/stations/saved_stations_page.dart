import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/location/device_location.dart';
import 'package:ridey_app/features/rider/bike_detail_page.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class SavedStationsDestination extends StatefulWidget {
  const SavedStationsDestination({
    super.key,
    this.liveRepository,
    this.stationRepository,
    this.readLocation,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final Future<DeviceLocation?> Function()? readLocation;

  @override
  State<SavedStationsDestination> createState() =>
      _SavedStationsDestinationState();
}

class _SavedStationsDestinationState extends State<SavedStationsDestination> {
  late final LiveSnapshotRepository _liveRepository;
  late Future<LiveSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _liveRepository = widget.liveRepository ?? SupabaseLiveSnapshotRepository();
    _snapshot = _liveRepository.fetch();
  }

  Future<void> _retry() async {
    setState(() => _snapshot = _liveRepository.fetch());
    await _snapshot;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiveSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _StationLoadFailure(onRetry: _retry);
        }
        return SavedStationsPage(
          snapshot: snapshot.requireData,
          stationRepository: widget.stationRepository,
          showAppBar: false,
          readLocation: widget.readLocation,
        );
      },
    );
  }
}

class SavedStationsPage extends StatefulWidget {
  const SavedStationsPage({
    super.key,
    required this.snapshot,
    this.stationRepository,
    this.store,
    this.showAppBar = true,
    this.readLocation,
  });

  final LiveSnapshot snapshot;
  final StationRepository? stationRepository;
  final SavedStationsStore? store;
  final bool showAppBar;
  final Future<DeviceLocation?> Function()? readLocation;

  @override
  State<SavedStationsPage> createState() => _SavedStationsPageState();
}

class _SavedStationsPageState extends State<SavedStationsPage> {
  late final StationRepository _stationRepository;
  late final SavedStationsStore _store;
  late Future<void> _loading;
  List<BikeStation> _stations = const [];
  List<String> _saved = const [];
  List<BikeStation> _suggestions = const [];
  String? _message;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _stationRepository = widget.stationRepository ?? BundledStationRepository();
    _store = widget.store ?? SavedStationsStore();
    _loading = _load().then((_) {
      return rememberLookup(
        kind: LookupKind.station,
        subject: _saved.isEmpty ? null : _saved.first,
        readLocation: widget.readLocation,
      );
    });
  }

  Future<void> _load() async {
    final result = await Future.wait([
      _stationRepository.fetch(),
      _store.load(),
    ]);
    _stations = result[0] as List<BikeStation>;
    _saved = result[1] as List<String>;
  }

  Future<void> _reload() async {
    setState(() {
      _message = null;
      _loading = _load();
    });
    await _loading;
  }

  void _search(String value) {
    final key = value.replaceAll(RegExp(r'\s+'), '');
    if (key.isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    final suggestions = _stations
        .where(
          (station) =>
              !_saved.contains(station.id) &&
              station.name.replaceAll(RegExp(r'\s+'), '').contains(key),
        )
        .take(6)
        .toList(growable: false);
    setState(() {
      _message = suggestions.isEmpty ? '찾는 대여소가 없어요.' : null;
      _suggestions = suggestions;
    });
  }

  Future<void> _findNearby() async {
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationException('위치 서비스를 켠 뒤 다시 시도해 주세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationException('위치 권한을 허용하면 가까운 대여소를 찾을 수 있어요.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationException('설정에서 위치 권한을 허용한 뒤 다시 시도해 주세요.');
      }
      final position = await Geolocator.getCurrentPosition();
      final nearby =
          _stations.where((station) => !_saved.contains(station.id)).toList()
            ..sort(
              (left, right) =>
                  _meters(position, left).compareTo(_meters(position, right)),
            );
      if (!mounted) return;
      setState(() {
        _suggestions = nearby.take(5).toList(growable: false);
        _locating = false;
      });
    } on _LocationException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _locating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = '현재 위치를 가져오지 못했어요. 이름으로 찾아 주세요.';
          _locating = false;
        });
      }
    }
  }

  Future<void> _add(BikeStation station) async {
    if (_saved.length >= savedStationsLimit) {
      final oldest = _stations
          .where((item) => item.id == _saved.first)
          .firstOrNull;
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
    final saved = await _store.add(station.id);
    await rememberLookup(
      kind: LookupKind.station,
      subject: station.id,
      readLocation: widget.readLocation,
    );
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _suggestions = _suggestions
          .where((item) => item.id != station.id)
          .toList();
      _message = '${station.name}을 내 대여소에 넣었어요.';
    });
  }

  Future<void> _remove(BikeStation station) async {
    final saved = await _store.remove(station.id);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _message = '${station.name}을 내 대여소에서 뺐어요.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar() : null,
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, loading) {
          if (loading.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (loading.hasError) {
            return _StationLoadFailure(onRetry: _reload);
          }
          return _Content(
            snapshot: widget.snapshot,
            updatedAt: widget.snapshot.updatedAt,
            stations: _stations,
            saved: _saved,
            suggestions: _suggestions,
            message: _message,
            locating: _locating,
            onSearch: _search,
            onFindNearby: _findNearby,
            onAdd: _add,
            onRemove: _remove,
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.snapshot,
    required this.updatedAt,
    required this.stations,
    required this.saved,
    required this.suggestions,
    required this.message,
    required this.locating,
    required this.onSearch,
    required this.onFindNearby,
    required this.onAdd,
    required this.onRemove,
  });

  final LiveSnapshot snapshot;
  final DateTime updatedAt;
  final List<BikeStation> stations;
  final List<String> saved;
  final List<BikeStation> suggestions;
  final String? message;
  final bool locating;
  final ValueChanged<String> onSearch;
  final VoidCallback onFindNearby;
  final ValueChanged<BikeStation> onAdd;
  final ValueChanged<BikeStation> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedStations = saved
        .map((id) => stations.where((station) => station.id == id).firstOrNull)
        .whereType<BikeStation>()
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('내 대여소', style: context.rideyPageTitle),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '자주 가는 곳을 저장하면, 출발 전에 피할 번호를 바로 볼 수 있어요.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              color: context.ridey.muted,
            ),
          ),
        ),
        RideySectionTitle(
          '저장한 대여소',
          note: '${savedStations.length}/$savedStationsLimit곳',
        ),
        if (savedStations.isEmpty)
          const _SavedStationsEmpty()
        else
          RideyListCard(
            children: [
              for (final station in savedStations)
                _SavedStationRow(
                  station: station,
                  bikes: _bikesAt(snapshot.bikes, station.id),
                  updatedAt: updatedAt,
                  onRemove: () => onRemove(station),
                ),
            ],
          ),
        const RideySectionTitle('대여소 추가'),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '대여소 이름 (예: 망원역)',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.ridey.muted,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            RideyButton(
              label: '가까운 곳',
              icon: Icons.near_me_outlined,
              compact: true,
              busy: locating,
              onPressed: onFindNearby,
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Message(message: message!),
          ),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          RideyListCard(
            key: ValueKey(suggestions.map((station) => station.id).join()),
            children: [
              for (final station in suggestions)
                _SuggestionRow(station: station, onAdd: () => onAdd(station)),
            ],
          ),
        ],
      ],
    );
  }
}

class _SavedStationRow extends StatelessWidget {
  const _SavedStationRow({
    required this.station,
    required this.bikes,
    required this.updatedAt,
    required this.onRemove,
  });

  final BikeStation station;
  final List<LiveBike> bikes;
  final DateTime updatedAt;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final hasHigh = bikes.any((bike) => bike.isHighAlert);

    return RideyRow(
      leading: RideyIco(
        icon: Icons.location_on_outlined,
        tone: bikes.isEmpty
            ? RideyTone.ok
            : hasHigh
            ? RideyTone.strong
            : RideyTone.normal,
      ),
      title: station.name,
      subtitle: station.district,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bikes.isEmpty)
            Text(
              '현재 경보 없음',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: c.calmText),
            )
          else
            RideyNumber('${bikes.length}대 피하기', color: c.signalText),
          IconButton(
            tooltip: '${station.name} 내 대여소에서 빼기',
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
                  _BikeChip(
                    bike: bike,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BikeDetailPage(bike: bike, updatedAt: updatedAt),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

/// A bike number pill (web `.chip`): solid signal for a strong alert.
class _BikeChip extends StatelessWidget {
  const _BikeChip({required this.bike, required this.onTap});

  final LiveBike bike;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    return RideyPressable(
      onTap: onTap,
      scale: .95,
      semanticLabel: '${bike.bike} 자세히 보기',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: bike.isHighAlert ? c.signal : c.signalSoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: RideyNumber(
          bike.bike,
          size: 12,
          color: bike.isHighAlert ? RideyColors.ink : c.signalText,
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.station, required this.onAdd});

  final BikeStation station;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return RideyRow(
      title: station.name,
      subtitle: station.district,
      trailing: RideyButton.secondary(
        label: '넣기',
        compact: true,
        onPressed: onAdd,
      ),
    );
  }
}

class _SavedStationsEmpty extends StatelessWidget {
  const _SavedStationsEmpty();

  @override
  Widget build(BuildContext context) {
    return RideyCard(
      child: Text(
        '자주 가는 대여소를 넣어 두면, 가기 전에 그곳의 피할 번호를 바로 보여 줘요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: context.ridey.calmText,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StationLoadFailure extends StatelessWidget {
  const _StationLoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        RideyCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RideyIco(icon: Icons.cloud_off_outlined),
              const SizedBox(height: 14),
              Text(
                '대여소 목록을 불러오지 못했어요.',
                style: Theme.of(context).textTheme.headlineLarge,
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

class _LocationException implements Exception {
  const _LocationException(this.message);

  final String message;
}

List<LiveBike> _bikesAt(List<LiveBike> bikes, String stationId) {
  final matches = bikes.where((bike) => bike.station == stationId).toList();
  matches.sort(
    (left, right) => (right.probability ?? right.chain).compareTo(
      left.probability ?? left.chain,
    ),
  );
  return matches;
}

double _meters(Position position, BikeStation station) {
  return Geolocator.distanceBetween(
    position.latitude,
    position.longitude,
    station.latitude,
    station.longitude,
  );
}

extension on Iterable<BikeStation> {
  BikeStation? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
