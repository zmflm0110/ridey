import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/features/live/live_snapshot_repository.dart';
import 'package:ridey_app/features/rider/bike_lookup_page.dart';
import 'package:ridey_app/features/stations/saved_stations_page.dart';
import 'package:ridey_app/widgets/ridey_status.dart';

class RiderHomePage extends StatefulWidget {
  const RiderHomePage({super.key, this.repository});

  final LiveSnapshotRepository? repository;

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
        builder: (_) =>
            BikeLookupPage(snapshot: snapshot, repository: _repository),
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
        builder: (_) => SavedStationsPage(snapshot: snapshot),
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
            onRefresh: _refresh,
            onLookup: () => _openLookup(snapshot.requireData),
            onBikeSelected: (bike) =>
                _openDetail(bike, snapshot.requireData),
            onSavedStations: () => _openSavedStations(snapshot.requireData),
          ),
          _ => const _LoadingHome(),
        };

        return RefreshIndicator.adaptive(onRefresh: _refresh, child: child);
      },
    );
  }
}

class _LoadedHome extends StatelessWidget {
  const _LoadedHome({
    required this.snapshot,
    required this.onRefresh,
    required this.onLookup,
    required this.onBikeSelected,
    required this.onSavedStations,
  });

  final LiveSnapshot snapshot;
  final RefreshCallback onRefresh;
  final VoidCallback onLookup;
  final ValueChanged<LiveBike> onBikeSelected;
  final VoidCallback onSavedStations;

  @override
  Widget build(BuildContext context) {
    final highAlerts = snapshot.bikes.where((bike) => bike.isHighAlert).length;
    final preview = snapshot.bikes.take(3).toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 130),
      children: [
        const RideyPageHeading(
          title: '타기 전,\n확인하세요.',
          description: '번호를 확인하면 반복 반납 신호를 바로 알려 드려요.',
          hero: true,
        ),
        const SizedBox(height: 16),
        RideyDataConfidence(
          updatedAt: snapshot.updatedAt,
          isHealthy: snapshot.feed.isHealthy,
          ratio: snapshot.feed.ratio,
        ),
        const SizedBox(height: 24),
        _CheckBikeCard(
          onLookup: onLookup,
          onSavedStations: onSavedStations,
        ),
        const SizedBox(height: 34),
        _AlertSummary(
          count: snapshot.bikes.length,
          highAlertCount: highAlerts,
          onRefresh: onRefresh,
        ),
        if (!snapshot.feed.isHealthy) ...[
          const SizedBox(height: 16),
          _FeedDelayNotice(feed: snapshot.feed),
        ],
        const SizedBox(height: 40),
        _SectionTitle(title: '지금 피할 자전거', description: '경보가 먼저 켜진 순서예요.'),
        const SizedBox(height: 12),
        if (preview.isEmpty)
          const _NoAlerts()
        else
          ...preview.map(
            (bike) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BikeAlertCard(
                bike: bike,
                onTap: () => onBikeSelected(bike),
              ),
            ),
          ),
      ],
    );
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({
    required this.count,
    required this.highAlertCount,
    required this.onRefresh,
  });

  final int count;
  final int highAlertCount;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 20, 22),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '서울 전체 RIDEY 신호',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.surface.withValues(alpha: .76),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: context.ridey.signal,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text(
                  '대 주의',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.surface,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '실시간 목록 새로고침',
                onPressed: onRefresh,
                style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.surface,
                  backgroundColor: theme.colorScheme.surface.withValues(
                    alpha: .1,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            color: theme.colorScheme.surface.withValues(alpha: .14),
          ),
          const SizedBox(height: 14),
          Text(
            '연쇄 3명 이상 경보 $highAlertCount대 · 고장 확정은 아니에요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.surface.withValues(alpha: .76),
            ),
          ),
        ],
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
            '지금 눈앞의 자전거',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'QR을 찍거나 번호를 입력해 보세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.surface.withValues(alpha: .76),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLookup,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('자전거 확인하기'),
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onSavedStations,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.surface.withValues(alpha: .86),
            ),
            icon: const Icon(Icons.bookmark_outline_rounded),
            label: const Text('내 대여소의 주의 번호 보기'),
          ),
        ],
      ),
    );
  }
}

class _BikeAlertCard extends StatelessWidget {
  const _BikeAlertCard({required this.bike, required this.onTap});

  final LiveBike bike;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = bike.isHighAlert
        ? context.ridey.signal
        : context.ridey.signalText.withValues(alpha: .72);
    final levelText = bike.isHighAlert ? '강한 경보' : '경보';

    return Semantics(
      button: true,
      label: '${bike.bike} 경보 자세히 보기',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: context.ridey.line),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: severityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bike.stationName.isEmpty
                            ? bike.station
                            : bike.stationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${bike.bike} · 서로 다른 ${bike.chain}명이 바로 반납',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.ridey.muted,
                        ),
                      ),
                      if (bike.probability != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          '다음 사람도 바로 반납할 가능성 ${bike.probability}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: context.ridey.signalText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  levelText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: severityColor,
                    fontWeight: FontWeight.w800,
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

class _FeedDelayNotice extends StatelessWidget {
  const _FeedDelayNotice({required this.feed});

  final FeedHealth feed;

  @override
  Widget build(BuildContext context) {
    final ratio = feed.ratio == null ? null : '${(feed.ratio! * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ridey.signalSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: context.ridey.signalText),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              ratio == null
                  ? '대여 기록이 늦어지고 있어요. 새 경보가 늦을 수 있어요.'
                  : '대여 기록이 평소의 $ratio만 올라오고 있어요. 새 경보가 늦을 수 있어요.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.ridey.signalText),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 130),
      children: [
        Text('타기 전에,\n확인하세요.', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 30),
        const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 88),
            child: CircularProgressIndicator.adaptive(),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 130),
      children: [
        Text('타기 전에,\n확인하세요.', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: context.ridey.line),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_outlined, color: context.ridey.muted),
              const SizedBox(height: 20),
              Text(
                '실시간 목록을 불러오지 못했어요.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 시도'),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '지금 목록에 경보가 없어요. 고장이 없다는 뜻은 아니에요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
        ),
      ],
    );
  }
}
