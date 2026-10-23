import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/field/field_verdict.dart';
import 'package:ridey_app/features/field/field_verification_repository.dart';
import 'package:ridey_app/features/field/quick_verdict_sheet.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';
import 'package:ridey_app/features/stations/bike_station.dart';
import 'package:ridey_app/features/stations/station_repository.dart';
import 'package:ridey_app/features/work/work_queue.dart';
import 'package:ridey_app/widgets/ridey_status.dart';

class WorkHomePage extends StatefulWidget {
  const WorkHomePage({
    super.key,
    this.liveRepository,
    this.stationRepository,
    this.fieldRepository,
  });

  final LiveSnapshotRepository? liveRepository;
  final StationRepository? stationRepository;
  final FieldVerificationRepository? fieldRepository;

  @override
  State<WorkHomePage> createState() => _WorkHomePageState();
}

class _WorkHomePageState extends State<WorkHomePage> {
  late final LiveSnapshotRepository _liveRepository;
  late final StationRepository _stationRepository;
  late final FieldVerificationRepository _fieldRepository;
  late Future<_WorkData> _loading;
  Position? _position;
  _QueueSort _sort = _QueueSort.priority;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _liveRepository = widget.liveRepository ?? SupabaseLiveSnapshotRepository();
    _stationRepository = widget.stationRepository ?? GitHubStationRepository();
    _fieldRepository = widget.fieldRepository ?? FieldVerificationRepository();
    _loading = _load();
  }

  Future<_WorkData> _load() async {
    try {
      await _fieldRepository.sync();
    } catch (_) {
      // A local-storage failure must not prevent access to the live queue.
    }
    final result = await Future.wait([
      _liveRepository.fetch(),
      _stationRepository.fetch(),
    ]);
    CheckedVerdicts checked = const {};
    try {
      checked = await _fieldRepository.fetchChecked();
    } catch (_) {
      // The live work queue still has value when aggregate check status is
      // temporarily unavailable.
    }
    return _WorkData(
      snapshot: result[0] as LiveSnapshot,
      stations: result[1] as List<BikeStation>,
      checked: checked,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _locationMessage = null;
      _loading = _load();
    });
    await _loading;
  }

  Future<void> _useLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _WorkLocationException('위치 서비스를 켠 뒤 다시 시도해 주세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _WorkLocationException('위치 권한을 허용하면 가까운 순서를 볼 수 있어요.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _WorkLocationException('설정에서 위치 권한을 허용한 뒤 다시 시도해 주세요.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = position;
        _sort = _QueueSort.nearby;
        _locationMessage = null;
      });
    } on _WorkLocationException catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationMessage = '현재 위치를 가져오지 못했어요. 우선순위 순서로 보여 드려요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WorkData>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _WorkLoadFailure(onRetry: _refresh);
        }
        return _WorkQueue(
          data: snapshot.requireData,
          position: _position,
          sort: _sort,
          locationMessage: _locationMessage,
          onRefresh: _refresh,
          onSortChanged: (sort) => setState(() => _sort = sort),
          onUseLocation: _useLocation,
          fieldRepository: _fieldRepository,
        );
      },
    );
  }
}

class _WorkQueue extends StatelessWidget {
  const _WorkQueue({
    required this.data,
    required this.position,
    required this.sort,
    required this.locationMessage,
    required this.onRefresh,
    required this.onSortChanged,
    required this.onUseLocation,
    required this.fieldRepository,
  });

  final _WorkData data;
  final Position? position;
  final _QueueSort sort;
  final String? locationMessage;
  final RefreshCallback onRefresh;
  final ValueChanged<_QueueSort> onSortChanged;
  final VoidCallback onUseLocation;
  final FieldVerificationRepository fieldRepository;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = _tasks();
    final high = data.snapshot.bikes.where((bike) => bike.isHighAlert).length;

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 130),
        children: [
          const RideyPageHeading(
            title: '다음으로 갈 곳',
            description: '더 많은 헛걸음을 막을 대여소부터 확인하세요.',
          ),
          const SizedBox(height: 14),
          RideyDataConfidence(
            updatedAt: data.snapshot.updatedAt,
            isHealthy: data.snapshot.feed.isHealthy,
            ratio: data.snapshot.feed.ratio,
          ),
          const SizedBox(height: 22),
          _WorkSummary(
            stationCount: tasks.length,
            bikeCount: data.snapshot.bikes.length,
            highCount: high,
            checkedBikeCount: _checkedBikeCount(tasks),
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: Text('확인할 곳', style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: '내 위치에서 가까운 순서',
                onPressed: onUseLocation,
                icon: const Icon(Icons.near_me_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<_QueueSort>(
            segments: const [
              ButtonSegment(
                value: _QueueSort.priority,
                label: Text('우선순위'),
                icon: Icon(Icons.format_list_numbered_rounded),
              ),
              ButtonSegment(
                value: _QueueSort.nearby,
                label: Text('가까운 순'),
                icon: Icon(Icons.location_on_outlined),
              ),
            ],
            selected: {sort},
            onSelectionChanged: (selection) {
              if (selection.single == _QueueSort.nearby && position == null) {
                onUseLocation();
                return;
              }
              onSortChanged(selection.single);
            },
          ),
          if (locationMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              locationMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.ridey.calm,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            const _NoWorkTasks()
          else
            ...tasks.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorkTaskCard(
                  order: entry.$1 + 1,
                  task: entry.$2,
                  distance: _distance(entry.$2),
                  updatedAt: data.snapshot.updatedAt,
                  fieldRepository: fieldRepository,
                  checked: data.checked,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_LocatedTask> _tasks() {
    final stations = {for (final station in data.stations) station.id: station};
    final tasks = buildStationTasks(data.snapshot.bikes)
        .map(
          (task) => _LocatedTask(task: task, station: stations[task.stationId]),
        )
        .toList();
    if (sort == _QueueSort.nearby && position != null) {
      tasks.sort((left, right) {
        final a = _distance(left) ?? double.infinity;
        final b = _distance(right) ?? double.infinity;
        return a.compareTo(b);
      });
    }
    return tasks;
  }

  double? _distance(_LocatedTask task) {
    if (position == null || task.station == null) return null;
    return Geolocator.distanceBetween(
      position!.latitude,
      position!.longitude,
      task.station!.latitude,
      task.station!.longitude,
    );
  }

  int _checkedBikeCount(List<_LocatedTask> tasks) {
    return tasks
        .expand((task) => task.task.bikes)
        .where((bike) => (data.checked[bike.bike] ?? const {}).isNotEmpty)
        .length;
  }
}

class _WorkSummary extends StatelessWidget {
  const _WorkSummary({
    required this.stationCount,
    required this.bikeCount,
    required this.highCount,
    required this.checkedBikeCount,
    required this.onRefresh,
  });

  final int stationCount;
  final int bikeCount;
  final int highCount;
  final int checkedBikeCount;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘 확인할 대여소',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.surface.withValues(alpha: .76),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$stationCount',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: context.ridey.signal,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text(
                  '곳',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.surface,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '작업 대기열 새로고침',
                onPressed: onRefresh,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface.withValues(
                    alpha: .1,
                  ),
                  foregroundColor: theme.colorScheme.surface,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '자전거 $bikeCount대 · 강한 경보 $highCount대 · 현장 확인 $checkedBikeCount대',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.surface.withValues(alpha: .76),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTaskCard extends StatelessWidget {
  const _WorkTaskCard({
    required this.order,
    required this.task,
    required this.distance,
    required this.updatedAt,
    required this.fieldRepository,
    required this.checked,
  });

  final int order;
  final _LocatedTask task;
  final double? distance;
  final DateTime updatedAt;
  final FieldVerificationRepository fieldRepository;
  final CheckedVerdicts checked;

  @override
  Widget build(BuildContext context) {
    final high = task.task.highAlertCount > 0;
    final signal = high ? context.ridey.signal : context.ridey.signalText;
    final checkedBikeCount = task.task.bikes
        .where((bike) => (checked[bike.bike] ?? const {}).isNotEmpty)
        .length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _WorkStationDetailPage(
                task: task,
                distance: distance,
                updatedAt: updatedAt,
                fieldRepository: fieldRepository,
                checked: checked,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: context.ridey.line),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: signal.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$order',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: signal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.task.stationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${task.task.bikes.length}대 확인 · 연쇄 ${task.task.totalChain}명'
                      '${checkedBikeCount == 0 ? '' : ' · 현장 확인 $checkedBikeCount대'}'
                      '${distance == null ? '' : ' · ${distance!.round()}m'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.ridey.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        RideySignalBadge(
                          state: high
                              ? RideySignalState.avoid
                              : RideySignalState.uncertain,
                          compact: true,
                        ),
                        if (checkedBikeCount > 0) ...[
                          const SizedBox(width: 6),
                          const RideySignalBadge(
                            state: RideySignalState.completed,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.ridey.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkStationDetailPage extends StatefulWidget {
  const _WorkStationDetailPage({
    required this.task,
    required this.distance,
    required this.updatedAt,
    required this.fieldRepository,
    required this.checked,
  });

  final _LocatedTask task;
  final double? distance;
  final DateTime updatedAt;
  final FieldVerificationRepository fieldRepository;
  final CheckedVerdicts checked;

  @override
  State<_WorkStationDetailPage> createState() => _WorkStationDetailPageState();
}

class _WorkStationDetailPageState extends State<_WorkStationDetailPage> {
  late CheckedVerdicts _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.checked;
  }

  Future<void> _refreshChecked() async {
    try {
      final refreshed = await widget.fieldRepository.fetchChecked();
      if (mounted) setState(() => _checked = refreshed);
    } catch (_) {
      // Submitted records can still be queued offline; preserve the current view.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedCount = widget.task.task.bikes
        .where((bike) => (_checked[bike.bike] ?? const {}).isNotEmpty)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('대여소 작업')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        children: [
          Text(
            widget.task.task.stationName,
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '현장 확인 $checkedCount/${widget.task.task.bikes.length}대'
            '${widget.distance == null ? '' : ' · 현재 위치에서 ${widget.distance!.round()}m'}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.ridey.muted,
            ),
          ),
          const SizedBox(height: 28),
          Text('확인할 자전거', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ...widget.task.task.bikes.map(
            (bike) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: context.ridey.line),
                  borderRadius: BorderRadius.circular(18),
                ),
                tileColor: theme.colorScheme.surface,
                title: Text(bike.bike),
                subtitle: Text(
                  _bikeSubtitle(bike, _checked[bike.bike] ?? const {}),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final submission = await showQuickVerdictSheet(
                      context,
                      bikeId: bike.bike,
                      repository: widget.fieldRepository,
                    );
                    if (submission != null) await _refreshChecked();
                  },
                  child: const Text('현장 확인'),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BikeDetailPage(
                        bike: bike,
                        updatedAt: widget.updatedAt,
                        isWorkContext: true,
                        fieldRepository: widget.fieldRepository,
                        checkedVerdicts: _checked[bike.bike] ?? const {},
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _bikeSubtitle(LiveBike bike, Map<FieldVerdict, int> verdicts) {
    final count = verdicts.values.fold(0, (sum, value) => sum + value);
    return '서로 다른 ${bike.chain}명이 바로 반납'
        '${count == 0 ? '' : ' · 현장 확인 $count건'}';
  }
}

class _NoWorkTasks extends StatelessWidget {
  const _NoWorkTasks();

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
        '지금 확인할 경보가 없어요. 자료가 늦는 경우에는 새 경보가 늦을 수 있어요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
      ),
    );
  }
}

class _WorkLoadFailure extends StatelessWidget {
  const _WorkLoadFailure({required this.onRetry});

  final RefreshCallback onRetry;

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
              '작업 대기열을 불러오지 못했어요.',
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

class _WorkData {
  const _WorkData({
    required this.snapshot,
    required this.stations,
    required this.checked,
  });

  final LiveSnapshot snapshot;
  final List<BikeStation> stations;
  final CheckedVerdicts checked;
}

class _LocatedTask {
  const _LocatedTask({required this.task, required this.station});

  final StationTask task;
  final BikeStation? station;
}

class _WorkLocationException implements Exception {
  const _WorkLocationException(this.message);

  final String message;
}

enum _QueueSort { priority, nearby }
