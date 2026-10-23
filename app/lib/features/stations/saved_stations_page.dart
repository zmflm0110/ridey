import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/saved_stations.dart';
import 'package:ridey_app/features/stations/station_repository.dart';

class SavedStationsDestination extends StatefulWidget {
  const SavedStationsDestination({
    super.key,
    this.liveRepository,
    this.stationRepository,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;

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
  });

  final LiveSnapshot snapshot;
  final StationRepository? stationRepository;
  final SavedStationsStore? store;
  final bool showAppBar;

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
    _stationRepository = widget.stationRepository ?? GitHubStationRepository();
    _store = widget.store ?? SavedStationsStore();
    _loading = _load();
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
      appBar: widget.showAppBar ? AppBar(title: const Text('내 대여소')) : null,
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
    final savedStations = saved
        .map((id) => stations.where((station) => station.id == id).firstOrNull)
        .whereType<BikeStation>()
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        Text('내 대여소', style: context.rideyPageTitle),
        const SizedBox(height: 10),
        Text(
          '자주 가는 곳을 저장하면, 출발 전에 주의 번호를 바로 확인할 수 있어요.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.ridey.muted),
        ),
        const SizedBox(height: 28),
        Text('저장한 대여소', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (savedStations.isEmpty)
          const _SavedStationsEmpty()
        else
          ...savedStations.map(
            (station) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SavedStationCard(
                station: station,
                bikes: _bikesAt(snapshot.bikes, station.id),
                updatedAt: updatedAt,
                onRemove: () => onRemove(station),
              ),
            ),
          ),
        const SizedBox(height: 34),
        Text('대여소 추가', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          onChanged: onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '대여소 이름 (예: 망원역)',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: context.ridey.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: context.ridey.line),
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: locating ? null : onFindNearby,
          icon: locating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : const Icon(Icons.near_me_outlined),
          label: const Text('가까운 대여소 찾기'),
        ),
        if (message != null) ...[
          const SizedBox(height: 14),
          _Message(message: message!),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...suggestions.map(
            (station) =>
                _SuggestionRow(station: station, onAdd: () => onAdd(station)),
          ),
        ],
      ],
    );
  }
}

class _SavedStationCard extends StatelessWidget {
  const _SavedStationCard({
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
    final hasHigh = bikes.any((bike) => bike.isHighAlert);
    final statusColor = bikes.isEmpty
        ? context.ridey.calm
        : hasHigh
        ? context.ridey.signal
        : context.ridey.signalText;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_bike_outlined, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      station.district,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.ridey.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '${station.name} 내 대여소에서 빼기',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            bikes.isEmpty ? '현재 경보 없음' : '${bikes.length}대 피하기',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: statusColor),
          ),
          if (bikes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bikes
                  .map(
                    (bike) => ActionChip(
                      label: Text(bike.bike),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BikeDetailPage(
                              bike: bike,
                              updatedAt: updatedAt,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(station.name),
      subtitle: Text(station.district),
      trailing: TextButton(onPressed: onAdd, child: const Text('넣기')),
    );
  }
}

class _SavedStationsEmpty extends StatelessWidget {
  const _SavedStationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(20),
      ),
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
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: context.ridey.calm),
    );
  }
}

class _StationLoadFailure extends StatelessWidget {
  const _StationLoadFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 16),
            Text(
              '대여소 목록을 불러오지 못했어요.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
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
