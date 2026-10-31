import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/staff/district_stats.dart';
import 'package:ridey_app/features/staff/staff_clock.dart';
import 'package:ridey_app/features/staff/staff_session.dart';
import 'package:ridey_app/widgets/ridey_tab_bar.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

class StaffOverviewPage extends StatelessWidget {
  const StaffOverviewPage({
    super.key,
    required this.session,
    required this.onOpenDistrict,
  });

  final StaffSession session;
  final ValueChanged<String> onOpenDistrict;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (session.loading && session.bikes.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (session.error != null && session.bikes.isEmpty) {
      return _StaffFailure(onRetry: session.reload);
    }

    final rows = districtRows(session.bikes, session.stations);
    final total = session.bikes.length;
    final high = session.bikes.where((bike) => bike.isHighAlert).length;

    return RefreshIndicator.adaptive(
      color: context.ridey.signal,
      onRefresh: session.reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, rideyTabClearance),
        children: [
          Text('구별 현황', style: theme.textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            '지금 고장 의심 $total대 · 강한 경보 $high',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.ridey.muted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RideySelectBadge(
                label: '실시간',
                selected: session.source == ListSource.live,
                onSelected: (_) => session.setSource(ListSource.live),
              ),
              RideySelectBadge(
                label: '아침 목록',
                selected: session.source == ListSource.morning,
                onSelected: (_) => session.setSource(ListSource.morning),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            Text(
              '지금 목록에 고장 의심 자전거가 없어요.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: context.ridey.muted,
              ),
            )
          else
            RideyListCard(
              children: [
                for (final row in rows)
                  RideyRow(
                    title: row.district,
                    subtitle:
                        '강한 경보 ${row.highAlerts} · 기대값 ${formatExpected(row.expected)}',
                    trailing: Text(
                      '${row.bikes}대',
                      style: context.rideyNumbers(theme.textTheme.titleMedium),
                    ),
                    onTap: () => onOpenDistrict(row.district),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StaffFailure extends StatelessWidget {
  const _StaffFailure({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, rideyTabClearance),
      children: [
        RideyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '목록을 불러오지 못했어요.',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 18),
              RideyButton.secondary(
                label: '다시 시도',
                onPressed: () => onRetry(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
