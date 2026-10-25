import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/live/live_snapshot.dart';
import 'package:ridey_app/widgets/ridey_status.dart';

class BikeDetailPage extends StatelessWidget {
  const BikeDetailPage({
    super.key,
    required this.bike,
    required this.updatedAt,
    this.feed,
  });

  final LiveBike bike;
  final DateTime updatedAt;
  final FeedHealth? feed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = bike.isHighAlert ? '피하세요.' : '주의해서 확인하세요.';
    final detail = bike.isHighAlert
        ? '서로 다른 사람들이 바로 반납한 기록이 여러 번 이어졌어요.'
        : '바로 반납한 기록이 이어져 경보가 켜졌어요.';

    return Scaffold(
      appBar: AppBar(title: const Text('자전거 경보')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.ridey.signal,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      bike.isHighAlert ? '강한 경보' : '경보',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: RideyColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    label,
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: theme.colorScheme.surface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.surface.withValues(alpha: .78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            RideyDataConfidence(
              updatedAt: updatedAt,
              isHealthy: feed?.isHealthy ?? true,
              ratio: feed?.ratio,
            ),
            const SizedBox(height: 24),
            Text(
              bike.bike,
              style: context.rideyNumbers(theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Text(
              bike.stationName.isEmpty ? bike.station : bike.stationName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.ridey.muted,
              ),
            ),
            const SizedBox(height: 32),
            Text('왜 경보가 켜졌나요?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            _EvidenceCard(bike: bike),
            if (bike.reasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ReasonCard(reasons: bike.reasons),
            ],
            const SizedBox(height: 16),
            _DataNote(updatedAt: updatedAt, feed: feed),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('다른 자전거 확인'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.bike});

  final LiveBike bike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _EvidenceRow(
            icon: Icons.radio_button_unchecked_rounded,
            text: '첫 번째 사람이 빌리자마자 반납',
            color: context.ridey.muted,
          ),
          const _EvidenceLine(),
          _EvidenceRow(
            icon: Icons.radio_button_checked_rounded,
            text: '다른 사람도 바로 반납',
            color: context.ridey.signal,
          ),
          const _EvidenceLine(),
          _EvidenceRow(
            icon: Icons.notifications_active_outlined,
            text: '서로 다른 ${bike.chain}명의 기록으로 경보',
            color: context.ridey.signal,
            strong: true,
          ),
          if (bike.probability != null) ...[
            const SizedBox(height: 18),
            Divider(color: context.ridey.line),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '다음 사람도 바로 반납할 가능성 ${bike.probability}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.ridey.signalText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reasons});

  final List<AlertReason> reasons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('판단 근거', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          for (final reason in reasons) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 58,
                  child: Text(
                    reason.deltaLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: (reason.deltaPoints ?? 0) < 0
                          ? context.ridey.calm
                          : context.ridey.signalText,
                    ),
                  ),
                ),
                Expanded(child: Text(reason.text)),
              ],
            ),
            if (reason != reasons.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.text,
    required this.color,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: strong
                  ? Theme.of(context).colorScheme.onSurface
                  : context.ridey.muted,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.only(left: 9, top: 5, bottom: 5),
      color: context.ridey.line,
    );
  }
}

class _DataNote extends StatelessWidget {
  const _DataNote({required this.updatedAt, this.feed});

  final DateTime updatedAt;
  final FeedHealth? feed;

  @override
  Widget build(BuildContext context) {
    final freshness = rideyAgo(updatedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.ridey.calmSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '${feed?.isHealthy == false ? '자료가 지연되고 있어 판단을 보수적으로 해 주세요. ' : ''}$freshness 갱신된 대여 기록을 기준으로 했어요. 고장 확정이 아니므로, 직접 상태도 확인해 주세요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.calm),
      ),
    );
  }
}
