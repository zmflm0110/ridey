import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/widgets/ridey_status.dart';

class WorkerOverviewPage extends StatefulWidget {
  const WorkerOverviewPage({
    super.key,
    this.repository,
    required this.onOpenStationTasks,
  });

  final LiveSnapshotRepository? repository;
  final VoidCallback onOpenStationTasks;

  @override
  State<WorkerOverviewPage> createState() => _WorkerOverviewPageState();
}

class _WorkerOverviewPageState extends State<WorkerOverviewPage> {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LiveSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return _WorkerOverviewFailure(onRetry: _refresh);
        }
        return _WorkerOverview(
          snapshot: snapshot.requireData,
          onRefresh: _refresh,
          onOpenStationTasks: widget.onOpenStationTasks,
        );
      },
    );
  }
}

class _WorkerOverview extends StatelessWidget {
  const _WorkerOverview({
    required this.snapshot,
    required this.onRefresh,
    required this.onOpenStationTasks,
  });

  final LiveSnapshot snapshot;
  final RefreshCallback onRefresh;
  final VoidCallback onOpenStationTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stations = snapshot.bikes.map((bike) => bike.station).toSet().length;
    final highAlerts = snapshot.bikes.where((bike) => bike.isHighAlert).length;

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 130),
        children: [
          const RideyPageHeading(
            title: '오늘의 작업',
            description: '현장 확인이 필요한 대여소부터 한 곳씩 처리하세요.',
          ),
          const SizedBox(height: 14),
          RideyDataConfidence(
            updatedAt: snapshot.updatedAt,
            isHealthy: snapshot.feed.isHealthy,
            ratio: snapshot.feed.ratio,
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘의 대기열', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _Count(
                        label: '확인할 자전거',
                        value: '${snapshot.bikes.length}대',
                      ),
                      const SizedBox(width: 28),
                      _Count(label: '강한 경보', value: '$highAlerts대'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$stations개 대여소 · ${snapshot.updatedAt.hour.toString().padLeft(2, '0')}:${snapshot.updatedAt.minute.toString().padLeft(2, '0')} 갱신',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.ridey.muted,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: onOpenStationTasks,
                    child: const Text('대여소 작업 시작'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '현장 기록은 기록 탭에서 전송 상태를 확인할 수 있어요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.ridey.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
        ),
      ],
    );
  }
}

class _WorkerOverviewFailure extends StatelessWidget {
  const _WorkerOverviewFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 36),
            const SizedBox(height: 14),
            const Text('업무 대기열을 불러오지 못했어요.'),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
